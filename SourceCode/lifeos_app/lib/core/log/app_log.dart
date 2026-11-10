// On-device diagnostics log (PBI-030). Nothing leaves the phone unless the
// user shares it from Settings → Diagnostics.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum LogLevel { info, warning, error }

/// One line of the log.
class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.area,
    required this.message,
    this.stack,
    this.route,
  });

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
    time: DateTime.parse(j['t'] as String),
    level: LogLevel.values.firstWhere(
      (l) => l.name == j['l'],
      orElse: () => LogLevel.info,
    ),
    area: j['a'] as String? ?? '',
    message: j['m'] as String? ?? '',
    stack: j['s'] as String?,
    route: j['r'] as String?,
  );

  final DateTime time;
  final LogLevel level;
  final String area;
  final String message;
  final String? stack;
  final String? route;

  Map<String, Object?> toJson() => {
    't': time.toIso8601String(),
    'l': level.name,
    'a': area,
    'm': message,
    's': ?stack,
    'r': ?route,
  };
}

/// Masks personal data in any text before it is written (AC3): long digit
/// runs (CNIC, phone, account, reference numbers), emails and amounts.
/// Messages should not contain such data in the first place — this is the
/// last line of defence.
String scrubLogText(String s) {
  var out = s;
  // API keys (PBI-027a AC6). Known prefixes first, then any long
  // unbroken token that looks like a secret. Done before the digit-run
  // rule, so a key is never half-masked into something still guessable.
  out = out.replaceAll(
    RegExp(r'\b(sk|rk|pk)-[A-Za-z0-9_-]{8,}|\bAIza[A-Za-z0-9_-]{10,}'),
    '<key>',
  );
  out = out.replaceAll(
    RegExp(r'\bBearer\s+[A-Za-z0-9._-]{8,}', caseSensitive: false),
    'Bearer <key>',
  );
  // A long unbroken token that mixes letters and digits is a secret,
  // not prose. Both are required: a long run of plain letters is
  // ordinary text, and masking that would eat real log lines.
  out = out.replaceAllMapped(RegExp(r'[A-Za-z0-9+/_-]{40,}={0,2}'), (m) {
    final token = m[0]!;
    final mixed =
        RegExp(r'[A-Za-z]').hasMatch(token) && RegExp(r'\d').hasMatch(token);
    return mixed ? '<key>' : token;
  });
  // Emails. Only when there is an "@", and bounded: an unbounded pattern
  // backtracks quadratically on long text (found by the 1 MB test).
  if (out.contains('@')) {
    out = out.replaceAll(
      RegExp(r'[\w.+-]{1,64}@[\w-]{1,63}(?:\.[\w-]{1,63})+'),
      '<email>',
    );
  }
  // Amounts: "Rs 1,234", "PKR 5000", "Rs. 12,000.50".
  out = out.replaceAll(
    RegExp(r'\b(?:rs\.?|pkr)\s*[\d,]+(?:\.\d+)?', caseSensitive: false),
    '<amount>',
  );
  // Digit runs of 4+ (allowing - / space inside: CNIC 42101-1234567-1,
  // phone 0300 1234567, references 08 11111 2233445).
  out = out.replaceAllMapped(RegExp(r'\d[\d\- ]{2,}\d'), (m) {
    final digits = m[0]!.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 ? '<number>' : m[0]!;
  });
  return out;
}

/// The app-wide log. Call [AppLog.init] once at start; until then (and in
/// most tests) calls are kept in memory only.
class AppLog {
  AppLog._(this.dir);

  /// The folder holding `lifeos-YYYY-MM-DD.log`; null = memory only.
  final Directory? dir;

  static AppLog _instance = AppLog._(null);
  static AppLog get instance => _instance;

  /// Days of logs kept (AC2).
  static const keepDays = 7;

  /// Largest size of one day's file (AC2).
  static const maxFileBytes = 1024 * 1024;

  /// Recent entries in memory, for the Diagnostics screen without a disk read.
  final List<LogEntry> recent = [];
  static const _recentMax = 500;

  final List<String> _pending = [];
  Timer? _timer;

  /// The current screen, kept up to date by the router.
  static String? currentRoute;

