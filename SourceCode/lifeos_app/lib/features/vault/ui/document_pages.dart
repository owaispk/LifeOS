import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/db/app_database.dart';

/// Builds a pinch-zoomable PDF view for a file. pdfx (pdfium) on phones;
/// replaced in tests, where native PDF rendering isn't available.
final pdfPagesBuilderProvider = Provider<Widget Function(String path)>(
  (ref) =>
      (path) => _PdfxPages(path: path),
);

/// Sends files through the OS share sheet (PBI-007 AC5): files only, with a
/// neutral message and file name — never the title or contents.
final shareFilesProvider = Provider<Future<void> Function(List<DocumentFile>)>(
  (ref) => (files) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final f in files) XFile(f.localPath!, mimeType: f.mime)],
        fileNameOverrides: [
          for (var i = 0; i < files.length; i++)
            'Document${files.length > 1 ? ' ${i + 1}' : ''}'
                '.${files[i].mime == 'application/pdf' ? 'pdf' : 'jpg'}',
        ],
        text: 'Shared from LifeOS',
      ),
    );
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
      return const Center(child: Text('No pages stored for this document'));
    }
    if (files.first.mime == 'application/pdf') {
      return KeyedSubtree(
        key: const ValueKey('viewer-pdf'),
        child: ref.watch(pdfPagesBuilderProvider)(files.first.localPath!),
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
                  : Image.file(File(files[i].localPath!), fit: BoxFit.contain),
            ),
          ),
        ),
        if (files.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            child: Semantics(
              label: 'Page ${_page + 1} of ${files.length}',
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

class _PdfxPages extends StatefulWidget {
  const _PdfxPages({required this.path});
  final String path;

  @override
  State<_PdfxPages> createState() => _PdfxPagesState();
}

class _PdfxPagesState extends State<_PdfxPages> {
  late final _controller = PdfControllerPinch(
    document: PdfDocument.openFile(widget.path),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PdfViewPinch(controller: _controller);
}
