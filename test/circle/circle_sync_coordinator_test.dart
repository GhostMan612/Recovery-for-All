// test/circle/circle_sync_coordinator_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_for_all/database/recovery_database.dart';
import 'package:recovery_for_all/features/circle/data/circle_sync_coordinator.dart';
import 'package:recovery_for_all/features/circle/domain/circle_event.dart';
import 'package:recovery_for_all/services/community_feed_service.dart';

void main() {
  group('CircleSyncCoordinator Tests', () {
    late CircleSyncCoordinator coordinator;

    setUp(() {
      coordinator = CircleSyncCoordinator();
      coordinator.clearForTesting();
      // Ensure fail-closed default
      CommunityFeedService.allowRemoteWritesForTesting = false;
    });

    test('fail-closed: enqueued post transitions to localDraft when remote sync is inactive', () async {
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
    });

    test('idempotency: duplicate enqueues with same outboxId return existing item without re-adding', () async {
      final first = await coordinator.enqueueEvent(
        outboxId: 'outbox-dup-1',
        eventType: CircleEventType.postCreate,
        payload: {'body': 'Hello'},
      );

      for (int i = 0; i < 50; i++) {
        final repeated = await coordinator.enqueueEvent(
          outboxId: 'outbox-dup-1',
          eventType: CircleEventType.postCreate,
          payload: {'body': 'Hello'},
        );
        expect(repeated.outboxId, first.outboxId);
      }

      expect(coordinator.items.length, 1);
    });

    test('deletion state machine: requestPostDeletion marks as deleting, requires server ack for deleted', () async {
      final result = await coordinator.requestPostDeletion(
        outboxId: 'del-001',
        postId: 'post-123',
        ownerUid: 'uid-456',
      );

      expect(result.status, CircleOutboxStatus.deleting);
      expect(result.eventType, CircleEventType.postDelete);
      expect(result.payload['postId'], 'post-123');
      expect(result.payload['ownerUid'], 'uid-456');

      // Server acknowledgment promotes to deleted tombstone
      final confirmed = await coordinator.confirmServerAck('del-001');
      expect(confirmed?.status, CircleOutboxStatus.deleted);
    });

    test('durability: survives app restarts and reloads from Drift database', () async {
      final db = RecoveryDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      final initialCoordinator = CircleSyncCoordinator(database: db);
      final enqueued = await initialCoordinator.enqueueEvent(
        outboxId: 'durable-001',
        eventType: CircleEventType.postCreate,
        payload: {'body': 'Persisted across restarts'},
      );

      expect(enqueued.status, CircleOutboxStatus.localDraft);

      // Verify row in database
      final row = await db.getCircleOutboxEntry('durable-001');
      expect(row, isNotNull);
      expect(row!.status, 'localDraft');
      expect(row.payloadJson, contains('Persisted across restarts'));

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
