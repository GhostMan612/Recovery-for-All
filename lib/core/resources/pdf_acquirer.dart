// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'resource_policy.dart';
import 'resource_request.dart';

/// Cooperative cancellation shared between the reader screen and the fetcher.
///
/// The token cannot interrupt a socket read that is already in flight; it is
/// checked between streamed chunks, so even a very large response stops at the
/// next chunk boundary and the partial file is discarded.
class CancellationToken {
  bool _cancelled = false;
  final StreamController<void> _controller = StreamController<void>.broadcast();

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> get whenCancelled => _controller.stream.first;

  void dispose() => _controller.close();
}

/// Download progress for the reader's linear indicator.
class PdfProgress {
  final int receivedBytes;
  final int? totalBytes;

  const PdfProgress({required this.receivedBytes, this.totalBytes});

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }
}

/// An acquired document owned by the reader.
///
/// Only a lease produced by [PdfAcquirer] may be disposed. A workbook file handed
/// to the reader through `ResourcePdfScreen.local` is caller-owned and is never
/// wrapped in a lease, so temporary cleanup cannot delete an imported workbook.
class PdfLease {
  final String path;
  final Uri finalUri;
  final int byteCount;

  /// True only for files this acquirer created and is responsible for removing.
  final bool ownsTemporaryFile;
  final void Function(String path)? onDisposed;

  PdfLease({
    required this.path,
    required this.finalUri,
    required this.byteCount,
    required this.ownsTemporaryFile,
    this.onDisposed,
  });

  /// Removes the owned temporary file.
  ///
  /// Idempotent, and a no-op for a non-owning lease, so the caller's
  /// unmount-then-delete ordering does not have to be exactly right for a
  /// caller-owned file to survive. Repeated calls simply find no file the second
  /// time; there is no mutable state on the lease itself.
  Future<void> dispose() async {
    if (!ownsTemporaryFile) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A leftover temporary file is not worth failing the reader over; the
      // prefix-scoped sweep on the next acquisition removes stragglers.
    } finally {
      onDisposed?.call(path);
    }
  }
}

/// A failure with a user-presentable message. Carries no URL or recovery data.
class PdfAcquisitionException implements Exception {
  final String message;

  const PdfAcquisitionException(this.message);

  @override
  String toString() => 'PdfAcquisitionException: $message';
}

/// Injectable temp-directory seam so host tests never touch real device paths.
typedef DirectoryProvider = Future<Directory> Function();
typedef HostResolver = Future<List<InternetAddress>> Function(String host);

/// Streams a remote PDF into a validated, app-private temporary file.
///
/// Security properties enforced here rather than trusted from the caller:
/// HTTPS only; the [ResourcePolicy] allowlist re-checked at **every** redirect
/// hop; a streamed byte ceiling that holds even when `Content-Length` is absent
/// or dishonest; PDF media-type, header and EOF checks; and an atomic partial-
/// file rename. A 200 response that is really an HTML error or consent page is
/// rejected rather than handed to the renderer.
class PdfAcquirer {
  /// Conservative resource ceiling. Current endpoint sizes have not been
  /// independently verified against this limit.
  static const int maximumBytes = 25 * 1024 * 1024;

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration transferTimeout = Duration(seconds: 60);

  /// At most this many redirect hops before the chain is refused.
  static const int maximumRedirects = 5;

  /// All owned temporary files share this prefix so cleanup sweeps can be
  /// scoped strictly to this feature's own leftovers.
  static const String temporaryFilePrefix = 'rfa_resource_pdf_';
  static const Duration abandonedFileRetention = Duration(days: 1);

