import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../reminders/reminder_providers.dart';
import '../../settings/settings_providers.dart';
import '../domain/nl_parser.dart';
import '../domain/task_title.dart';
import '../tasks_providers.dart';
import 'task_tile.dart' show domainColor, domainLabel;

/// A parse with some parts switched off by the user (tapped chips).
class QuickParse {
  const QuickParse(this.input, this.parsed, [this.dropped = const {}]);

  final String input;
  final ParsedTask parsed;
  final Set<ParsedPart> dropped;

  ParsedTask get effective {
    var p = parsed;
    for (final d in dropped) {
      p = p.without(d);
    }
    return p;
  }

  /// The title: the input minus the words of the parts still applied.
  /// Dropping a chip puts its words back ("Meet Friday" the person).
  String get title =>
      titleFrom(input, matchedWords(parsed, dropped: dropped));

  QuickParse drop(ParsedPart p) => QuickParse(input, parsed, {...dropped, p});
}

QuickParse quickParse(String input, DateTime now) =>
    QuickParse(input, parseTask(input, now));

/// Saves a parsed task through the task service: a timed task gets its
/// default reminder (PBI-012); the notification permission is asked in
/// context.
Future<void> createFromParse(WidgetRef ref, QuickParse q) async {
  final p = q.effective;
  final now = ref.read(nowProvider)();
  final due = p.dueAt(now);
  await ref
      .read(taskServiceProvider)
      .create(
        title: q.title,
        due: due,
        allDay: due != null && !p.hasTime,
        priority: p.highPriority ? 2 : 1,
        domain: p.domain ?? 'mind',
        notes: taskNotes(title: q.title, amount: p.amount),
      );
  if (p.hasTime) {
    await ref.read(notificationGatewayProvider).requestPermission();
  }
}

/// The live preview under the field: 📅 Fri, 13 Nov · ⏰ 5:00 PM · ‼ · ●
/// Money. Tapping ✕ on a chip drops that part.
class ParseChips extends StatelessWidget {
  const ParseChips({super.key, required this.parse, required this.onDrop});

  final QuickParse parse;
  final ValueChanged<ParsedPart> onDrop;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = parse.effective;
    final chips = <(ParsedPart, Widget, String)>[
      if (p.date != null)
        (
          ParsedPart.date,
          const Text('📅'),
          formatDay(p.date!, now: DateTime.now()),
        ),
      if (p.hasTime)
        (
          ParsedPart.time,
          const Text('⏰'),
          formatTime(DateTime(0, 1, 1, p.hour!, p.minute)),
        ),
      if (p.highPriority) (ParsedPart.priority, const Text('‼'), l.parseHigh),
      if (p.amount != null)
        (ParsedPart.amount, const Text('💰'), p.amount!),
      if (p.domain != null)
        (
          ParsedPart.domain,
          CircleAvatar(radius: 5, backgroundColor: domainColor(p.domain!)),
          domainLabel(p.domain!),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      key: const ValueKey('parse-chips'),
      spacing: Tokens.spaceS,
      children: [
        for (final (part, avatar, label) in chips)
          InputChip(
            key: ValueKey('parse-chip-${part.name}'),
            avatar: avatar,
            label: Text(label),
            deleteButtonTooltipMessage: l.removeChip(label),
            onDeleted: () => onDrop(part),
          ),
      ],
    );
  }
}

// ───────────────────────────── Voice (M3) ─────────────────────────────

/// On-device speech to text (PBI-010), behind an interface for tests.
abstract interface class SpeechInput {
  /// False when this phone has no recogniser (or the mic was refused).
  Future<bool> init();

  Future<void> listen({
    required String localeId,
    required void Function(String words, bool done) onResult,
  });

  Future<void> stop();
}

class DeviceSpeechInput implements SpeechInput {
  final _stt = SpeechToText();

  @override
  Future<bool> init() async {
    try {
      // The microphone permission is asked here, after 🎤 is tapped.
      return await _stt.initialize();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words, bool done) onResult,
  }) => _stt.listen(
    onResult: (r) => onResult(r.recognizedWords, r.finalResult),
    listenOptions: SpeechListenOptions(
      partialResults: true,
      localeId: localeId,
    ),
  );

  @override
  Future<void> stop() => _stt.stop();
}

/// No recogniser (tests by default, the web preview).
class NoSpeechInput implements SpeechInput {
  const NoSpeechInput();
  @override
  Future<bool> init() async => false;
  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words, bool done) onResult,
  }) async {}
  @override
  Future<void> stop() async {}
}

final speechInputProvider = Provider<SpeechInput>(
  (ref) => const NoSpeechInput(),
);

/// M3 — full-screen voice capture: live words, the same preview chips,
/// and Create.
Future<void> showVoiceOverlay(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const VoiceOverlay(),
    ),
  );
}

class VoiceOverlay extends ConsumerStatefulWidget {
  const VoiceOverlay({super.key});

  @override
  ConsumerState<VoiceOverlay> createState() => _VoiceOverlayState();
}

enum _VoiceState { starting, listening, unavailable }

class _VoiceOverlayState extends ConsumerState<VoiceOverlay> {
  _VoiceState _state = _VoiceState.starting;
  String _words = '';
  Set<ParsedPart> _dropped = {};
  bool _saving = false;

  // Kept here: `ref` must not be used in dispose().
  late final SpeechInput _speech = ref.read(speechInputProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_speech.stop());
    super.dispose();
  }

  Future<void> _start() async {
    final speech = _speech;
    final ok = await speech.init();
    if (!mounted) return;
    if (!ok) {
      setState(() => _state = _VoiceState.unavailable);
      return;
    }
    setState(() => _state = _VoiceState.listening);
    final lang = ref.read(settingsProvider).value?.language;
    await speech.listen(
      localeId: lang == 'ur' ? 'ur_PK' : 'en_US',
      onResult: (words, _) {
        if (mounted) setState(() => _words = words);
      },
    );
  }

  Future<void> _create(QuickParse q) async {
    if (_saving || q.input.trim().isEmpty) return;
    setState(() => _saving = true);
    await _speech.stop();
    await createFromParse(ref, q);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider)();
    final q = QuickParse(_words, parseTask(_words, now), _dropped);
    return Scaffold(
      key: const ValueKey('voice-overlay'),
      appBar: AppBar(title: Text(l.voiceTitle)),
      body: Padding(
        padding: EdgeInsets.all(Tokens.spaceL),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              _state == _VoiceState.unavailable ? Icons.mic_off : Icons.mic,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            SizedBox(height: Tokens.spaceM),
            if (_state == _VoiceState.unavailable) ...[
              Text(
                l.voiceUnavailable,
                key: const ValueKey('voice-unavailable'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ] else ...[
              Text(
                _words.isEmpty ? l.voiceListening : _words,
                key: const ValueKey('voice-words'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              SizedBox(height: Tokens.spaceS),
              if (_words.isEmpty)
                Text(l.voiceHint, textAlign: TextAlign.center),
              SizedBox(height: Tokens.spaceM),
              ParseChips(
                parse: q,
                onDrop: (p) => setState(() => _dropped = {..._dropped, p}),
              ),
            ],
            const Spacer(),
            if (_state != _VoiceState.unavailable)
              FilledButton(
                key: const ValueKey('voice-create'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(Tokens.minTouchTarget),
                ),
                onPressed: _words.trim().isEmpty || _saving
                    ? null
                    : () => _create(q),
                child: Text(l.create),
              ),
          ],
        ),
      ),
    );
  }
}
