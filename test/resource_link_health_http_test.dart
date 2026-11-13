// test/resource_link_health_http_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recovery_for_all/services/resource_link_health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unsafe or cleartext check URL is refused before any request', () async {
    var sent = 0;
    final client = MockClient((_) async {
      sent++;
      return http.Response('', 200);
    });
    for (final uri in [
      'http://example.org/public.pdf',
      'https://127.0.0.1/private',
      'https://localhost/secrets',
      'https://user:pass@example.org/file',
      'file:///etc/passwd',
    ]) {
      expect(await ResourceLinkHealth.instance.checkUrl(uri, client: client),
          isNull, reason: uri);
    }
    expect(sent, 0);
    client.close();
  });

  test('HEAD redirects are inconclusive and never auto-followed', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('', 302, headers: {
        'location': 'https://example.org/new-location',
      });
    });

    expect(await ResourceLinkHealth.instance.checkUrl(
        'https://example.org/old-location', client: client), isNull);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'HEAD');
    expect(requests.single.followRedirects, isFalse);
    expect(requests.single.maxRedirects, 0);
    client.close();
  });

  test('405 HEAD falls back to Range GET without redirects', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'HEAD') return http.Response('', 405);
      return http.Response('SAMPLE chunk', 206);
    });

    expect(await ResourceLinkHealth.instance.checkUrl(
        'https://example.org/resource', client: client), isTrue);
    expect(requests.map((x) => x.method), ['HEAD', 'GET']);
    expect(requests.last.headers['Range'], 'bytes=0-1023');
    expect(requests.last.followRedirects, isFalse);
    client.close();
  });

  test('GET redirect is not treated as an authorized live resource', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return request.method == 'HEAD'
          ? http.Response('', 405)
          : http.Response('', 307, headers: {
              'location': 'http://localhost/private',
            });
    });
    expect(await ResourceLinkHealth.instance.checkUrl(
        'https://example.org/resource', client: client), isNull);
    expect(requests, hasLength(2));
    expect(requests.last.followRedirects, isFalse);
    client.close();
  });

  test('rate-limited link is considered reachable without a fallback GET',
      () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('', 429);
    });
    expect(await ResourceLinkHealth.instance.checkUrl(
        'https://example.org/resource', client: client), isTrue);
    expect(requests, 1);
    client.close();
  });
}
