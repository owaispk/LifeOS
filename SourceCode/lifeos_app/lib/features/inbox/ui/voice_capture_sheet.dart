// Voice capture bottom sheet for inbox (PBI-026).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../settings/settings_providers.dart';
import '../inbox_providers.dart';

/// Voice capture sheet that records speech and saves as text capture.
class VoiceCaptureSheet extends ConsumerStatefulWidget {
  const VoiceCaptureSheet({super.key});

  @override
  ConsumerState<VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

enum _VoiceState { initializing, listening, stopped, unavailable }

class _VoiceCaptureSheetState extends ConsumerState<VoiceCaptureSheet> {
  final _stt = SpeechToText();
  _VoiceState _state = _VoiceState.initializing;
  String _words = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    unawaited(_stt.stop());
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final available = await _stt.initialize();
      if (!mounted) return;
      
      if (available) {
        setState(() => _state = _VoiceState.stopped);
        // Auto-start listening
        await _startListening();
      } else {
        setState(() => _state = _VoiceState.unavailable);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = _VoiceState.unavailable);
      }
    }
  }

  Future<void> _startListening() async {
    if (_state == _VoiceState.listening) return;
    
    final lang = ref.read(settingsProvider).value?.language ?? 'en';
    final localeId = lang == 'ur' ? 'ur_PK' : 'en_US';
    
    setState(() => _state = _VoiceState.listening);
    
    await _stt.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _words = result.recognizedWords;
          });
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: localeId,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    if (mounted) {
      setState(() => _state = _VoiceState.stopped);
    }
  }

  Future<void> _save() async {
    if (_words.trim().isEmpty) return;
    
    setState(() => _saving = true);
    
    try {
      await ref.read(inboxServiceProvider).addVoice(_words.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.inboxCaptured)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.gutter,
        right: Tokens.gutter,
        top: Tokens.gutter,
        bottom: MediaQuery.of(context).viewInsets.bottom + Tokens.gutter,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  l.inboxCaptureVoice,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: Tokens.spaceL),

          // Status and visualization
          if (_state == _VoiceState.initializing)
            const Center(child: CircularProgressIndicator())
          else if (_state == _VoiceState.unavailable)
            Center(
              child: Column(
                children: [
                  Icon(Icons.mic_off, size: 48, color: theme.colorScheme.error),
                  SizedBox(height: Tokens.spaceS),
                  Text(
                    'Voice input unavailable',
                    style: theme.textTheme.bodyLarge,
                  ),
                  SizedBox(height: Tokens.spaceXs),
                  Text(
                    'Please check microphone permissions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Mic button
            Center(
              child: GestureDetector(
                onTap: _state == _VoiceState.listening 
                    ? _stopListening 
                    : _startListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _state == _VoiceState.listening
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  child: Icon(
                    _state == _VoiceState.listening ? Icons.stop : Icons.mic,
                    color: _state == _VoiceState.listening
                        ? theme.colorScheme.onError
                        : theme.colorScheme.onPrimary,
                    size: 36,
                  ),
                ),
              ),
            ),
            SizedBox(height: Tokens.spaceS),
            Center(
              child: Text(
                _state == _VoiceState.listening 
                    ? 'Listening... tap to stop' 
                    : 'Tap to start',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(height: Tokens.spaceL),

            // Transcribed text
            Container(
              constraints: const BoxConstraints(minHeight: 100),
              padding: EdgeInsets.all(Tokens.spaceM),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Tokens.radiusM),
              ),
              child: Text(
                _words.isEmpty ? 'Your words will appear here...' : _words,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _words.isEmpty 
                      ? theme.colorScheme.onSurfaceVariant 
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: Tokens.spaceL),

            // Save button
            FilledButton.icon(
              onPressed: _words.trim().isEmpty || _saving ? null : _save,
              icon: _saving 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(l.inboxSaveToInbox),
            ),
          ],
          SizedBox(height: Tokens.spaceM),
        ],
      ),
    );
  }
}
