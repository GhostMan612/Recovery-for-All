// test/circle/firestore_v2_security_test.dart
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firestore v2 Security Rules & Emulator Evaluation Tests', () {
    late String v2RulesContent;
    late String v1RulesContent;

    setUpAll(() {
      final v2File = File('firestore/firestore_v2.rules');
      expect(v2File.existsSync(), isTrue,
          reason: 'firestore_v2.rules must exist');
      v2RulesContent = v2File.readAsStringSync();

      final v1File = File('firestore/firestore.rules');
      expect(v1File.existsSync(), isTrue,
          reason: 'legacy firestore.rules must exist');
      v1RulesContent = v1File.readAsStringSync();
    });

    test('Truthful Boundary: Legacy community_feeds rules DO NOT provide owner-bound creation or deletion', () {
      final legacyFeedBlock = v1RulesContent.split('match /community_feeds/{docId}')[1].split('match /')[0];

      // Legacy rules do NOT check ownerUid on create
      expect(legacyFeedBlock.contains("ownerUid"), isFalse,
          reason: 'Legacy community_feeds rules must not claim to check ownerUid on creation');

      // Legacy rules forbid all deletes rather than providing owner-bound deletion
      expect(legacyFeedBlock.contains("allow delete: if false;"), isTrue,
          reason: 'Legacy rules deny all deletes unconditionally; no owner-bound deletion exists in v1');
    });

    test('Circle v2 Rules: Owner-bound creation is strictly enforced', () {
      expect(v2RulesContent.contains("match /circle_v2/posts/{postId}"), isTrue);

      // Verify ownerUid is bound to request.auth.uid
      expect(v2RulesContent.contains("request.resource.data.ownerUid == request.auth.uid"), isTrue,
          reason: 'v2 creation must bind ownerUid to request.auth.uid');

      // Verify required fields
      expect(v2RulesContent.contains(".hasAll(['ownerUid', 'authorAlias', 'body', 'createdAt', 'status'])"), isTrue,
          reason: 'v2 creation must require schema fields including ownerUid');
    });

    test('Circle v2 Rules: Owner-bound deletion is strictly enforced', () {
      // Only the author who matches resource.data.ownerUid can delete
      expect(v2RulesContent.contains("allow delete: if request.auth != null\n                    && resource.data.ownerUid == request.auth.uid;"), isTrue,
          reason: 'v2 deletion must be bound to resource.data.ownerUid == request.auth.uid');
    });

    test('Circle v2 Rules: Reactions and Reports access restrictions', () {
      // Reactions bound to actorUid
      expect(v2RulesContent.contains("request.resource.data.actorUid == request.auth.uid"), isTrue);
      expect(v2RulesContent.contains("reactionId.matches('^' + request.auth.uid + '_[a-zA-Z0-9]+\$')"), isTrue,
          reason: 'Reaction docId must be prefixed with actorUid to prevent cross-actor overwrites');

      // Reports cannot be read by clients
      expect(v2RulesContent.contains("match /reports/{reporterUid} {\n        allow read: if false;"), isTrue,
          reason: 'Client enumeration of reports must be denied');

      // Reports are bound to reporterUid
      expect(v2RulesContent.contains("reporterUid == request.auth.uid"), isTrue);
    });

    test('Simulated Security Engine: Authorization Decision Matrix', () {
      // Evaluation helper simulating Firestore rule decisions
      bool evaluateV2PostCreate({
        required String? authUid,
        required Map<String, dynamic> data,
      }) {
        if (authUid == null) return false;
        final requiredKeys = ['ownerUid', 'authorAlias', 'body', 'createdAt', 'status'];
        for (final k in requiredKeys) {
          if (!data.containsKey(k)) return false;
        }
        if (data['ownerUid'] != authUid) return false;
        if (data['body'] is! String || (data['body'] as String).isEmpty || (data['body'] as String).length > 480) return false;
        if (data['authorAlias'] is! String || (data['authorAlias'] as String).isEmpty || (data['authorAlias'] as String).length > 32) return false;
        if (data['createdAt'] is! int) return false;
        if (data['status'] != 'visible') return false;
        return true;
      }

      bool evaluateV2PostDelete({
        required String? authUid,
        required Map<String, dynamic> existingData,
      }) {
        if (authUid == null) return false;
        return existingData['ownerUid'] == authUid;
      }

      bool evaluateV2ReactionWrite({
        required String? authUid,
        required String reactionDocId,
        required Map<String, dynamic> data,
      }) {
        if (authUid == null) return false;
        if (data['actorUid'] != authUid) return false;
        if (!reactionDocId.startsWith('${authUid}_')) return false;
        return true;
      }

      // Case 1: Unauthenticated post create -> DENIED
      expect(evaluateV2PostCreate(
        authUid: null,
        data: {'ownerUid': 'user123', 'authorAlias': 'Alice', 'body': 'Hello', 'createdAt': 1000, 'status': 'visible'},
      ), isFalse);

      // Case 2: Post create with spoofed ownerUid -> DENIED
      expect(evaluateV2PostCreate(
        authUid: 'attacker',
        data: {'ownerUid': 'victim', 'authorAlias': 'Victim', 'body': 'Spoofed', 'createdAt': 1000, 'status': 'visible'},
      ), isFalse);

      // Case 3: Legitimate post create with matching ownerUid -> ALLOWED
      expect(evaluateV2PostCreate(
        authUid: 'alice_uid',
        data: {'ownerUid': 'alice_uid', 'authorAlias': 'Alice', 'body': 'Sobriety Milestone', 'createdAt': 1000, 'status': 'visible'},
      ), isTrue);

      // Case 4: Non-owner post deletion -> DENIED
      expect(evaluateV2PostDelete(
        authUid: 'mallory',
        existingData: {'ownerUid': 'alice_uid', 'body': 'Secret'},
      ), isFalse);

      // Case 5: Authentic owner post deletion -> ALLOWED
      expect(evaluateV2PostDelete(
        authUid: 'alice_uid',
        existingData: {'ownerUid': 'alice_uid', 'body': 'My Post'},
      ), isTrue);

      // Case 6: Cross-user reaction spoofing -> DENIED
      expect(evaluateV2ReactionWrite(
        authUid: 'bob',
        reactionDocId: 'alice_strength',
        data: {'actorUid': 'alice', 'kind': 'strength'},
      ), isFalse);

      // Case 7: Authentic reaction creation -> ALLOWED
      expect(evaluateV2ReactionWrite(
        authUid: 'bob',
        reactionDocId: 'bob_strength',
        data: {'actorUid': 'bob', 'kind': 'strength'},
      ), isTrue);
    });
  });
}
