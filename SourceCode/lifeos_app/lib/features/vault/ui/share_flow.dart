// Share choices, the watermark step and the progress while a share PDF
// builds (PBI-028a).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/app_links.dart';
import '../../../core/l10n.dart';
import '../../../core/log/app_log.dart';
import '../../../core/now_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart' show dayMonth;
import '../../../data/db/app_database.dart';
import '../../capture/capture_providers.dart';
import '../../capture/data/capture_service.dart';
import '../../premium/premium_providers.dart' show premiumProvider;
import '../../profile/profile_screen.dart' show selfPersonProvider;
import '../data/share_pack.dart';
import '../share_providers.dart';
import 'document_pages.dart' show shareFilesProvider;

/// Who a watermarked copy is for.
typedef WatermarkInput = ({String recipient, String purpose});

/// Viewer → Share: the file as it is, or a watermarked copy.
Future<void> showShareChoice(
  BuildContext context,
  WidgetRef ref,
  Document doc,
  List<DocumentFile> files,
) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('share-file'),
            leading: const Icon(Icons.ios_share),
            title: Text(context.l10n.shShareFile),
            subtitle: Text(
              ref.read(premiumProvider)
                  ? context.l10n.shShareFileSub
                  : context.l10n.shShareFileSubFree,
            ),
            onTap: () => Navigator.pop(context, 'file'),
          ),
          ListTile(
            key: const ValueKey('share-watermark'),
            leading: const Icon(Icons.branding_watermark_outlined),
            title: Text(context.l10n.shShareWatermark),
            subtitle: Text(context.l10n.shShareWatermarkSub),
            onTap: () => Navigator.pop(context, 'watermark'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'file') {
    // Free shares carry the LifeOS footer, so they go out as one PDF with
    // it on every page; Premium sends the file as it is (PBI-038 F-03).
    if (!ref.read(premiumProvider)) {
      await sharePdf(context, ref, documentIds: [doc.id]);
      return;
    }
    await ref.read(shareFilesProvider)(files);
    await ref.read(shareServiceProvider).record(documentIds: [doc.id]);
    return;
  }
  final input = await askWatermark(context);
  if (input == null || !context.mounted) return;
  await sharePdf(context, ref, documentIds: [doc.id], watermark: input);
}

/// Asks who the copy is for (required) and why (optional).
Future<WatermarkInput?> askWatermark(BuildContext context) =>
    showDialog<WatermarkInput>(
      context: context,
      builder: (context) => const _WatermarkDialog(),
    );

class _WatermarkDialog extends StatefulWidget {
  const _WatermarkDialog();

  @override
  State<_WatermarkDialog> createState() => _WatermarkDialogState();
}

class _WatermarkDialogState extends State<_WatermarkDialog> {
  final _recipient = TextEditingController();
  final _purpose = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _recipient.dispose();
    _purpose.dispose();
    super.dispose();
  }

  void _submit() {
    if (_recipient.text.trim().isEmpty) {
      setState(() => _tried = true);
      return;
    }
    Navigator.pop<WatermarkInput>(context, (
      recipient: _recipient.text.trim(),
      purpose: _purpose.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.shWatermarkTitle),
      content: WatermarkFields(
        recipient: _recipient,
        purpose: _purpose,
        showError: _tried,
        onSubmitted: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('wm-share'),
          onPressed: _submit,
          child: Text(l.shShare),
        ),
      ],
    );
  }
}

/// "Shared with" and "Purpose", used by the dialog and the bundle screen.
class WatermarkFields extends StatelessWidget {
  const WatermarkFields({
    super.key,
    required this.recipient,
    required this.purpose,
    this.showError = false,
    this.onSubmitted,
  });

  final TextEditingController recipient;
  final TextEditingController purpose;
  final bool showError;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('wm-recipient'),
          controller: recipient,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l.shSharedWith,
            hintText: l.shSharedWithHint,
            errorText: showError && recipient.text.trim().isEmpty
                ? l.shRecipientRequired
                : null,
          ),
        ),
        SizedBox(height: Tokens.spaceS),
        TextField(
          key: const ValueKey('wm-purpose'),
          controller: purpose,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.shPurpose,
            hintText: l.shPurposeHint,
          ),
          onSubmitted: (_) => onSubmitted?.call(),
        ),
      ],
    );
  }
}

/// The footer free-tier shares carry (PBI-038 F-03), or null on Premium.
PromoFooter? freeTierFooter(WidgetRef ref) => ref.read(premiumProvider)
    ? null
    : PromoFooter(text: l10nNow.shPromoLine, url: promoDownloadUrl);

/// Builds the flattened PDF of [documentIds] (watermarked when
/// [watermark] is set), shows progress, sends it, records the share, and
/// optionally files a copy in the Vault. Returns whether it was shared.
Future<bool> sharePdf(
  BuildContext context,
  WidgetRef ref, {
  required List<String> documentIds,
  WatermarkInput? watermark,
  String? title,
  bool saveToVault = false,
  String? folderId,
}) async {
  final service = ref.read(shareServiceProvider);
  final send = ref.read(sendPdfProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final progress = ValueNotifier<(int, int)>((0, 0));
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => _ProgressDialog(progress: progress),
  ).whenComplete(() => open = false);

  try {
    final wm = watermark == null
        ? null
        : Watermark(
            text: watermarkText(
              name: ref.read(selfPersonProvider)?.name,
              recipient: watermark.recipient,
              purpose: watermark.purpose,
              date: ref.read(nowProvider)(),
            ),
          );
    final pdf = await service.buildPdf(
      documentIds,
      watermark: wm,
      promo: freeTierFooter(ref),
      title: title,
      direction: watermarkDirection,
      onPage: (done, total) => progress.value = (done, total),
    );
    if (open) navigator.pop();
    open = false;
    await send(pdf, bundleFileName(title));
    await service.record(
      documentIds: documentIds,
      recipient: watermark?.recipient,
      purpose: watermark?.purpose,
      watermarked: watermark != null,
      bundleTitle: documentIds.length > 1 ? title : null,
    );
    if (saveToVault) {
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}${Platform.pathSeparator}bundle');
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
        await dir.create(recursive: true);
        final file = File('${dir.path}${Platform.pathSeparator}bundle.pdf');
        await file.writeAsBytes(pdf, flush: true);
        await ref
            .read(captureServiceProvider)
            .save(
              CaptureDraft.importPdf(file.path),
              FilingDetails(
                title: bundleVaultTitle(title, ref.read(nowProvider)()),
                folderId: folderId,
              ),
            );
      } finally {
        if (await dir.exists()) await dir.delete(recursive: true);
      }
      messenger.showSnackBar(SnackBar(content: Text(l.shSavedToVault)));
    }
    return true;
  } catch (e, s) {
    AppLog.e('share', 'share PDF failed: $e', s);
    if (open) navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l.shFailed)));
    return false;
  }
}

/// The name a bundle gets in the Vault: its title, or "Shared PDF · date".
String bundleVaultTitle(String? title, DateTime now) {
  final t = title?.trim() ?? '';
  return t.isNotEmpty
      ? t
      : l10nNow.shBundleDefaultTitle('${dayMonth(now)} ${now.year}');
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.progress});
  final ValueNotifier<(int, int)> progress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('share-progress'),
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (context, p, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: p.$2 == 0 ? null : p.$1 / p.$2),
              SizedBox(height: Tokens.spaceM),
              Text(context.l10n.shPreparing('${p.$1}', '${p.$2}')),
            ],
          ),
        ),
      ),
    );
  }
}