  /// Opens the log in [dir], deleting files older than [keepDays].
  static Future<AppLog> init(Directory dir, {DateTime? now}) async {
    try {
      await dir.create(recursive: true);
      _instance = AppLog._(dir);
      await _instance._prune(now ?? DateTime.now());
    } on Object {
      _instance = AppLog._(null); // never let logging stop the app (AC6)
    }
    return _instance;
  }

  /// For tests: a fresh memory-only log.
  static void reset() => _instance = AppLog._(null);

  static void i(String area, String message) =>
      _instance.add(LogLevel.info, area, message);

  static void w(String area, String message) =>
      _instance.add(LogLevel.warning, area, message);

  static void e(String area, Object error, [StackTrace? stack]) =>
      _instance.add(LogLevel.error, area, '$error', stack: stack);

  void add(
    LogLevel level,
    String area,
    String message, {
    StackTrace? stack,
    DateTime? at,
  }) {
    try {
      final entry = LogEntry(
        time: at ?? DateTime.now(),
        level: level,
        area: area,
        message: scrubLogText(message),
        stack: stack == null ? null : scrubLogText(_trim('$stack')),
        route: currentRoute,
      );
      recent.add(entry);
      if (recent.length > _recentMax) recent.removeAt(0);
      if (dir == null) return;
      _pending.add(jsonEncode(entry.toJson()));
      // Errors are written right away; the rest in small batches, so the
      // UI never waits on the disk (AC6).
      if (level == LogLevel.error) {
        unawaited(flush());
      } else {
        _timer ??= Timer(const Duration(milliseconds: 500), flush);
      }
    } on Object {
      // Logging must never break the app.
    }
  }

  /// Writes run one after another, so Clear and reads never race a write.
  Future<void> _chain = Future.value();

  /// Writes what is queued. Safe to call any time; completes when every
  /// earlier write has finished too.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _chain = _chain.then((_) => _write());
  }

  Future<void> _write() async {
    final d = dir;
    if (d == null || _pending.isEmpty) return;
    final lines = List<String>.of(_pending);
    _pending.clear();
    try {
      final f = fileFor(DateTime.now());
      var size = await f.exists() ? await f.length() : 0;
      final out = StringBuffer();
      for (final l in lines) {
        final bytes = utf8.encode(l).length + 1;
        if (size + bytes > maxFileBytes) break; // the day's cap (AC2)
        out.writeln(l);
        size += bytes;
      }
      if (out.isNotEmpty) {
        await f.writeAsString(
          out.toString(),
          mode: FileMode.append,
          flush: true,
        );
      }
    } on Object {
      // Disk full or similar: drop the lines, keep the app running.
    }
  }

  File fileFor(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return File('${dir!.path}${Platform.pathSeparator}lifeos-$y-$m-$d.log');
  }

  /// Log files, newest first.
  Future<List<File>> files() async {
    final d = dir;
    if (d == null || !await d.exists()) return const [];
    final list = [
      for (final e in await d.list().toList())
        if (e is File && e.path.endsWith('.log')) e,
    ]..sort((a, b) => b.path.compareTo(a.path));
    return list;
  }

  /// Entries from the files (or memory), newest first.
  Future<List<LogEntry>> read({int limit = 300}) async {
    await flush();
    if (dir == null) return recent.reversed.take(limit).toList();
    final out = <LogEntry>[];
    for (final f in await files()) {
      final lines = await f.readAsLines();
      for (final line in lines.reversed) {
        try {
          out.add(LogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>));
        } on Object {
          continue; // a torn line
        }
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  /// Deletes every log (Diagnostics → Clear logs), after any write in
  /// flight.
  Future<void> clear() async {
    _pending.clear();
    await flush();
    recent.clear();
    for (final f in await files()) {
      try {
        await f.delete();
      } on Object {
        // ignore
      }
    }
  }

  Future<void> _prune(DateTime now) async {
    final oldest = DateTime(now.year, now.month, now.day - (keepDays - 1));
    final keep = fileFor(oldest).path;
    for (final f in await files()) {
      if (f.path.compareTo(keep) < 0) await f.delete();
    }
  }

  static String _trim(String stack) {
    final lines = stack.split('\n');
    return lines.length > 40 ? lines.take(40).join('\n') : stack;
  }
}