  static const List<int> _pdfMagic = [0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-
  static const List<int> _pdfEof = [0x25, 0x25, 0x45, 0x4F, 0x46]; // %%EOF
  static final Set<String> _activeTemporaryPaths = <String>{};

  final http.Client _client;
  final bool _ownsClient;
  final ResourcePolicy _policy;
  final DirectoryProvider _directoryProvider;
  final HostResolver _hostResolver;
  final Random _random;

  /// Injectable for tests; production always uses [maximumBytes]. Overridable so
  /// a host test can prove the ceiling holds without streaming 25 MiB.
  final int byteCeiling;

  PdfAcquirer({
    http.Client? client,
    ResourcePolicy? policy,
    DirectoryProvider? directoryProvider,
    HostResolver? hostResolver,
    Random? random,
    int? byteCeiling,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _policy = policy ?? ResourcePolicy.defaultPolicy,
        _directoryProvider = directoryProvider ?? getTemporaryDirectory,
        _hostResolver = hostResolver ?? InternetAddress.lookup,
        _random = random ?? Random.secure(),
        byteCeiling = byteCeiling ?? maximumBytes;

  /// Closes only the client created by this acquirer.
  ///
  /// Injected clients remain owned by their caller, which keeps test and
  /// application-level client lifetimes explicit.
  void close() {
    if (_ownsClient) _client.close();
  }

  /// Downloads the request's document and returns a disposable lease.
  ///
  /// Throws [PdfAcquisitionException] with a presentable message for every
  /// failure mode; a partially written file is never returned.
  Future<PdfLease> acquire(
    ResourceRequest request, {
    void Function(PdfProgress)? onProgress,
    CancellationToken? cancellation,
  }) async {
    try {
      final classified = _policy.classify(request);
      if (classified.route != ResourceRoute.pdf) {
        throw PdfAcquisitionException(
          'This link is not an approved PDF source. ${classified.reason}',
        );
      }

      await _sweepAbandonedTemporaries();

      // Follows redirects by hand so the allowlist is re-checked at each hop.
      // `http.Client` with automatic redirects would let a chain walk to an
      // unaudited host without a single policy call.
      final target = await _resolveVerifiedTarget(request.uri, cancellation);

      final directory = await _directoryProvider();
      final name = '$temporaryFilePrefix'
          '${DateTime.now().microsecondsSinceEpoch}_'
          '${_random.nextInt(1 << 32).toRadixString(16)}.pdf';
      final partial = File(
        '${directory.path}${Platform.pathSeparator}$name.part',
      );
      final complete = File(
        '${directory.path}${Platform.pathSeparator}$name',
      );

      _activeTemporaryPaths.add(partial.path);
      try {
        final bytes = await _writeBounded(
          partial,
          target.stream,
          cancellation,
          onProgress,
          declaredLength: target.contentLength,
        );
        if (cancellation?.isCancelled ?? false) {
          throw const PdfAcquisitionException('The download was cancelled.');
        }
        await partial.rename(complete.path);
        _activeTemporaryPaths.remove(partial.path);
        _activeTemporaryPaths.add(complete.path);
        // The path is handed to the renderer only after the bytes are proven to
        // be a PDF and the complete file has been atomically renamed, so the
        // native view never mounts an incomplete download.
        return PdfLease(
          path: complete.path,
          finalUri: target.uri,
          byteCount: bytes,
          ownsTemporaryFile: true,
          onDisposed: (path) {
            _activeTemporaryPaths.remove(path);
          },
        );
      } catch (_) {
        await _deleteQuietly(partial);
        await _deleteQuietly(complete);
        _activeTemporaryPaths
          ..remove(partial.path)
          ..remove(complete.path);
        rethrow;
      }
    } on PdfAcquisitionException {
      rethrow;
    } catch (error) {
      if (_isConnectivityFailure(error)) {
        throw const PdfAcquisitionException(
          'You appear to be offline. This chapter is not saved on your device — '
          'connect to the internet and retry.',
        );
      }
      throw const PdfAcquisitionException(
        'Could not download this PDF. Check your connection and retry.',
      );
    }
  }

  /// Issues the GET, following redirects manually and validating the final
  /// response before any bytes are written.
  Future<_VerifiedTarget> _resolveVerifiedTarget(
    Uri start,
    CancellationToken? cancellation,
  ) async {
    var current = start;
    for (var hop = 0; hop <= maximumRedirects; hop++) {
      if (cancellation?.isCancelled ?? false) {
        throw const PdfAcquisitionException('The download was cancelled.');
      }

      await _rejectNonPublicResolution(current);
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..maxRedirects = 0;
      final response = await _client.send(request).timeout(connectTimeout);

      final status = response.statusCode;
      final location = response.headers['location'];

      if (status >= 300 && status < 400) {
        // Cancel the redirect body instead of draining an unbounded response.
        await response.stream.listen((_) {}, onError: (_) {}).cancel();
        if (location == null || location.isEmpty) {
          throw const PdfAcquisitionException(
            'The document source sent a redirect with no destination.',
          );
        }
        final next = current.resolve(location);
        final unsafe = _policy.unsafeHttpsReason(next);
        if (unsafe != null) {
          throw PdfAcquisitionException(
            'This document redirected somewhere the app cannot open safely. $unsafe',
          );
        }
        if (!_policy.allowsAutomaticRedirect(
          originalUri: start,
          currentUri: current,
          nextUri: next,
        )) {
          throw PdfAcquisitionException(
            'This document redirected to ${next.host}, which is not an approved '
            'source for the in-app reader.',
          );
        }
        current = next;
        continue;
      }

      _rejectBadStatus(status);
      _rejectContentType(response.headers['content-type']);
      _rejectOversizedDeclaration(response.headers['content-length']);

      // The policy is re-checked on the final hop too: a chain that stayed
      // structurally safe could still land on an unapproved origin.
      if (!_policy.isTrustedOrigin(current)) {
        throw PdfAcquisitionException(
          'This document resolved to ${current.host}, which is not an approved '
          'source for the in-app reader.',
        );
      }

      return _VerifiedTarget(
        uri: current,
        contentLength: int.tryParse(response.headers['content-length'] ?? ''),
        stream: response.stream,
      );
    }
    throw const PdfAcquisitionException(
      'This document redirected too many times to open safely.',
    );
  }

  Future<void> _rejectNonPublicResolution(Uri uri) async {
    final addresses = await _hostResolver(uri.host).timeout(connectTimeout);
    if (addresses.isEmpty || addresses.any(_isNonPublicAddress)) {
      throw const PdfAcquisitionException(
        'This document source did not resolve to a public network address.',
      );
    }
  }

  bool _isNonPublicAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return _isNonPublicIpv4(bytes);
    }
    if (bytes.length != 16 ||
        bytes.every((byte) => byte == 0) ||
        (bytes.take(15).every((byte) => byte == 0) && bytes.last == 1) ||
        (bytes[0] & 0xFE) == 0xFC ||
        (bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80) ||
        bytes[0] == 0xFF) {
      return true;
    }
    final isIpv4Mapped = bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 0xFF &&
        bytes[11] == 0xFF;
    if (isIpv4Mapped) return _isNonPublicIpv4(bytes.sublist(12));

    // IPv4-compatible IPv6 addresses are deprecated and can encode a local
    // destination in their final four bytes.
    if (bytes.take(12).every((byte) => byte == 0)) return true;
    return false;
  }

  bool _isNonPublicIpv4(List<int> bytes) {
    if (bytes.length != 4) return true;
    final first = bytes[0];
    final second = bytes[1];
    final third = bytes[2];
    return first == 0 ||
        first == 10 ||
        first == 127 ||
        (first == 100 && second >= 64 && second <= 127) ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 0 && third == 0) ||
        (first == 192 && second == 0 && third == 2) ||
        (first == 192 && second == 88 && third == 99) ||
        (first == 192 && second == 168) ||
        (first == 198 && (second == 18 || second == 19)) ||
        (first == 198 && second == 51 && third == 100) ||
        (first == 203 && second == 0 && third == 113) ||
        first >= 224;
  }

