import 'package:drift/drift.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

import '../../../data/repositories/repositories.dart';
import '../data/capture_service.dart';
import 'doc_classifier.dart';
import 'field_extractor.dart';
import 'ocr_rows.dart';
import '../../../core/log/app_log.dart';

/// Reads text from page images, on-device (PBI-004).
abstract interface class TextReader {
  /// All pages' text, joined in page order. Empty if nothing was read.
  Future<String> read(List<String> imagePaths);
}

/// Google ML Kit text recognition (Latin script), fully offline.
/// Device-only: exercised on Android/iOS, not in unit tests.
class MlKitTextReader implements TextReader {
  const MlKitTextReader();

  @override
  Future<String> read(List<String> imagePaths) async {
    final recognizer = mlkit.TextRecognizer();
    try {
      final pages = <String>[];
      for (final path in imagePaths) {
        final result = await recognizer.processImage(
          mlkit.InputImage.fromFilePath(path),
        );
        // Labels and values on one printed row back on one line.
        final boxes = [
          for (final block in result.blocks)
            for (final line in block.lines)
              OcrBox(
                line.text,
                line.boundingBox.left,
                line.boundingBox.top,
                line.boundingBox.right,
                line.boundingBox.bottom,
              ),
        ];
        pages.add(boxes.isEmpty ? result.text : rowsToText(boxes));
      }
      return pages.join('\n');
    } finally {
      await recognizer.close();
    }
  }
}

/// No OCR (web preview, before setup): every capture is "Unclassified".
class NoTextReader implements TextReader {
  const NoTextReader();

  @override
  Future<String> read(List<String> imagePaths) async => '';
}

/// What the confirm screen starts from.
class DocumentAnalysis {
  const DocumentAnalysis({
    required this.ocrText,
    required this.classification,
    required this.fields,
    required this.hints,
  });

  static const empty = DocumentAnalysis(
    ocrText: '',
    classification: Classification('other', 0, {}),
    fields: {},
    hints: [],
  );

  final String ocrText;
  final Classification classification;
  final Map<String, Extracted> fields;

  /// Per-issuer labels that were applied (for re-extraction on type change).
  final List<IssuerHint> hints;

  bool get unreadable => ocrText.trim().isEmpty;

  /// Re-extracts for a different [type] the user picked.
  Map<String, Extracted> fieldsFor(String type) =>
      extractFields(type, ocrText, hints: hints);
}

/// Reads, classifies and extracts a draft. Imported PDFs aren't OCR'd in
/// the MVP (PBI-004 grooming) and come back empty → "Unclassified".
Future<DocumentAnalysis> analyzeDraft(
  CaptureDraft draft,
  TextReader reader,
  Repositories repos,
) async {
  if (draft.isPdfImport || draft.pagePaths.isEmpty) {
    return DocumentAnalysis.empty;
  }
  final text = await reader.read(draft.pagePaths);
  if (text.trim().isEmpty) return DocumentAnalysis.empty;

  final classification = classify(text);
  AppLog.i(
    'ocr',
    'type ${classification.type} '
        '${(classification.confidence * 100).round()}% · '
        '${draft.pagePaths.length} page(s)',
  );
  var fields = extractFields(classification.type, text);
  var hints = const <IssuerHint>[];

  // Per-issuer learning (AC6): earlier corrections for this issuer.
  final issuer = fields[Fields.issuer]?.value;
  if (issuer != null) {
    hints = await hintsForIssuer(repos, issuer);
    if (hints.isNotEmpty) {
      fields = extractFields(classification.type, text, hints: hints);
    }
  }
  return DocumentAnalysis(
    ocrText: text,
    classification: classification,
    fields: fields,
    hints: hints,
  );
}

/// Labels learned from the user's corrections on documents from [issuer].
Future<List<IssuerHint>> hintsForIssuer(
  Repositories repos,
  String issuer,
) async {
  final docs = await repos.documents.getWhere(
    (d) => d.issuer.equals(issuer) & d.ocrText.isNotNull(),
  );
  if (docs.isEmpty) return const [];
  final byId = {for (final d in docs) d.id: d};
  final corrected = await repos.extractedFields.getWhere(
    (f) => f.corrected.equals(true) & f.documentId.isIn(byId.keys),
  );
  // Newest corrections first, so the latest teaching wins.
  corrected.sort((a, b) => b.id.compareTo(a.id));
  return learnHints([
    for (final f in corrected)
      (field: f.field, value: f.value, ocrText: byId[f.documentId]!.ocrText!),
  ]);
}
