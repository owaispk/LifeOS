// Capture FAB with text/voice/photo actions (PBI-026).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../capture/platform/capture_platform.dart';
import '../inbox_providers.dart';
import 'text_capture_sheet.dart';
import 'voice_capture_sheet.dart';

/// State for the expandable capture FAB.
class CaptureFabNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void expand() => state = true;
  void collapse() => state = false;
}

final captureFabExpandedProvider = NotifierProvider<CaptureFabNotifier, bool>(
  CaptureFabNotifier.new,
);

/// Expandable FAB for capturing text, voice, or photo.
class CaptureFab extends ConsumerWidget {
  const CaptureFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(captureFabExpandedProvider);
    final notifier = ref.read(captureFabExpandedProvider.notifier);
    final l = context.l10n;

    if (!expanded) {
      return FloatingActionButton(
        key: const ValueKey('capture-fab'),
        tooltip: l.inboxCapture,
        onPressed: notifier.toggle,
        child: const Icon(Icons.add),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _CaptureOption(
          key: const ValueKey('capture-text'),
          icon: Icons.text_snippet_outlined,
          label: l.inboxCaptureText,
          onTap: () {
            notifier.collapse();
            _showTextCapture(context);
          },
        ),
        SizedBox(height: Tokens.spaceS),
        _CaptureOption(
          key: const ValueKey('capture-voice'),
          icon: Icons.mic_outlined,
          label: l.inboxCaptureVoice,
          onTap: () {
            notifier.collapse();
            _showVoiceCapture(context);
          },
        ),
        SizedBox(height: Tokens.spaceS),
        _CaptureOption(
          key: const ValueKey('capture-photo'),
          icon: Icons.photo_camera_outlined,
          label: l.inboxCapturePhoto,
          onTap: () {
            notifier.collapse();
            _startPhotoCapture(context, ref);
          },
        ),
        SizedBox(height: Tokens.spaceM),
        FloatingActionButton(
          key: const ValueKey('capture-fab-close'),
          tooltip: l.inboxCloseCapture,
          onPressed: notifier.collapse,
          child: const Icon(Icons.close),
        ),
      ],
    );
  }

  void _showTextCapture(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => const TextCaptureSheet(),
    );
  }

  void _showVoiceCapture(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => const VoiceCaptureSheet(),
    );
  }

  Future<void> _startPhotoCapture(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    
    // Use the document scanner to capture photos
    const scanner = NativeDocumentScanner();
    final pages = await scanner.scan();
    
    if (pages == null || pages.isEmpty) return;
    if (!context.mounted) return;
    
    // Save each scanned page as a photo capture
    final service = ref.read(inboxServiceProvider);
    for (final path in pages) {
      await service.addPhoto(path);
    }
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pages.length == 1 
            ? l.inboxCaptured 
            : '${pages.length} ${l.inboxCaptured}'),
        ),
      );
    }
  }
}

class _CaptureOption extends StatelessWidget {
  const _CaptureOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Tokens.spaceM,
            vertical: Tokens.spaceS,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Tokens.radiusM),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge,
          ),
        ),
        SizedBox(width: Tokens.spaceS),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          child: Icon(icon),
        ),
      ],
    );
  }
}
