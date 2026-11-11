// Watermarked shares and document bundles (PBI-028a). Everything runs on
// the phone; the Vault originals are never modified.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../../../core/plaintext_cache.dart';
import '../../../data/db/app_database.dart';

/// "Shared by {name} with {recipient} for {purpose} — {date}".
class Watermark {
  const Watermark({required this.text});

  /// The full line, already worded in the app's language.
  final String text;
}

/// Turns a PDF into page images (JPEG or PNG), one per page, at about [dpi].
/// pdfx on phones; replaced in tests, where native rendering isn't
/// available.
abstract interface class PdfRasterizer {
  /// Pages one at a time, so each can be stamped while the next renders.
  Stream<Uint8List> rasterize(Uint8List pdf, {int dpi = 150});
}

class PdfxRasterizer implements PdfRasterizer {
  const PdfxRasterizer({this.cacheDir = getTemporaryDirectory});

  /// Where the short-lived plaintext copy goes (see [openPdfPrivately]).
  final Future<Directory> Function() cacheDir;

  @override
  Stream<Uint8List> rasterize(Uint8List pdf, {int dpi = 150}) async* {
    final doc = await openPdfPrivately(await cacheDir(), pdf);
    try {
      for (var i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);
        try {
          // Page size is in points (1/72 in).
          final scale = dpi / 72;
          final image = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            // JPEG: encoded natively, decodes fast, small in the PDF.
            format: pdfx.PdfPageImageFormat.jpeg,
            quality: 90,
            backgroundColor: '#FFFFFF',
          );
          if (image != null) yield image.bytes;
        } finally {
          await page.close();
        }
      }
    } finally {
      await doc.close();
    }
  }
}

/// One document's stored files, decrypted, in page order.
typedef ReadFile = Future<Uint8List> Function(DocumentFile f);

/// Builds the flattened PDF that leaves the phone: the documents' pages in
/// the given order, each optionally stamped with [Watermark].
class SharePackBuilder {
  SharePackBuilder({required this.read, required this.rasterizer});

  final ReadFile read;
  final PdfRasterizer rasterizer;

  /// How many pages are stamped at once.
  static const stampParallelism = 4;

  /// Where the time went in the last build, for the diagnostics log.
  String lastTimings = '';

  /// Page images (encoded) for one document, in page order.
  Stream<Uint8List> pagesOf(List<DocumentFile> files) async* {
    final sorted = [...files]..sort((a, b) => a.pageNo.compareTo(b.pageNo));
    for (final f in sorted) {
      final bytes = await read(f);
      if (f.mime == 'application/pdf') {
        yield* rasterizer.rasterize(bytes);
      } else {
        yield bytes;
      }
    }
  }

  /// The final page images, in share order, stamped when [watermark] is
  /// set. [onPage] reports progress (done, pages found so far).
  ///
  /// Reading and rendering run one page at a time while finished pages are
  /// stamped alongside, a few at once: the JPEG encoding runs in isolates,
  /// so this uses the phone's other cores (AC8).
  Future<List<Uint8List>> finalPages(
    List<List<DocumentFile>> documents, {
    Watermark? watermark,
    TextDirection direction = TextDirection.ltr,
    void Function(int done, int total)? onPage,
  }) async {
    final sw = Stopwatch()..start();
    final jobs = <Future<Uint8List>>[];
    final slots = _Slots(stampParallelism);
    var total = 0;
    var done = 0;
    for (final d in documents) {
      await for (final page in pagesOf(d)) {
        total++;
        jobs.add(
          (watermark == null
                  ? Future.value(page)
                  : slots.run(
                      () => stampWatermark(page, watermark.text, direction),
                    ))
              .then((out) {
                onPage?.call(++done, total);
                return out;
              }),
        );
      }
    }
    if (jobs.isEmpty) throw ArgumentError('Nothing to share');
    final renderMs = sw.elapsedMilliseconds;
    final out = await Future.wait(jobs);
    lastTimings =
        'pages ${out.length}, read+render $renderMs ms, '
        'all stamped ${sw.elapsedMilliseconds} ms';
    return out;
  }

