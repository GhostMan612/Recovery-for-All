// test/sponsor_relay_containment_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recovery_for_all/services/sponsor_link_service.dart';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrivacyCapabilityService.resetForTesting();
    SponsorLinkService.resetTestingOverrides();
  });

  tearDown(() {
    SponsorLinkService.resetTestingOverrides();
    PrivacyCapabilityService.resetForTesting();
  });

  test('untrusted legacy sponsor cloud relay is disabled by default', () {
    expect(SponsorLinkService.cloudRelayAvailable, isFalse);
  });

  test('plaintext upload and signed receipt writes fail closed before Firebase auth', () async {
    var attemptedAuth = false;
    SponsorLinkService.authCheckerForTesting = () async {
      attemptedAuth = true;
      return true;
    };

    final share = await SponsorLinkService.shareBundleViaCloud(
      sponsorCode: 'SAMPLECODE-QX',
      sponseeAlias: 'SAMPLE Sponsee',
      step: 4,
      title: 'SAMPLE Step',
      bundleJson: '{"answers":["PRIVATE TEST ANSWER"]}',
    );
    final sign = await SponsorLinkService.signBundleViaCloud(
      bundleDocId: 'SAMPLE_b1',
      bundleJson: '{"answers":["PRIVATE TEST ANSWER"]}',
    );
    expect(share, isNull);
    expect(sign, isFalse);
    expect(attemptedAuth, isFalse,
        reason: 'Blocked operations must not even attempt Firebase authentication');
  });

  test('orphan diagnostic stays inert with both cloud grants and no Firebase', () async {
    await PrivacyCapabilityService.setConsent(
      PrivacyCapability.cloudSync, ConsentState.granted,
    );
    expect(await SponsorLinkService.orphanedRelayDocIds(), isEmpty);
  });

  test('pending inbox resolves empty with no live cloud connection', () async {
    final result = await SponsorLinkService.watchPendingBundles('SAMPLECODE-QX')
        .first;
    expect(result, isEmpty);
  });
}
