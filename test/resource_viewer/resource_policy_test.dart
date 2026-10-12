// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/core/resources/aa_step_resources.dart';
import 'package:recovery_for_all/core/resources/resource_policy.dart';
import 'package:recovery_for_all/core/resources/resource_request.dart';

ResourceRequest _request(String url, {ResourceKind kind = ResourceKind.auto}) =>
    ResourceRequest(uri: Uri.parse(url), title: 'Test', sourceId: 'test', kind: kind);

void main() {
  final policy = ResourcePolicy.defaultPolicy;

  group('registry invariants', () {
    test('has exactly twelve sequential steps with unique urls', () {
      expect(AaStepResources.all, hasLength(12));
      final steps = AaStepResources.all.map((r) => r.step).toList();
      expect(steps, List<int>.generate(12, (i) => i + 1));
      expect(AaStepResources.all.map((r) => r.url).toSet(), hasLength(12));
    });

    test('forStep returns the entry whose step matches, not an off-by-one', () {
      for (var n = 1; n <= 12; n++) {
        expect(AaStepResources.forStep(n).step, n);
        expect(AaStepResources.forStep(n).url, contains('en_step$n.pdf'));
      }
    });

    test('out-of-range steps are rejected rather than clamped', () {
      expect(() => AaStepResources.forStep(0), throwsRangeError);
      expect(() => AaStepResources.forStep(13), throwsRangeError);
    });

    test('aaStep factory routes as pdf and carries a per-step title', () {
      for (var n = 1; n <= 12; n++) {
        final request = ResourceRequest.aaStep(n);
        expect(policy.classify(request).route, ResourceRoute.pdf);
        expect(request.title, contains('Step $n'));
        expect(request.uri.path, endsWith('en_step$n.pdf'));
      }
    });

    test('no entry falls back to a generic landing page', () {
      for (final resource in AaStepResources.all) {
        expect(resource.url, isNot(contains('the-twelve-steps')));
        expect(resource.url.toLowerCase(), endsWith('.pdf'));
      }
    });
  });

  group('scheme policy', () {
    test('tel, sms and mailto route to the OS', () {
      expect(policy.classify(_request('tel:+19555550123')).route,
          ResourceRoute.system);
      expect(policy.classify(_request('sms:+19555550123')).route,
          ResourceRoute.system);
      expect(policy.classify(_request('mailto:help@example.org')).route,
          ResourceRoute.system);
    });

    test('malformed or prefilled system actions are blocked', () {
      for (final url in [
        'tel:call-me',
        'tel:+12',
        'sms:+19555550123?body=private',
        'mailto:help@example.org?subject=private',
        'mailto:not-an-address',
        'tel:+19555550123#fragment',
      ]) {
        expect(policy.classify(_request(url)).route, ResourceRoute.blocked,
            reason: '$url must not be handed to a system app');
      }
    });

    test('dangerous schemes are blocked and never launched', () {
      for (final url in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'content://com.example/x',
        'data:text/html,<h1>x',
        'intent://scan/#Intent;scheme=zxing;end',
        'http://www.aa.org/the-twelve-steps',
        'ftp://www.aa.org/file',
      ]) {
        expect(
          policy.classify(_request(url)).route,
          ResourceRoute.blocked,
          reason: '$url must not open in-app',
        );
      }
    });
  });

  group('host trust', () {
    test('lookalike hosts never inherit trust from a suffix', () {
      // The classic prefix-match bug: aa.org.evil.example starts with "aa.org".
      for (final url in [
        'https://aa.org.evil.example/step1.pdf',
        'https://evil.example/?next=https://www.aa.org',
        'https://notaa.org/step1.pdf',
        'https://aa.org.co/step1.pdf',
      ]) {
        expect(
          policy.classify(_request(url)).route,
          ResourceRoute.requiresExternalApproval,
          reason: '$url must not receive a trusted route',
        );
      }
    });

    test('local, loopback and private-network targets are blocked', () {
      for (final url in [
        'https://127.0.0.1/x',
        'https://192.168.1.1/admin',
        'https://10.0.0.5/',
        'https://localhost/x',
        'https://foo.local/x',
      ]) {
        expect(policy.classify(_request(url)).route, ResourceRoute.blocked,
            reason: '$url must be blocked');
      }
    });

    test('embedded credentials and odd ports are refused', () {
      expect(policy.classify(_request('https://user:pass@www.aa.org/x')).route,
          ResourceRoute.blocked);
      expect(policy.classify(_request('https://www.aa.org:8443/x')).route,
          ResourceRoute.blocked);
    });

    test('an approved origin with no explicit kind routes by suffix', () {
      expect(
        policy.classify(_request('https://www.aa.org/sites/default/files/x.pdf'))
            .route,
        ResourceRoute.pdf,
      );
      expect(
        policy.classify(_request('https://www.aa.org/the-twelve-steps')).route,
        ResourceRoute.web,
      );
    });
  });

  group('redirect policy', () {
    test('same-origin and audited aa alias hops are allowed', () {
      const original = 'https://www.aa.org/a';
      expect(
        policy.allowsAutomaticRedirect(
          originalUri: Uri.parse(original),
          currentUri: Uri.parse(original),
          nextUri: Uri.parse('https://www.aa.org/b'),
        ),
        isTrue,
      );
      expect(
        policy.allowsAutomaticRedirect(
          originalUri: Uri.parse('https://aa.org/a'),
          currentUri: Uri.parse('https://aa.org/a'),
          nextUri: Uri.parse('https://www.aa.org/b'),
        ),
        isTrue,
        reason: 'aa.org and www.aa.org are the one audited alias pair',
      );
    });

    test('cross-origin hops are refused', () {
      expect(
        policy.allowsAutomaticRedirect(
          originalUri: Uri.parse('https://www.aa.org/a'),
          currentUri: Uri.parse('https://www.aa.org/a'),
          nextUri: Uri.parse('https://evil.example/b'),
        ),
        isFalse,
      );
    });

    test('a redirect is reclassified against the current origin', () {
      final decision = policy.classify(
        _request('https://www.aa.org/next'),
        currentUri: Uri.parse('https://evil.example/page'),
      );
      expect(decision.route, ResourceRoute.blocked,
          reason: 'an untrusted current page may not authorize navigation');
    });
  });

  group('privacy', () {
    test('requests carry no recovery, profile or sponsor data', () {
      final request = ResourceRequest.aaStep(6);
      final uri = request.uri;
      expect(uri.userInfo, isEmpty);
      expect(uri.query, isEmpty);
      expect(uri.fragment, isEmpty);
      expect(uri.toString(), isNot(contains('steps_completed')));
      expect(uri.toString(), isNot(contains('sponsor')));
    });
  });
}