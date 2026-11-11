// Providers for watermarked shares, bundles and share history (PBI-028a).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart' show TextDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n.dart';
import '../../core/plaintext_cache.dart';
import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../../shared/format.dart';
import '../security/security_providers.dart';
import 'data/share_pack.dart';
import 'data/share_service.dart';

/// PDF page rendering: pdfx on phones, a fake in tests.
final pdfRasterizerProvider = Provider<PdfRasterizer>(
  (ref) => const PdfxRasterizer(),
);

final shareServiceProvider = Provider<ShareService>(
  (ref) => ShareService(
    ref.watch(repositoriesProvider),
    builder: SharePackBuilder(
      read: ref.watch(vaultFilesProvider).read,
      rasterizer: ref.watch(pdfRasterizerProvider),
    ),
    now: ref.watch(nowProvider),
  ),
);

/// Sends one PDF through the OS share sheet under [fileName], with the
/// neutral message, and deletes the temporary copy afterwards (AC2).
final sendPdfProvider =
    Provider<Future<void> Function(Uint8List bytes, String fileName)>(
      (ref) => (bytes, fileName) async {
        final tmp = await getTemporaryDirectory();
        await shareTempFile(
          bytes,
          fileName,
          Directory('${tmp.path}${Platform.pathSeparator}share'),
          (path) => SharePlus.instance.share(
            ShareParams(
              files: [XFile(path, mimeType: 'application/pdf')],
              text: l10nNow.vtSharedFrom,
            ),
          ),
        );
        // share_plus keeps its own copy; it goes too (AC2).
        await clearShareSheetCopies(tmp);
      },
    );

final shareHistoryProvider = StreamProvider<List<ShareEvent>>(
  (ref) => ref.watch(shareServiceProvider).watchHistory(),
);

final shareCountProvider = StreamProvider.family<int, String>(
  (ref, documentId) =>
      ref.watch(shareServiceProvider).watchShareCount(documentId),
);

final bundleTemplatesProvider = StreamProvider<List<BundleTemplate>>(
  (ref) => ref.watch(shareServiceProvider).watchTemplates(),
);

/// "Shared by Ali with ABC Bank for account opening — 10 Nov 2026", in the
/// app's language. Without a real name (empty, or still the seeded "Me"):
/// "Shared with…", since "Shared by Me" tells the recipient nothing.
String watermarkText({
  String? name,
  required String recipient,
  String? purpose,
  required DateTime date,
}) {
  final l = l10nNow;
  var n = name?.trim() ?? '';
  if (n.toLowerCase() == 'me') n = '';
  final p = purpose?.trim() ?? '';
  final r = recipient.trim();
  final d = '${dayMonth(date)} ${date.year}';
  return switch ((n.isEmpty, p.isEmpty)) {
    (false, false) => l.shWmFull(n, r, p, d),
    (false, true) => l.shWmNoPurpose(n, r, d),
    (true, false) => l.shWmNoName(r, p, d),
    (true, true) => l.shWmNoNameNoPurpose(r, d),
  };
}

/// The watermark's text direction follows the app language (AC7).
TextDirection get watermarkDirection => AppLocale.current.languageCode == 'ur'
    ? TextDirection.rtl
    : TextDirection.ltr;
