// test/circle/circle_sync_coordinator_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/core/privacy/privacy_capability.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/features/circle/data/circle_sync_coordinator.dart';
import 'package:recovery_for_all/features/circle/domain/circle_event.dart';
import 'package:recovery_for_all/services/community_feed_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CircleSyncCoordinator Durability & Acknowledgment Tests', () {
    late RecoveryDatabase db;
    late CircleSyncCoordinator coordinator;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PrivacyCapabilityService.resetForTesting();
      db = RecoveryDatabase.forTesting(NativeDatabase.memory());
      coordinator = CircleSyncCoordinator(database: db);
      coordinator.clearForTesting();
      // Ensure fail-closed default
      CommunityFeedService.allowRemoteWritesForTesting = false;
    });

    tearDown(() async {
      PrivacyCapabilityService.resetForTesting();
      await db.close();
    });

    test('fail-closed: enqueued post transitions to localDraft when remote sync is inactive and persists to DB', () async {
      final item = await coordinator.enqueueEvent(
        outboxId: 'outbox-001',
        eventType: CircleEventType.postCreate,
        payload: {
          'body': 'Staying grounded today.',
          'authorAlias': 'Wanderer',
        },
      );

      expect(item.status, CircleOutboxStatus.localDraft);
      expect(item.errorMessage, contains('stored safely in local database'));
      expect(coordinator.items.length, 1);

      // Verify row in database
      final row = await db.getCircleOutboxEntry('outbox-001');
      expect(row, isNotNull);
      expect(row!.status, 'localDraft');
    });

    test('idempotency: duplicate enqueues with same outboxId return existing item without duplicating rows', () async {
      final first = await coordinator.enqueueEvent(
        outboxId: 'outbox-dup-1',
        eventType: CircleEventType.postCreate,
        payload: {'body': 'Hello'},
      );

      for (int i = 0; i < 20; i++) {
        final repeated = await coordinator.enqueueEvent(
          outboxId: 'outbox-dup-1',
          eventType: CircleEventType.postCreate,
          payload: {'body': 'Hello'},
        );
        expect(repeated.outboxId, first.outboxId);
      }

      expect(coordinator.items.length, 1);
      final allRows = await db.getAllCircleOutboxEntries();
      expect(allRows.length, 1);
    });

    test('deletion state machine: requestPostDeletion marks as deleting, survives restart, requires verified server ack for deleted', () async {
      final result = await coordinator.requestPostDeletion(
        outboxId: 'del-001',
        postId: 'post-123',
        ownerUid: 'uid-456',
      );

      expect(result.status, CircleOutboxStatus.deleting);
      expect(result.eventType, CircleEventType.postDelete);
      expect(result.payload['postId'], 'post-123');
      expect(result.payload['ownerUid'], 'uid-456');

      // Verify stored as 'deleting' in database
      final dbRow = await db.getCircleOutboxEntry('del-001');
      expect(dbRow, isNotNull);
      expect(dbRow!.status, 'deleting');

      // Simulate app restart while deletion is pending
      final restarted = CircleSyncCoordinator(database: db);
      await restarted.loadPersistedOutbox();
      expect(restarted.items.length, 1);
      expect(restarted.items.first.status, CircleOutboxStatus.deleting);

      // Server acknowledgment promotes to deleted tombstone ONLY with valid receipt
      final receipt = CircleServerAckReceipt(
        outboxId: 'del-001',
        serverToken: 'srv_ack_xyz789',
        serverTimestampUtcMs: DateTime.now().millisecondsSinceEpoch,
        isVerified: true,
      );
      final confirmed = await restarted.confirmServerAck(
        outboxId: 'del-001',
        receipt: receipt,
      );
      expect(confirmed.status, CircleOutboxStatus.deleted);

      // Verify updated in database
      final finalRow = await db.getCircleOutboxEntry('del-001');
      expect(finalRow!.status, 'deleted');
    });

    test('validation: caller-supplied acknowledgment without valid token or mismatched ID is rejected', () async {
      await coordinator.requestPostDeletion(
        outboxId: 'del-002',
        postId: 'post-999',
        ownerUid: 'uid-999',
      );

      // Invalid receipt: empty token
      final emptyTokenReceipt = CircleServerAckReceipt(
        outboxId: 'del-002',
        serverToken: '   ',
        serverTimestampUtcMs: DateTime.now().millisecondsSinceEpoch,
      );
      expect(
        () => coordinator.confirmServerAck(outboxId: 'del-002', receipt: emptyTokenReceipt),
        throwsArgumentError,
      );

      // Invalid receipt: mismatched outbox ID
      final mismatchedReceipt = CircleServerAckReceipt(
        outboxId: 'del-DIFFERENT',
        serverToken: 'token123',
        serverTimestampUtcMs: DateTime.now().millisecondsSinceEpoch,
      );
      expect(
        () => coordinator.confirmServerAck(outboxId: 'del-002', receipt: mismatchedReceipt),
        throwsArgumentError,
      );

      // Status must remain 'deleting'
      expect(coordinator.items.first.status, CircleOutboxStatus.deleting);
    });

    test('no simulated remote delivery: items stay queued/local and never fabricate delivery success', () async {
      CommunityFeedService.allowRemoteWritesForTesting = true;
      await PrivacyCapabilityService.setConsent(
        PrivacyCapability.cloudSync,
        ConsentState.granted,
      );

      final item = await coordinator.enqueueEvent(
        outboxId: 'queued-001',
        eventType: CircleEventType.postCreate,
        payload: {'body': 'Pending network push'},
      );

      // Must remain queued (never falsely 'delivered' without trusted transport)
      expect(item.status, CircleOutboxStatus.queued);
      expect(item.errorMessage, contains('Server transport unavailable'));

      // Confirm server acknowledgment with verified receipt
      final receipt = CircleServerAckReceipt(
        outboxId: 'queued-001',
        serverToken: 'srv_deliv_token_456',
        serverTimestampUtcMs: DateTime.now().millisecondsSinceEpoch,
      );
      final delivered = await coordinator.confirmServerAck(
        outboxId: 'queued-001',
        receipt: receipt,
      );
      expect(delivered.status, CircleOutboxStatus.delivered);
    });

    test('restart durability: survives app restarts and reloads exact states from Drift database', () async {
      final enqueued = await coordinator.enqueueEvent(
        outboxId: 'durable-001',
        eventType: CircleEventType.postCreate,
        payload: {'body': 'Persisted across restarts'},
      );

      expect(enqueued.status, CircleOutboxStatus.localDraft);

      // Simulate app restart with fresh coordinator instance
      final restartedCoordinator = CircleSyncCoordinator(database: db);
      expect(restartedCoordinator.items, isEmpty);

      await restartedCoordinator.loadPersistedOutbox();
      expect(restartedCoordinator.items.length, 1);
      final loadedItem = restartedCoordinator.items.first;
      expect(loadedItem.outboxId, 'durable-001');
      expect(loadedItem.payload['body'], 'Persisted across restarts');
      expect(loadedItem.status, CircleOutboxStatus.localDraft);
    });
  });
}