  /// [documents] in share order (each a list of its files) → PDF bytes.
  Future<Uint8List> build(
    List<List<DocumentFile>> documents, {
    Watermark? watermark,
    String? title,
    TextDirection direction = TextDirection.ltr,
    void Function(int done, int total)? onPage,
  }) async {
    final stamped = await finalPages(
      documents,
      watermark: watermark,
      direction: direction,
      onPage: onPage,
    );
    final sw = Stopwatch()..start();
    final doc = pw.Document(title: title ?? '', creator: 'LifeOS');
    for (final bytes in stamped) {
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    final bytes = await doc.save();
    lastTimings = '$lastTimings, pdf ${sw.elapsedMilliseconds} ms';
    return bytes;
  }
}

/// Runs at most [size] tasks at a time.
class _Slots {
  _Slots(this.size);
  final int size;
  int _busy = 0;
  final _waiting = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() task) async {
    if (_busy >= size) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _busy++;
    try {
      return await task();
    } finally {
      _busy--;
      if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
    }
  }
}

/// Draws [text] diagonally, repeated and semi-transparent, across the page
/// image, plus a footer line, and returns a JPEG. The text is burned into
/// the pixels, so it can't be removed by editing the PDF's text (AC1).
/// Uses Flutter's text engine, so Urdu is shaped correctly (AC7).
Future<Uint8List> stampWatermark(
  Uint8List pageImage,
  String text,
  TextDirection direction,
) async {
  final codec = await ui.instantiateImageCodec(pageImage);
  final frame = await codec.getNextFrame();
  final page = frame.image;
  final w = page.width.toDouble();
  final h = page.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
  canvas.drawImage(page, Offset.zero, Paint());

  // Repeated diagonal lines, about 25% opaque.
  final diagonal = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0x40303030),
        fontSize: math.max(12, w * 0.032),
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: direction,
    maxLines: 1,
  )..layout();
  canvas.save();
  canvas.translate(w / 2, h / 2);
  canvas.rotate(-math.pi / 6);
  final span = math.sqrt(w * w + h * h);
  final step = diagonal.height * 4;
  for (var y = -span / 2; y < span / 2; y += step) {
    for (
      var x = -span / 2 - (y / step % 2) * diagonal.width / 2;
      x < span / 2;
      x += diagonal.width + w * 0.08
    ) {
      diagonal.paint(canvas, Offset(x, y));
    }
  }
  canvas.restore();

  // Footer line on a light band.
  final footer = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0xFF202020),
        fontSize: math.max(10, w * 0.02),
      ),
    ),
    textDirection: direction,
    maxLines: 2,
    textAlign: TextAlign.center,
  )..layout(maxWidth: w * 0.94);
  final band = footer.height + w * 0.02;
  canvas.drawRect(
    Rect.fromLTWH(0, h - band, w, band),
    Paint()..color = const Color(0xD9FFFFFF),
  );
  footer.paint(canvas, Offset((w - footer.width) / 2, h - band + w * 0.01));

  final picture = recorder.endRecording();
  final out = await picture.toImage(page.width, page.height);
  final raw = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = page.width;
  final height = page.height;
  page.dispose();
  out.dispose();
  final pixels = raw!.buffer.asUint8List();
  // JPEG encoding is pure Dart: off the UI thread (AC8).
  return Isolate.run(() {
    final rgba = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: pixels.buffer,
      numChannels: 4,
    );
    // 4:2:0 like any camera or scanner: less work, smaller file.
    return Uint8List.fromList(
      img.encodeJpg(rgba, quality: 85, chroma: img.JpegChroma.yuv420),
    );
  });
}

/// The bundle's file name: its title, made safe, or the neutral name.
String bundleFileName(String? title) {
  final t = (title ?? '').replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return '${t.isEmpty ? 'Document' : t}.pdf';
}