  void _rejectBadStatus(int status) {
    if (status == 200) return;
    if (status == 404 || status == 410) {
      throw const PdfAcquisitionException(
        'This chapter is no longer available at its official address.',
      );
    }
    if (status == 403) {
      throw const PdfAcquisitionException(
        'The document source refused this request. You can open the original '
        'link in a browser instead.',
      );
    }
    throw PdfAcquisitionException(
      'The document source returned an error (HTTP $status).',
    );
  }

  void _rejectOversizedDeclaration(String? contentLength) {
    final declared = int.tryParse(contentLength ?? '');
    if (declared != null && declared > byteCeiling) {
      throw const PdfAcquisitionException(
        'This document is larger than the app can safely open.',
      );
    }
  }

  void _rejectContentType(String? contentType) {
    final mediaType = contentType?.split(';').first.trim().toLowerCase();
    if (mediaType != 'application/pdf') {
      throw const PdfAcquisitionException(
        'The document source did not identify this response as a PDF.',
      );
    }
  }

  /// Streams to disk under a byte ceiling that holds even when the server omits
  /// `Content-Length` or understates it, and fails closed on a non-PDF body.
  Future<int> _writeBounded(
    File file,
    Stream<List<int>> stream,
    CancellationToken? cancellation,
    void Function(PdfProgress)? onProgress, {
    int? declaredLength,
  }) async {
    final sink = file.openWrite();
    var received = 0;
    final magicBuffer = <int>[];
    final trailerBuffer = <int>[];

    try {
      await for (final chunk in stream.timeout(
        transferTimeout,
        onTimeout: (sink) => sink.addError(
          const PdfAcquisitionException(
            'The download stalled before it finished. Please retry.',
          ),
        ),
      )) {
        if (cancellation?.isCancelled ?? false) {
          throw const PdfAcquisitionException('The download was cancelled.');
        }

        received += chunk.length;
        if (received > byteCeiling) {
          throw const PdfAcquisitionException(
            'This document is larger than the app can safely open.',
          );
        }

        // Accumulate only until the header verdict is decided, so an HTML error
        // page is rejected as early as possible.
        if (magicBuffer.length < _pdfMagic.length) {
          magicBuffer.addAll(chunk.take(_pdfMagic.length - magicBuffer.length));
          if (magicBuffer.length == _pdfMagic.length && !_startsWithMagic(magicBuffer)) {
            throw const PdfAcquisitionException(
              'This link did not return a PDF document.',
            );
          }
        }

        if (chunk.length >= 1024) {
          trailerBuffer
            ..clear()
            ..addAll(chunk.skip(chunk.length - 1024));
        } else {
          trailerBuffer.addAll(chunk);
          if (trailerBuffer.length > 1024) {
            trailerBuffer.removeRange(0, trailerBuffer.length - 1024);
          }
        }

        sink.add(chunk);
        onProgress?.call(PdfProgress(
          receivedBytes: received,
          totalBytes: declaredLength,
        ));
      }

      if (magicBuffer.length < _pdfMagic.length) {
        throw const PdfAcquisitionException(
          'This link did not return a PDF document.',
        );
      }
      if (received == 0) {
        throw const PdfAcquisitionException(
          'The document source returned an empty file.',
        );
      }
      if (received < 32 ||
          !_endsWithSequenceAndWhitespace(trailerBuffer, _pdfEof)) {
        throw const PdfAcquisitionException(
          'This PDF appears incomplete or damaged and cannot be opened safely.',
        );
      }

      await sink.flush();
      await sink.close();
      return received;
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {
        // Already closed or never opened cleanly; the partial file is removed by
        // the caller's catch block either way.
      }
      rethrow;
    }
  }

