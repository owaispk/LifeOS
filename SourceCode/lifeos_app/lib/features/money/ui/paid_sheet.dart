import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../core/now_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/data_providers.dart';
import '../../../data/db/app_database.dart';
import '../../capture/capture_providers.dart';
import '../../capture/data/capture_service.dart';
import '../data/payment_service.dart';

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => PaymentService(
    ref.watch(repositoriesProvider),
    capture: _captureOrNull(ref),
    now: ref.watch(nowProvider),
  ),
);

CaptureService? _captureOrNull(Ref ref) {
  try {
    return ref.watch(captureServiceProvider);
  } on Object {
    return null; // no Vault folder (web preview): receipts unavailable
  }
}

enum _ReceiptChoice { scan, import, skip }

/// M2 — Payment completion chain (PBI-016): "✓ School fee — Rs 12,000
/// paid · Attach receipt? Scan · Import · Skip", then one transaction and
/// the stacked confirmations with a 5-second Undo.
Future<void> payWithChain(
  BuildContext context,
  WidgetRef ref,
  Payment p,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final result = await showModalBottomSheet<(_ReceiptChoice, int?)>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => _PaidSheet(payment: p),
  );
  if (result == null || !context.mounted) return;
  final (choice, amount) = result;

  CaptureDraft? receipt;
  if (choice == _ReceiptChoice.scan) {
    final pages = await ref.read(documentScannerProvider).scan();
    if (pages != null && pages.isNotEmpty) receipt = CaptureDraft.scan(pages);
  } else if (choice == _ReceiptChoice.import) {
    final files = await ref.read(fileImporterProvider).pick();
    if (files.isNotEmpty) {
      receipt = files.first.isPdf
          ? CaptureDraft.importPdf(files.first.path)
          : CaptureDraft.importImages([for (final f in files) f.path]);
    }
  }

  final service = ref.read(paymentServiceProvider);
  final done = await service.markPaid(
    p.id,
    receipt: receipt,
    amountMinor: amount,
  );
  await HapticFeedback.mediumImpact();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const ValueKey('paid-snackbar'),
        duration: const Duration(seconds: 5),
        content: Text(
          [
            l.mnPaidDone,
            if (done.receiptDocumentId != null) l.mnFiledInVault,
            l.mnLoggedInMoney,
          ].join(' · '),
        ),
        action: SnackBarAction(
          label: l.mnUndo,
          onPressed: () => service.undo(done),
        ),
      ),
    );
}

class _PaidSheet extends StatefulWidget {
  const _PaidSheet({required this.payment});
  final Payment payment;

  @override
  State<_PaidSheet> createState() => _PaidSheetState();
}

class _PaidSheetState extends State<_PaidSheet> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.payment;
    final l = context.l10n;
    final needsAmount = p.amountMinor == null;
    final entered = Money.parseMinor(_amount.text);
    final ready = !needsAmount || (entered != null && entered > 0);

    void pick(_ReceiptChoice c) =>
        Navigator.pop(context, (c, needsAmount ? entered : null));

    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.spaceM,
        right: Tokens.spaceM,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.spaceL,
      ),
      child: Column(
        key: const ValueKey('paid-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            needsAmount
                ? l.mnPaidHowMuch(p.title)
                : l.mnPaidAmountLine(p.title, Money.format(p.amountMinor!)),
            style: theme.textTheme.titleLarge,
          ),
          if (needsAmount) ...[
            SizedBox(height: Tokens.spaceM),
            TextField(
              key: const ValueKey('paid-amount'),
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: Money.prefix,
                labelText: l.mnAmountPaid,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          SizedBox(height: Tokens.spaceM),
          Text(l.mnAttachReceipt, style: theme.textTheme.titleSmall),
          SizedBox(height: Tokens.spaceS),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('paid-scan'),
                  onPressed: ready ? () => pick(_ReceiptChoice.scan) : null,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(l.mnScan),
                ),
              ),
              SizedBox(width: Tokens.spaceS),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('paid-import'),
                  onPressed: ready ? () => pick(_ReceiptChoice.import) : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l.mnImport),
                ),
              ),
              SizedBox(width: Tokens.spaceS),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('paid-skip'),
                  onPressed: ready ? () => pick(_ReceiptChoice.skip) : null,
                  child: Text(l.skip),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
