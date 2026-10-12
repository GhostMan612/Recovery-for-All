// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../../widgets/app_primitives.dart';

typedef PdfPlatformViewBuilder = Widget Function(PDFView configuration);

/// One native renderer for both borrowed workbooks and owned remote downloads.
/// This widget never deletes its input file.
class PdfDocumentView extends StatefulWidget {
  final String path;
  final ValueChanged<String> onLink;
  final PdfPlatformViewBuilder? documentBuilder;

  const PdfDocumentView({
    super.key,
    required this.path,
    required this.onLink,
    this.documentBuilder,
  });

  @override
  State<PdfDocumentView> createState() => _PdfDocumentViewState();
}

class _PdfDocumentViewState extends State<PdfDocumentView> {
  PDFViewController? _controller;
  Timer? _renderTimeout;
  int _pages = 0;
  int _page = 0;
  int _generation = 0;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Only arm the watchdog when the real native PDF view is what will render.
    // When a caller injects a `documentBuilder` (host tests, and any future
    // non-native renderer) the platform callbacks below never fire, so a timer
    // armed here would simply expire into the void and keep the frame pipeline
    // permanently unsettled.
    if (widget.documentBuilder == null) _armTimeout();
  }

  void _armTimeout() {
    _renderTimeout?.cancel();
    _renderTimeout = Timer(const Duration(seconds: 25), () {
      _fail('The PDF reader did not respond. You can retry or close the reader.');
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    _renderTimeout?.cancel();
    setState(() => _error = message);
  }

  void _retry() {
    setState(() {
      _error = null;
      _ready = false;
      _pages = 0;
      _page = 0;
      _controller = null;
      _generation++;
    });
    if (widget.documentBuilder == null) _armTimeout();
  }

  Future<void> _turnPage(int page) async {
    try {
      await _controller?.setPage(page);
    } catch (_) {
      _fail('This page could not be displayed. Please retry the document.');
    }
  }

  @override
  void dispose() {
    _renderTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error case final error?) {
      return SingleChildScrollView(
        child: AppErrorState(
          title: 'Could not display PDF',
          message: error,
          onRetry: _retry,
        ),
      );
    }
    final generation = _generation;

    // A substituted renderer replaces the native PDF view completely. Building
    // a `PDFView` that is then never mounted still drives its platform-view
    // state machine, which on a host test schedules frames forever and makes
    // `pumpAndSettle` time out.
    final substitute = widget.documentBuilder;
    if (substitute != null) {
      return substitute(
        PDFView(
          key: ValueKey('${widget.path}:$generation'),
          filePath: widget.path,
        ),
      );
    }

    final configuration = PDFView(
      key: ValueKey('${widget.path}:$generation'),
      filePath: widget.path,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: false,
      pageFling: false,
      pageSnap: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      preventLinkNavigation: true,
      onLinkHandler: (url) {
        if (mounted && generation == _generation && url != null) {
          widget.onLink(url);
        }
      },
      onViewCreated: (controller) {
        if (mounted && generation == _generation) {
          setState(() => _controller = controller);
        }
      },
      onRender: (pages) {
        if (!mounted || generation != _generation) return;
        _renderTimeout?.cancel();
        if (pages == null || pages < 1) {
          _fail('This document contains no readable pages.');
          return;
        }
        setState(() {
          _pages = pages;
          _ready = true;
        });
      },
      onPageChanged: (page, total) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _page = page ?? _page;
          _pages = total ?? _pages;
        });
      },
      onError: (_) {
        if (generation == _generation) {
          _fail('The document could not be read. It may be damaged or password protected.');
        }
      },
      onPageError: (_, _) {
        if (generation == _generation) {
          _fail('A page could not be read. Please retry the document.');
        }
      },
    );
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: configuration),
              if (!_ready)
                const Positioned.fill(
                  child: SingleChildScrollView(
                    child: AppLoadingState(message: 'Opening PDF…'),
                  ),
                ),
            ],
          ),
        ),
        if (_ready)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _page > 0 && _controller != null
                      ? () => _turnPage(_page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'Page ${_page + 1} of $_pages',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _page + 1 < _pages && _controller != null
                      ? () => _turnPage(_page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