  bool _startsWithMagic(List<int> bytes) {
    for (var i = 0; i < _pdfMagic.length; i++) {
      if (bytes[i] != _pdfMagic[i]) return false;
    }
    return true;
  }

  bool _endsWithSequenceAndWhitespace(List<int> bytes, List<int> sequence) {
    for (var start = 0; start <= bytes.length - sequence.length; start++) {
      var matches = true;
      for (var offset = 0; offset < sequence.length; offset++) {
        if (bytes[start + offset] != sequence[offset]) {
          matches = false;
          break;
        }
      }
      if (matches &&
          bytes
              .skip(start + sequence.length)
              .every((byte) => byte == 0 ||
                  byte == 9 ||
                  byte == 10 ||
                  byte == 12 ||
                  byte == 13 ||
                  byte == 32)) {
        return true;
      }
    }
    return false;
  }

  bool _isConnectivityFailure(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is HandshakeException ||
      error is TlsException;

  /// Removes abandoned `rfa_resource_pdf_*` files left by a crash or force-kill.
  ///
  /// Scoped strictly to this prefix. An imported workbook is stored under a
  /// different name and is never a candidate for deletion.
  Future<void> _sweepAbandonedTemporaries() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) return;
    final now = DateTime.now();
    await for (final entity in directory.list()) {
      if (entity is! File ||
          !entity.path
              .split(Platform.pathSeparator)
              .last
              .startsWith(temporaryFilePrefix) ||
          _activeTemporaryPaths.contains(entity.path)) {
        continue;
      }
      final modified = await entity.lastModified();
      if (now.difference(modified) >= abandonedFileRetention) {
        await _deleteQuietly(entity);
      }
    }
  }

  Future<void> _deleteQuietly(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Ignored by design.
    }
  }
}

class _VerifiedTarget {
  final Uri uri;
  final int? contentLength;
  final Stream<List<int>> stream;

  const _VerifiedTarget({
    required this.uri,
    required this.contentLength,
    required this.stream,
  });
}