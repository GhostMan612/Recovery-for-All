// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/resources/pdf_acquirer.dart';
import '../../core/resources/resource_request.dart';
import '../../widgets/app_primitives.dart';
import 'pdf_document_view.dart';

typedef ResourcePdfLoader = Future<PdfLease> Function(
  ResourceRequest request, {
  void Function(PdfProgress)? onProgress,
  CancellationToken? cancellation,
});

class ResourcePdfScreen extends StatefulWidget {
  final ResourceRequest? request;
  final String? localPath;
  final String title;
  final Future<void> Function(ResourceRequest)? onOpenResource;
  final Future<void> Function(Uri)? onOpenExternal;
  final ResourcePdfLoader? loader;
  final PdfPlatformViewBuilder? documentBuilder;

  const ResourcePdfScreen({
    super.key,
    required ResourceRequest this.request,
    required this.onOpenResource,
    required this.onOpenExternal,
    this.loader,
    this.documentBuilder,
  })  : localPath = null,
        title = '';

  const ResourcePdfScreen.local({
    super.key,
    required String path,
    required this.title,
    this.onOpenResource,
    this.documentBuilder,
  }) : localPath = path,
       request = null,
       onOpenExternal = null,
       loader = null;

  /// The title to display: the explicit local title, else the request's own.
  String get displayTitle =>
      title.isNotEmpty ? title : (request?.title ?? 'Document');

  @override
  State<ResourcePdfScreen> createState() => _ResourcePdfScreenState();
}

class _ResourcePdfScreenState extends State<ResourcePdfScreen> {
  final PdfAcquirer _acquirer = PdfAcquirer();
  CancellationToken? _cancellation;
  PdfLease? _lease;
  PdfProgress? _progress;
  String? _error;
  int _generation = 0;
  bool _openingLink = false;

  @override
  void initState() {
    super.initState();
    if (widget.request != null) unawaited(_load());
  }

  Future<void> _releaseAfterUnmount(PdfLease? lease) async {
    if (lease == null) return;
    // PDFView is removed first. Wait through the platform view's disposal
    // frame before deleting only the lease's owned download, never a workbook.
    await WidgetsBinding.instance.endOfFrame;
    await lease.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _cancellation?.cancel();
    final oldLease = _lease;
    setState(() {
      _lease = null;
      _error = null;
      _progress = null;
    });
    await _releaseAfterUnmount(oldLease);
    if (!mounted || generation != _generation) return;
    final token = CancellationToken();
    _cancellation = token;
    try {
      void onProgress(PdfProgress progress) {
        if (mounted && generation == _generation) {
          setState(() => _progress = progress);
        }
      }
      final loader = widget.loader;
      final lease = loader == null
          ? await _acquirer.acquire(
              widget.request!,
              cancellation: token,
              onProgress: onProgress,
            )
          : await loader(
              widget.request!,
              cancellation: token,
              onProgress: onProgress,
            );
      if (!mounted || generation != _generation) {
        await lease.dispose();
        return;
      }
      setState(() => _lease = lease);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error is PdfAcquisitionException
            ? error.message
            : 'Could not download this PDF. Check your connection and retry. '
              'This chapter has not been saved for offline reading.';
      });
    }
  }

  Future<void> _openLink(String raw) async {
    if (_openingLink) return;
    final uri = Uri.tryParse(raw);
    final handler = widget.onOpenResource;
    if (uri == null || !uri.hasScheme || handler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This document link cannot be opened safely.')),
      );
      return;
    }
    _openingLink = true;
    try {
      await handler(ResourceRequest(
        uri: uri,
        title: 'Document link',
        sourceId: 'pdf-link',
      ));
    } finally {
      _openingLink = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _cancellation?.cancel();
    unawaited(_releaseAfterUnmount(_lease));
    _acquirer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final path = widget.localPath ?? _lease?.path;
    final received = _progress?.receivedBytes ?? 0;
    final total = _progress?.totalBytes;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.displayTitle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Close PDF reader',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (request != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.public, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (_lease?.finalUri ?? request.uri).host,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Open original PDF in browser',
                      onPressed: widget.onOpenExternal == null
                          ? null
                          : () => widget.onOpenExternal!(
                                _lease?.finalUri ?? request.uri,
                              ),
                      icon: const Icon(Icons.open_in_new),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: path != null
                  ? PdfDocumentView(
                      key: ValueKey(path),
                      path: path,
                      onLink: _openLink,
                      documentBuilder: widget.documentBuilder,
                    )
                  : SingleChildScrollView(
                      child: _error != null
                          ? AppErrorState(
                              title: 'PDF unavailable',
                              message: _error,
                              onRetry: _load,
                            )
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const AppLoadingState(message: 'Downloading PDF…'),
                                  LinearProgressIndicator(
                                    value: total != null && total > 0
                                        ? (received / total).clamp(0.0, 1.0)
                                        : null,
                                    semanticsLabel: 'PDF download progress',
                                  ),
                                  const SizedBox(height: 12),
                                  Text('${(received / 1024).round()} KB received'),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Reading from the official source. Requires a connection; '
                                    'the temporary copy is removed when you close the reader.',
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton.icon(
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Cancel download'),
                                  ),
                                ],
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
