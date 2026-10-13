// test/navigator/atlas_bridge_contract_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/features/navigator/data/atlas_bridge.dart';
import 'package:recovery_for_all/features/navigator/data/atlas_dtos.dart';
import 'package:recovery_for_all/features/navigator/data/navigator_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> log;
  late AtlasBridge bridge;
  late NavigatorRepository repository;

  setUp(() {
    log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(AtlasBridge.channelName),
      (MethodCall methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'getCapabilities':
            final apiVersion = methodCall.arguments['apiVersion'];
            if (apiVersion != 1) {
              throw PlatformException(
                code: 'UNSUPPORTED_VERSION',
                message: 'Version $apiVersion unsupported',
              );
            }
            return <String, dynamic>{
              'version': 1,
              'staticTransit': true,
              'localRouting': true,
              'realtime': false,
              'weather': false,
              'offlineSnapshot': true,
              'providerIds': ['metro_transit_mn'],
            };

          case 'loadStaticNetwork':
            return <String, dynamic>{
              'state': 'ready',
              'feedHash': 'sha256:abc12345',
              'fetchedAt': 1791750000000,
              'expiresAt': 1791836400000,
              'stopCount': 1420,
              'source': 'metro_gtfs_cache',
            };

          case 'planJourney':
            final allowRemote = methodCall.arguments['allowRemote'];
            if (allowRemote == true) {
              throw PlatformException(
                code: 'REMOTE_DISABLED',
                message: 'Remote routing is disabled',
              );
            }
            return <String, dynamic>{
              'version': 1,
              'requestId': methodCall.arguments['requestId'],
              'meetingId': methodCall.arguments['meetingId'],
              'providerId': 'metro_transit_mn',
              'dataSource': 'static_gtfs',
              'isSynthetic': false,
              'fetchedAtUtcMs': 1791750000000,
              'freshness': 'fresh',
              'options': [
                {
                  'journeyId': 'j-1',
                  'departUtcMs': 1791751200000,
                  'arriveUtcMs': 1791753000000,
                  'walkMeters': 300,
                  'transferCount': 0,
                  'transferConfidence': 'high',
                  'legs': [
                    {
                      'mode': 'bus',
                      'fromLabel': 'Stop A',
                      'toLabel': 'Stop B',
                      'startUtcMs': 1791751200000,
                      'endUtcMs': 1791753000000,
                      'routeLabel': 'Route 5',
                      'distanceMeters': 3200,
                    }
                  ],
                }
              ],
            };

          case 'cancelRequest':
            return <String, dynamic>{
              'cancelRequested': true,
              'requestId': methodCall.arguments['requestId'],
            };

          case 'getOfflineStatus':
            return <String, dynamic>{
              'staticNetwork': 'cached',
              'basemap': 'cached_tiles',
              'routing': 'available',
              'dataAgeSeconds': 1200,
              'notes': 'Offline routing operational',
            };

          default:
            return null;
        }
      },
    );

    bridge = AtlasBridge();
    repository = NavigatorRepository(bridge: bridge);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(AtlasBridge.channelName),
      null,
    );
  });

  group('AtlasBridge Contract Tests', () {
    test('getCapabilities returns typed capabilities model', () async {
      final caps = await bridge.getCapabilities();
      expect(caps.version, 1);
      expect(caps.staticTransit, isTrue);
      expect(caps.localRouting, isTrue);
      expect(caps.realtime, isFalse);
      expect(caps.providerIds, contains('metro_transit_mn'));
    });

    test('getCapabilities throws AtlasException on unsupported version', () async {
      expect(
        () => bridge.getCapabilities(apiVersion: 99),
        throwsA(isA<AtlasException>().having(
          (e) => e.code,
          'code',
          AtlasErrorCode.unsupportedVersion,
        )),
      );
    });

    test('loadStaticNetwork returns valid network status', () async {
      final status = await bridge.loadStaticNetwork(
        requestId: 'req-001',
        feedId: 'metro_transit_mn',
      );
      expect(status.state, 'ready');
      expect(status.feedHash, 'sha256:abc12345');
      expect(status.stopCount, 1420);
    });

    test('planJourney validates coordinates strictly before invocation', () async {
      // NaN latitude
      expect(
        () => bridge.planJourney(
          requestId: 'req-123',
          meetingId: 'meet-1',
          originLat: double.nan,
          originLon: -93.2650,
          destinationLat: 44.9778,
          destinationLon: -93.2650,
          departAtUtcMs: 1791751200000,
        ),
        throwsA(isA<AtlasException>().having(
          (e) => e.code,
          'code',
          AtlasErrorCode.badInput,
        )),
      );

      // Out of bounds latitude
      expect(
        () => bridge.planJourney(
          requestId: 'req-123',
          meetingId: 'meet-1',
          originLat: 95.0,
          originLon: -93.2650,
          destinationLat: 44.9778,
          destinationLon: -93.2650,
          departAtUtcMs: 1791751200000,
        ),
        throwsA(isA<AtlasException>().having(
          (e) => e.code,
          'code',
          AtlasErrorCode.badInput,
        )),
      );

      // Empty requestId
      expect(
        () => bridge.planJourney(
          requestId: '   ',
          meetingId: 'meet-1',
          originLat: 44.9778,
          originLon: -93.2650,
          destinationLat: 44.9778,
          destinationLon: -93.2650,
          departAtUtcMs: 1791751200000,
        ),
        throwsA(isA<AtlasException>().having(
          (e) => e.code,
          'code',
          AtlasErrorCode.badInput,
        )),
      );
    });

    test('planJourney successfully parses preview with legs and options', () async {
      final preview = await bridge.planJourney(
        requestId: 'req-valid',
        meetingId: 'meet-456',
        originLat: 44.9778,
        originLon: -93.2650,
        destinationLat: 44.9800,
        destinationLon: -93.2700,
        departAtUtcMs: 1791751200000,
      );

      expect(preview.version, 1);
      expect(preview.requestId, 'req-valid');
      expect(preview.meetingId, 'meet-456');
      expect(preview.options.length, 1);
      final opt = preview.options.first;
      expect(opt.journeyId, 'j-1');
      expect(opt.legs.length, 1);
      expect(opt.legs.first.mode, 'bus');
      expect(opt.legs.first.routeLabel, 'Route 5');
    });

    test('cancelRequest returns success boolean', () async {
      final canceled = await bridge.cancelRequest(requestId: 'req-to-cancel');
      expect(canceled, isTrue);
    });

    test('getOfflineStatus returns offline data details', () async {
      final offline = await bridge.getOfflineStatus(feedId: 'metro_transit_mn');
      expect(offline.staticNetwork, 'cached');
      expect(offline.routing, 'available');
      expect(offline.dataAgeSeconds, 1200);
    });

    test('NavigatorRepository provides safe fallback on unhandled channel error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(AtlasBridge.channelName),
        (MethodCall call) async {
          throw PlatformException(code: 'UNAVAILABLE');
        },
      );

      final caps = await repository.checkCapabilities();
      expect(caps.staticTransit, isFalse);
      expect(caps.localRouting, isFalse);

      final offline = await repository.getOfflineStatus();
      expect(offline.routing, 'unavailable');
    });
  });
}
