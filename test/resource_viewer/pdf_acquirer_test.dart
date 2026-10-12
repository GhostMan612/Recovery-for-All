// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:recovery_for_all/core/resources/pdf_acquirer.dart';
import 'package:recovery_for_all/core/resources/resource_request.dart';

/// A minimal but genuinely valid-looking PDF body: the header the loader checks.
Uint8List _pdfBytes([int extra = 0]) => Uint8List.fromList([
      0x25, 0x50, 0x44, 0x46, 0x2D, // %PDF-
      ...utf8.encode('1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n'),
      ...List<int>.filled(extra, 0x20),
      0x25, 0x25, 0x45, 0x4F, 0x46, // %%EOF
    ]);

ResourceRequest _request([
  String url = 'https://www.aa.org/sites/default/files/2022-01/en_step1.pdf',
]) =>
    ResourceRequest(
      uri: Uri.parse(url),
      title: 'Step',
      sourceId: 'test',
      kind: ResourceKind.pdf,
    );

/// A scripted client so a test can choose status, headers and whether the body
/// arrives as a single buffer or a chunk stream. `MockClient` can only return a
/// complete `Response`, which cannot express "no Content-Length, streamed".
class _ScriptedClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;

  _ScriptedClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

void main() {
  late Directory tempDirectory;

  setUp(() {
    // Sync temp I/O. These tests drive a real filesystem, and `flutter test`
    // runs bodies in a fake-async zone where an awaited real I/O completion can
    // stall; the synchronous form is deterministic. See the same reasoning in
    // resource_integration_test.dart.
    tempDirectory = Directory.systemTemp.createTempSync('rfa_pdf_test_');
  });

  tearDown(() {
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  PdfAcquirer acquirerUsing(
    _ScriptedClient client, {
    int? ceiling,
    HostResolver? hostResolver,
  }) =>
      PdfAcquirer(
        client: client,
        byteCeiling: ceiling,
        directoryProvider: () async => tempDirectory,
        hostResolver: hostResolver ??
            (_) async => [InternetAddress('8.8.8.8')],
      );

  /// Single buffered response, optionally with an explicit content-length.
  _ScriptedClient respond(
    List<int> body, {
    int status = 200,
    String contentType = 'application/pdf',
    bool omitContentLength = false,
  }) =>
      _ScriptedClient((request) async => http.StreamedResponse(
            Stream<List<int>>.value(body),
            status,
            headers: {
              'content-type': contentType,
              if (!omitContentLength) 'content-length': '${body.length}',
            },
          ));

  group('pdf magic and content verification', () {
    test('a real PDF is accepted and written to a private temp file', () async {
      final acquirer = acquirerUsing(respond(_pdfBytes()));

      final lease = await acquirer.acquire(_request());
      addTearDown(lease.dispose);

      expect(lease.ownsTemporaryFile, isTrue);
      expect(lease.byteCount, greaterThan(0));
      expect(File(lease.path).existsSync(), isTrue);
      expect(lease.path, contains(PdfAcquirer.temporaryFilePrefix));
      expect(lease.path, endsWith('.pdf'));
      expect(lease.path, isNot(endsWith('.part')));
      expect(
        lease.path,
        startsWith(tempDirectory.path),
        reason: 'must stay inside app-private temp storage',
      );

      final head = File(lease.path).readAsBytesSync().sublist(0, 5);
      expect(head, [0x25, 0x50, 0x44, 0x46, 0x2D]);
    });

    test('an HTML page served with 200 and a .pdf URL is rejected', () async {
      // The failure this whole feature exists to avoid: a consent or error page
      // that looks like a PDF by URL and by status alone.
      final html = utf8.encode('<!DOCTYPE html><html><body>Consent</body></html>');
      final acquirer = acquirerUsing(respond(html, contentType: 'text/html'));

      await expectLater(
        acquirer.acquire(_request()),
        throwsA(isA<PdfAcquisitionException>()),
      );
      expect(
        tempDirectory.listSync().whereType<File>(),
        isEmpty,
        reason: 'a rejected response must leave no partial file behind',
      );
    });

    test('a PDF-looking body with a non-PDF media type is rejected', () async {
      final acquirer = acquirerUsing(respond(
        _pdfBytes(),
        contentType: 'text/html',
      ));

      await expectLater(
        acquirer.acquire(_request()),
        throwsA(isA<PdfAcquisitionException>()
            .having((error) => error.message, 'message', contains('identify'))),
      );
      expect(tempDirectory.listSync().whereType<File>(), isEmpty);
    });

    test('a PDF without its final EOF marker is rejected', () async {
      final complete = _pdfBytes();
      final incomplete =
          Uint8List.fromList(complete.sublist(0, complete.length - 5));
      final acquirer = acquirerUsing(respond(incomplete));

      await expectLater(
        acquirer.acquire(_request()),
        throwsA(isA<PdfAcquisitionException>()
            .having((error) => error.message, 'message', contains('incomplete'))),
      );
      expect(tempDirectory.listSync().whereType<File>(), isEmpty);
    });

    test('non-whitespace after the EOF marker is rejected', () async {
      final body = <int>[
        ..._pdfBytes(),
        ...utf8.encode('unexpected trailing content'),
      ];
      final acquirer = acquirerUsing(respond(body));

      await expectLater(
        acquirer.acquire(_request()),
        throwsA(isA<PdfAcquisitionException>()
            .having((error) => error.message, 'message', contains('incomplete'))),
      );
      expect(tempDirectory.listSync().whereType<File>(), isEmpty);
    });

    test('a body too short to contain a header is rejected', () async {
      final acquirer = acquirerUsing(respond(Uint8List.fromList([0x25])));
      await expectLater(
          acquirer.acquire(_request()),
          throwsA(isA<PdfAcquisitionException>()));
    });

    test('an empty body is rejected', () async {
      final acquirer = acquirerUsing(respond(const <int>[]));
      await expectLater(
          acquirer.acquire(_request()),
          throwsA(isA<PdfAcquisitionException>()));
    });
  });

  group('http status handling', () {
    test('404 and 410 produce a presentable message, not a stack trace', () async {
      for (final status in [404, 410]) {
        final acquirer = acquirerUsing(respond(const <int>[], status: status));
        await expectLater(
          acquirer.acquire(_request()),
          throwsA(isA<PdfAcquisitionException>().having(
            (e) => e.message,
            'message',
            contains('no longer available'),
          )),
        );
      }
    });

    test('403 tells the user they can use the browser instead', () async {
      final acquirer = acquirerUsing(respond(const <int>[], status: 403));
      await expectLater(
        acquirer.acquire(_request()),
        throwsA(isA<PdfAcquisitionException>()
            .having((e) => e.message, 'message', contains('browser'))),
      );
    });
  });

  group('bounds', () {
    test('an oversized stream with no Content-Length is cut off', () async {
      // Content-Length omitted entirely: the streamed ceiling has to hold on its
      // own, which a length-only check would miss.
      final acquirer = acquirerUsing(
        _ScriptedClient((request) async => http.StreamedResponse(
              Stream<List<int>>.fromIterable(
                List<List<int>>.generate(64, (_) => _pdfBytes(4096)),
              ),
              200,
              headers: {'content-type': 'application/pdf'},
            )),
        ceiling: 16 * 1024,
      );

      await expectLater(
          acquirer.acquire(_request()),
          throwsA(isA<PdfAcquisitionException>()));
      expect(tempDirectory.listSync().whereType<File>(), isEmpty);
    });

    test('an oversized declared Content-Length is refused before any write',
        () async {
      final acquirer =
          acquirerUsing(respond(_pdfBytes()), ceiling: 8);
      await expectLater(
          acquirer.acquire(_request()),
          throwsA(isA<PdfAcquisitionException>()));
      expect(tempDirectory.listSync().whereType<File>(), isEmpty);
    });
  });

  group('cancellation and cleanup', () {
    test('a cancelled download leaves no file on disk', () async {
      final token = CancellationToken();
      final acquirer = acquirerUsing(_ScriptedClient((request) async {
        token.cancel();
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([_pdfBytes(8192), _pdfBytes(8192)]),
          200,
          headers: {'content-type': 'application/pdf'},
        );
      }));

      await expectLater(
        acquirer.acquire(_request(), cancellation: token),
        throwsA(isA<PdfAcquisitionException>()),
      );
      expect(
        tempDirectory.listSync().whereType<File>(),
        isEmpty,
        reason: 'mid-stream cancellation must discard the partial file',
      );
    });

    test('dispose removes the owned file and is idempotent', () async {
      final acquirer = acquirerUsing(respond(_pdfBytes()));
      final lease = await acquirer.acquire(_request());

      expect(File(lease.path).existsSync(), isTrue);
      await lease.dispose();
      expect(File(lease.path).existsSync(), isFalse);
      // A second dispose must not throw or resurrect anything: the reader calls
      // dispose from both a retry path and a route-exit path.
      await lease.dispose();
      expect(File(lease.path).existsSync(), isFalse);
    });

    test('a non-owning lease never deletes a caller-owned workbook', () async {
      // Regression guard for the workbook refactor: cleanup must be
      // ownership-aware, not merely "delete on dispose".
      final workbook =
          File('${tempDirectory.path}${Platform.pathSeparator}workbook.pdf');
      workbook.writeAsBytesSync(_pdfBytes());

      final borrowed = PdfLease(
        path: workbook.path,
        finalUri: Uri.parse('https://example.test/workbook.pdf'),
        byteCount: 10,
        ownsTemporaryFile: false,
      );
      await borrowed.dispose();

      expect(workbook.existsSync(), isTrue,
          reason: 'an imported workbook is caller-owned and must survive');
    });

    test('abandoned temp files from a crash are swept, workbooks are not',
        () async {
      final abandoned = File(
        '${tempDirectory.path}${Platform.pathSeparator}'
        '${PdfAcquirer.temporaryFilePrefix}stale.pdf',
      );
      final workbook =
          File('${tempDirectory.path}${Platform.pathSeparator}guide.pdf');
      abandoned.writeAsBytesSync(_pdfBytes());
      abandoned.setLastModifiedSync(
        DateTime.now().subtract(
          PdfAcquirer.abandonedFileRetention + const Duration(minutes: 1),
        ),
      );
      workbook.writeAsBytesSync(_pdfBytes());

      final acquirer = acquirerUsing(respond(_pdfBytes()));
      final lease = await acquirer.acquire(_request());

      expect(abandoned.existsSync(), isFalse);
      expect(workbook.existsSync(), isTrue,
          reason: 'the sweep must be scoped to the temp prefix only');
      await lease.dispose();
    });

    test('a second acquisition does not sweep a live reader file', () async {
      final acquirer = acquirerUsing(respond(_pdfBytes()));
      final first = await acquirer.acquire(_request());
      final second = await acquirer.acquire(_request());

      expect(File(first.path).existsSync(), isTrue);
      expect(File(second.path).existsSync(), isTrue);
      await first.dispose();
      await second.dispose();
    });
  });

  group('redirects are revalidated per hop', () {
    test('a redirect off the allowlist is refused before any bytes are written',
        () async {
      final acquirer = acquirerUsing(_ScriptedClient((request) async {
        if (request.url.host == 'www.aa.org') {
          return http.StreamedResponse(
            const Stream<List<int>>.empty(),
            302,
            headers: {'location': 'https://evil.example/payload.pdf'},
          );
        }
        return http.StreamedResponse(
          Stream<List<int>>.value(_pdfBytes()),
          200,
          headers: {'content-type': 'application/pdf'},
        );
      }));

      await expectLater(
        acquirer.acquire(_request()),
        throwsA(isA<PdfAcquisitionException>()
            .having((e) => e.message, 'message', contains('evil.example'))),
      );
      expect(tempDirectory.listSync().whereType<File>(), isEmpty);
    });

    test('a redirect loop past the hop limit is refused', () async {
      var hops = 0;
      final acquirer = acquirerUsing(_ScriptedClient((request) async {
        hops++;
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          302,
          headers: {'location': request.url.toString()},
        );
      }));

      await expectLater(
          acquirer.acquire(_request()),
          throwsA(isA<PdfAcquisitionException>()));
      expect(hops, lessThanOrEqualTo(PdfAcquirer.maximumRedirects + 1));
    });

    test('a same-origin redirect is followed and yields the PDF', () async {
      final resolvedHosts = <String>[];
      final followsRedirects = <bool>[];
      final redirectLimits = <int>[];
      var redirectBodyCancelled = false;
      final redirectBody = StreamController<List<int>>(
        onCancel: () => redirectBodyCancelled = true,
      );
      addTearDown(redirectBody.close);
      final acquirer = acquirerUsing(
        _ScriptedClient((request) async {
          followsRedirects.add(request.followRedirects);
          redirectLimits.add(request.maxRedirects);
          if (request.url.path.endsWith('en_step1.pdf')) {
            return http.StreamedResponse(
              redirectBody.stream,
              302,
              headers: {'location': '/sites/default/files/final.pdf'},
            );
          }
          return http.StreamedResponse(
            Stream<List<int>>.value(_pdfBytes()),
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
        hostResolver: (host) async {
          resolvedHosts.add(host);
          return [InternetAddress('8.8.8.8')];
        },
      );

      final lease = await acquirer.acquire(_request());
      addTearDown(lease.dispose);
      expect(lease.finalUri.path, '/sites/default/files/final.pdf',
          reason: 'the lease records where the bytes actually came from');
      expect(resolvedHosts, ['www.aa.org', 'www.aa.org']);
      expect(
        followsRedirects,
        everyElement(isFalse),
        reason: 'the client must not follow an unchecked redirect internally',
      );
      expect(redirectLimits, everyElement(0));
      expect(redirectBodyCancelled, isTrue,
          reason: 'redirect bodies are cancelled rather than drained');
    });

    test('a redirect to http is refused as a scheme downgrade', () async {
      final acquirer = acquirerUsing(_ScriptedClient((request) async {
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          302,
          headers: {'location': 'http://www.aa.org/insecure.pdf'},
        );
      }));

      await expectLater(
        acquirer.acquire(_request()),
        throwsA(isA<PdfAcquisitionException>()),
      );
    });
  });

  group('unapproved sources never reach the fetcher', () {
    test('an untrusted host is refused before any network call', () async {
      var called = false;
      final acquirer = acquirerUsing(_ScriptedClient((request) async {
        called = true;
        return http.StreamedResponse(
          Stream<List<int>>.value(_pdfBytes()),
          200,
          headers: {'content-type': 'application/pdf'},
        );
      }));

      await expectLater(
        acquirer.acquire(_request('https://evil.example/a.pdf')),
        throwsA(isA<PdfAcquisitionException>()),
      );
      expect(called, isFalse,
          reason: 'policy must gate before the request is issued');
    });

    test('private DNS answers are refused before any network request',
        () async {
      var called = false;
      final acquirer = acquirerUsing(
        _ScriptedClient((request) async {
          called = true;
          return http.StreamedResponse(
            Stream<List<int>>.value(_pdfBytes()),
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
        hostResolver: (_) async => [
          InternetAddress('8.8.8.8'),
          InternetAddress('192.168.1.2'),
        ],
      );

      await expectLater(
        acquirer.acquire(_request()),
        throwsA(isA<PdfAcquisitionException>().having(
          (error) => error.message,
          'message',
          contains('public network address'),
        )),
      );
      expect(called, isFalse);
    });

    test('loopback, link-local and unique-local IPv6 answers are refused',
        () async {
      for (final address in [
        InternetAddress('127.0.0.1'),
        InternetAddress('169.254.1.1'),
        InternetAddress('::1'),
        InternetAddress('fe80::1'),
        InternetAddress('fc00::1'),
      ]) {
        final acquirer = acquirerUsing(
          _ScriptedClient((request) async => http.StreamedResponse(
                Stream<List<int>>.value(_pdfBytes()),
                200,
                headers: {'content-type': 'application/pdf'},
              )),
          hostResolver: (_) async => [address],
        );
        await expectLater(
          acquirer.acquire(_request()),
          throwsA(isA<PdfAcquisitionException>()),
          reason: '$address must not be contacted',
        );
      }
    });
  });
}