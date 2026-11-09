import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n.dart';
import '../../core/log/app_log.dart';
import '../../core/log/diagnostics.dart';
import '../../core/theme/tokens.dart';
import '../../shared/format.dart';

/// Builds the logs ZIP: every log file plus `device.txt` (AC5).
Future<Uint8List> buildLogsZip(Map<String, String> facts) async {
  final log = AppLog.instance;
  await log.flush();
  final archive = Archive();
  final device = facts.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  final deviceBytes = Uint8List.fromList(utf8.encode('$device\n'));
  archive.addFile(ArchiveFile('device.txt', deviceBytes.length, deviceBytes));
  final files = await log.files();
  if (files.isEmpty) {
    // Memory-only log (no folder yet): export what is in memory.
    final lines = log.recent.map((e) => jsonEncode(e.toJson())).join('\n');
    final b = Uint8List.fromList(utf8.encode(lines));
    archive.addFile(ArchiveFile('lifeos-memory.log', b.length, b));
  }
  for (final f in files) {
    final bytes = await f.readAsBytes();
    archive.addFile(ArchiveFile(f.uri.pathSegments.last, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Sends the ZIP through the share sheet; the temp file is deleted after.
final shareLogsProvider = Provider<Future<void> Function(Uint8List zip)>(
  (ref) => (zip) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}LifeOS-logs.zip');
    await f.writeAsBytes(zip, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path, mimeType: 'application/zip')]),
      );
    } finally {
      if (await f.exists()) await f.delete();
    }
  },
);

/// The device facts, read once.
final deviceFactsProvider = FutureProvider<Map<String, String>>(
  (ref) => deviceFacts(),
);

/// Settings → Diagnostics (PBI-030): recent log entries, errors first in
/// colour, Share / Clear / test error.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  List<LogEntry> _entries = const [];
  bool _errorsOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppLog.instance.read();
    if (mounted) setState(() => _entries = list);
  }

  Future<void> _share() async {
    final facts = ref.read(deviceFactsProvider).value ?? await deviceFacts();
    final zip = await buildLogsZip(facts);
    await ref.read(shareLogsProvider)(zip);
  }

  Future<void> _clear() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = context.l10n.dgCleared;
    await AppLog.instance.clear();
    await _load();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _testError() async {
    AppLog.e(
      'diagnostics',
      StateError(context.l10n.dgTestErrorText),
      StackTrace.current,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final facts = ref.watch(deviceFactsProvider).value ?? const {};
    final shown = _errorsOnly
        ? _entries.where((e) => e.level == LogLevel.error).toList()
        : _entries;
    final errors = _entries.where((e) => e.level == LogLevel.error).length;

    return Scaffold(
      appBar: AppBar(title: Text(l.dgTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const ValueKey('diag-list'),
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.all(Tokens.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final v in facts.values)
                    Text(v, style: theme.textTheme.bodySmall),
                  const SizedBox(height: Tokens.spaceS),
                  Text(l.dgPrivacy, style: theme.textTheme.bodySmall),
                  const SizedBox(height: Tokens.spaceS),
                  Text(
                    '${l.dgCount(_entries.length)} · ${l.dgErrorsCount(errors)}',
                    key: const ValueKey('diag-counts'),
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceM),
              child: Wrap(
                spacing: Tokens.spaceS,
                runSpacing: Tokens.spaceS,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('diag-share'),
                    onPressed: _share,
                    icon: const Icon(Icons.ios_share),
                    label: Text(l.dgShare),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('diag-clear'),
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: Text(l.dgClear),
                  ),
                  TextButton(
                    key: const ValueKey('diag-test-error'),
                    onPressed: _testError,
                    child: Text(l.dgTestError),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              key: const ValueKey('diag-errors-only'),
              title: Text(l.dgErrorsOnly),
              value: _errorsOnly,
              onChanged: (v) => setState(() => _errorsOnly = v),
            ),
            const Divider(height: 1),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Tokens.spaceL),
                child: Center(child: Text(l.dgEmpty)),
              ),
            for (final e in shown) _EntryTile(e),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile(this.e);
  final LogEntry e;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = e.level == LogLevel.error;
    final color = switch (e.level) {
      LogLevel.error => theme.colorScheme.error,
      LogLevel.warning => Tokens.scoreMid,
      LogLevel.info => theme.colorScheme.onSurfaceVariant,
    };
    // 24-hour with seconds: easier to line up with other logs.
    String two(int n) => n.toString().padLeft(2, '0');
    final when =
        '${formatDay(e.time)} ${two(e.time.hour)}:${two(e.time.minute)}:'
        '${two(e.time.second)}';
    return ExpansionTile(
      key: ValueKey('diag-entry-${e.time.microsecondsSinceEpoch}'),
      leading: Icon(
        isError
            ? Icons.error_outline
            : e.level == LogLevel.warning
            ? Icons.warning_amber
            : Icons.info_outline,
        color: color,
      ),
      title: Text(
        e.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: isError ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      subtitle: Text(
        [when, e.area, ?e.route].join(' · '),
        style: theme.textTheme.bodySmall,
      ),
      children: [
        if (e.stack != null)
          Padding(
            padding: const EdgeInsets.all(Tokens.spaceM),
            child: SelectableText(
              e.stack!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    );
  }
}
