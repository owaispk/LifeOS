import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/l10n.dart';

/// Merges scanned page images (JPEG/PNG bytes) into one PDF, one page per
/// image, each image fitted to an A4 page in capture order (PBI-003 AC2).
Future<Uint8List> buildPdf(List<Uint8List> pages) async {
  if (pages.isEmpty) throw ArgumentError('No pages to build a PDF from');
  final doc = pw.Document(title: l10nNow.cpPdfTitle, creator: 'LifeOS');
  for (final bytes in pages) {
    final image = pw.MemoryImage(bytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  return doc.save();
}
