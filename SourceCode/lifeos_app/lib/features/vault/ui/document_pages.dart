import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../../security/security_providers.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/db/app_database.dart';

/// A file's plaintext, decrypted in memory (PBI-024). Auto-disposed, so
/// decrypted bytes don't outlive the screen that shows them.
final fileBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, DocumentFile>(
      (ref, f) => ref.watch(vaultFilesProvider).read(f),
    );

/// Builds a pinch-zoomable PDF view for a file. pdfx (pdfium) on phones,
/// opened from decrypted bytes; replaced in tests, where native PDF
/// rendering isn't available.
final pdfPagesBuilderProvider = Provider<Widget Function(DocumentFile file)>(
  (ref) =>
      (file) => _PdfxPages(file: file),
);

/// The neutral name a shared file gets: "Document.pdf", or "Document 2.jpg"
/// when several are shared — never the title, number or internal id.
String neutralShareName(DocumentFile f, int index, int count) =>
    'Document${count > 1 ? ' ${index + 1}' : ''}'
    '.${f.mime == 'application/pdf' ? 'pdf' : 'jpg'}';

/// Writes [files]' plaintext into a fresh [shareDir] under their neutral
/// names and returns the paths. Android's share sheet shows (and sends) the
/// file's real name, so a display-name override is not enough (device QA).
/// These are the only plaintext copies ever written; the caller deletes
/// them once the share sheet closes, and the folder is emptied first.
Future<List<String>> prepareShareCopies(
  List<DocumentFile> files,
  Directory shareDir,
  Future<Uint8List> Function(DocumentFile f) read,
) async {
  if (await shareDir.exists()) await shareDir.delete(recursive: true);
  await shareDir.create(recursive: true);
  final paths = <String>[];
  for (var i = 0; i < files.length; i++) {
    final out = File(
      '${shareDir.path}${Platform.pathSeparator}'
      '${neutralShareName(files[i], i, files.length)}',
    );
    await out.writeAsBytes(await read(files[i]), flush: true);
    paths.add(out.path);
  }
  return paths;
}

/// Sends files through the OS share sheet (PBI-007 AC5): files only, with a
/// neutral message and file name — never the title or contents.
final shareFilesProvider = Provider<Future<void> Function(List<DocumentFile>)>(
  (ref) => (files) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}${Platform.pathSeparator}share');
    final copies = await prepareShareCopies(
      files,
      dir,
      ref.read(vaultFilesProvider).read,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            for (var i = 0; i < files.length; i++)
              XFile(copies[i], mimeType: files[i].mime),
          ],
          text: l10nNow.vtSharedFrom,
        ),
      );
    } finally {
      // No plaintext left behind (PBI-024).
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  },
);

/// All pages of a document: images in a swipeable, zoomable pager with
/// page dots; a PDF in the PDF viewer (PBI-007 AC1).
class DocumentPages extends ConsumerStatefulWidget {
  const DocumentPages({super.key, required this.files});

  final List<DocumentFile> files;

  @override
  ConsumerState<DocumentPages> createState() => _DocumentPagesState();
}

class _DocumentPagesState extends ConsumerState<DocumentPages> {
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.files.where((f) => f.localPath != null).toList();
    if (files.isEmpty) {
      return Center(child: Text(context.l10n.vtNoPages));
    }
    if (files.first.mime == 'application/pdf') {
      return KeyedSubtree(
        key: const ValueKey('viewer-pdf'),
        child: ref.watch(pdfPagesBuilderProvider)(files.first),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          key: const ValueKey('viewer-pages'),
          controller: _pager,
          itemCount: files.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => InteractiveViewer(
            key: ValueKey('viewer-page-$i'),
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: kIsWeb
                  ? const Icon(Icons.image_outlined, size: 64)
                  : _DecryptedImage(file: files[i]),
            ),
          ),
        ),
        if (files.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            child: Semantics(
              label: context.l10n.vtPageOf('${_page + 1}', '${files.length}'),
              child: Row(
                key: const ValueKey('viewer-dots'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < files.length; i++)
                    Container(
                      width: i == _page ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (files.length > 1)
          Positioned(
            top: Tokens.spaceS,
            right: Tokens.spaceM,
            child: Chip(
              key: const ValueKey('viewer-page-label'),
              label: Text('${_page + 1} / ${files.length}'),
            ),
          ),
      ],
    );
  }
}

/// An image page decrypted in memory.
class _DecryptedImage extends ConsumerWidget {
  const _DecryptedImage({required this.file});
  final DocumentFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(fileBytesProvider(file))
        .when(
          data: (bytes) => Image.memory(bytes, fit: BoxFit.contain),
          // Decryption takes a moment: a still placeholder, no spinner.
          loading: () => const Icon(Icons.image_outlined, size: 64),
          error: (_, _) => const Icon(Icons.broken_image_outlined, size: 64),
        );
  }
}

class _PdfxPages extends ConsumerStatefulWidget {
  const _PdfxPages({required this.file});
  final DocumentFile file;

  @override
  ConsumerState<_PdfxPages> createState() => _PdfxPagesState();
}

class _PdfxPagesState extends ConsumerState<_PdfxPages> {
  late final _controller = PdfControllerPinch(
    document: ref
        .read(vaultFilesProvider)
        .read(widget.file)
        .then(PdfDocument.openData),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PdfViewPinch(controller: _controller);
}
