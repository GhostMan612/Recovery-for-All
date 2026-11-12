// test/ollama_network_privacy_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';
import 'package:recovery_for_all/services/ollama_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrivacyCapabilityService.resetForTesting();
  });

  tearDown(PrivacyCapabilityService.resetForTesting);

  test('No hard-coded LAN server is present in the default build', () {
    expect(OllamaService.defaultBaseUrl, isEmpty);
  });

  test('All Ollama transports fail closed without session permission', () async {
    final service = OllamaService(baseUrl: 'http://127.0.0.1:1');
    await expectLater(
      service.generateResponse('private recovery prompt'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      service.chat([{'role': 'user', 'content': 'private recovery prompt'}]),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      service.chatStream([
        {'role': 'user', 'content': 'private recovery prompt'}
      ]).toList(),
      throwsA(isA<StateError>()),
    );
  });

  test('Persisted grant never authorizes Ollama on a fresh process', () async {
    SharedPreferences.setMockInitialValues({
      'privacy_consent_v1_ollamaBridge': 'granted',
    });
    await PrivacyCapabilityService.loadState();
    expect(
      PrivacyCapabilityService.isGrantedSync(PrivacyCapability.ollamaBridge),
      isFalse,
    );
    await expectLater(
      OllamaService(baseUrl: 'http://127.0.0.1:1')
          .generateResponse('private recovery prompt'),
      throwsA(isA<StateError>()),
    );
  });

  test('Consent without an explicitly configured endpoint still fails closed', () async {
    expect(await PrivacyCapabilityService.setConsent(
      PrivacyCapability.ollamaBridge,
      ConsentState.granted,
    ), isTrue);

    final service = OllamaService(baseUrl: '');
    await expectLater(
      service.generateResponse('private recovery prompt'),
      throwsA(isA<StateError>()),
    );

    expect(await PrivacyCapabilityService.setConsent(
      PrivacyCapability.ollamaBridge,
      ConsentState.denied,
    ), isTrue);
    expect(
      PrivacyCapabilityService.isGrantedSync(PrivacyCapability.ollamaBridge),
      isFalse,
    );
  });
}
