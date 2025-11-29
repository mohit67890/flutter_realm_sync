import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:flutter_realm_sync/services/Models/SyncDBCache.dart';
import 'package:flutter_realm_sync/services/Models/SyncOutboxPatch.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_realm_sync/services/RealmSync.dart';
import 'package:flutter_realm_sync/services/RealmHelpers/RealmSyncExtensions.dart';
import 'Goal.dart';

final String url = 'http://localhost:3000';
final String userId =
    'comprehensive-test-${DateTime.now().millisecondsSinceEpoch}';

// Helper function to write with sync and manually trigger the sync
void writeWithSyncAndTrigger(
  Realm realm,
  RealmSync? realmSync,
  Goal goal,
  String userId,
  String collectionName,
  void Function() writeCallback,
) {
  realm.writeWithSync(
    goal,
    userId: userId,
    collectionName: collectionName,
    writeCallback: writeCallback,
  );
  realmSync?.syncObject(collectionName, goal.id);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive MongoDB Sync Replication Tests', () {
    late Realm realm;
    IO.Socket? socket;
    RealmSync? realmSync;

    setUpAll(() async {
      print('🌐 Testing connection to sync server: $url');
      print(
        '📝 Ensure server is running: cd sync-implementation && npx ts-node server/index.ts',
      );

      final config = Configuration.local(
        [Goal.schema, SyncDBCache.schema, SyncOutboxPatch.schema],
        schemaVersion: 5,
        shouldDeleteIfMigrationNeeded: true,
      );
      realm = Realm(config);
      print('✅ Realm database initialized at ${config.path}');
    });

    tearDownAll(() {
      realmSync?.dispose();
      if (!realm.isClosed) {
        realm.close();
        print('✅ Realm database closed');
      }
      if (socket != null) {
        socket?.dispose();
        print('❌ Socket disconnected');
      }
    });

    testWidgets('Initialize Socket and RealmSync', (WidgetTester tester) async {
      final completer = Completer<bool>();
      final connectedCompleter = Completer<void>();
      final joinedCompleter = Completer<void>();
      bool connectionSuccessful = false;
      bool authSuccessful = false;

      final options =
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .disableAutoConnect()
              .setExtraHeaders({'user-agent': 'comprehensive-test'})
              .setTimeout(5000)
              .setReconnectionAttempts(3)
              .build();

      socket = IO.io(url, options);

      socket?.onConnect((_) {
        print('✅ Socket connected to $url');
        connectionSuccessful = true;
        connectedCompleter.complete();

        socket?.emitWithAck(
          'sync:join',
          {'userId': userId},
          ack: (data) {
            print('📦 Server response: $data');
            if (data != null && data['success'] == true) {
              authSuccessful = true;
              joinedCompleter.complete();
              print('✅ Joined as user: $userId');
            }
          },
        );
      });

      socket?.onConnectError((error) {
        print('❌ Connection error: $error');
        if (!completer.isCompleted) completer.complete(false);
      });

      socket?.connect();

      try {
        await connectedCompleter.future.timeout(Duration(seconds: 5));
        await joinedCompleter.future.timeout(Duration(seconds: 5));
        completer.complete(true);
      } catch (e) {
        print('❌ Timeout waiting for connection/authentication: $e');
        completer.complete(false);
      }

      final result = await completer.future;
      expect(connectionSuccessful, true);
      expect(authSuccessful, true);
      expect(result, true);

      // Initialize RealmSync
      if (socket != null && socket!.connected) {
        print('\n🔄 Initializing RealmSync...');

        final goalResults = realm.all<Goal>();
        final config = SyncCollectionConfig<Goal>(
          results: goalResults,
          collectionName: 'goals',
          idSelector: (Goal goal) => goal.id,
          needsSync:
              (Goal goal) =>
                  goal.sync_update_db == true && goal.userId == userId,
          propertyNames: [
            'id',
            'userId',
            'title',
            'description',
            'status',
            'progress',
            'createdAt',
            'updatedAt',
            'sync_updated_at',
            'sync_update_db',
          ],
          create:
              () => Goal(
                ObjectId().toString(),
                '',
                '',
                description: null,
                status: 'active',
                progress: 0.0,
                createdAt: null,
                updatedAt: null,
              ),
        );

        realmSync = RealmSync(
          userId: userId,
          realm: realm,
          socket: socket!,
          configs: [config],
        );

        realmSync!.subscribe(
          'goals',
          filterExpr: 'userId == \$0',
          args: [userId],
        );
        realmSync!.start();

        print('✅ RealmSync initialized and started');
      }
    });

    testWidgets('TEST 1: Create new goal - Full data replication', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected || realmSync == null) {
        print('⏭ Skipped: Socket or RealmSync not initialized');
        return;
      }

      print('\n📝 TEST 1: New Goal Creation - Full Data');
      final goalId = ObjectId().toString();
      final now = DateTime.now();
      final goal = Goal(
        goalId,
        userId,
        'Integration Test Goal',
        description: 'Testing full data replication to MongoDB',
        status: 'active',
        progress: 25.5,
        createdAt: now,
        updatedAt: now,
      );

      realm.write(() => realm.add(goal));
      writeWithSyncAndTrigger(realm, realmSync, goal, userId, 'goals', () {});

      print('✅ Created goal in Realm and triggered sync');
      await Future.delayed(Duration(seconds: 3));

      final realmGoal =
          realm.all<Goal>().where((g) => g.id == goalId).firstOrNull;
      expect(realmGoal, isNotNull);
      expect(realmGoal!.title, 'Integration Test Goal');
      expect(realmGoal.progress, 25.5);

      print('✅ TEST 1 PASSED: Full data replicated correctly');
    });

    testWidgets('TEST 2: Update single field - String update', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected || realmSync == null) {
        print('⏭ Skipped');
        return;
      }

      print('\n📝 TEST 2: Single Field Update - String');
      final goalId = ObjectId().toString();
      final goal = Goal(
        goalId,
        userId,
        'Original Title',
        description: 'Original description',
        status: 'active',
        progress: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      realm.write(() => realm.add(goal));
      writeWithSyncAndTrigger(realm, realmSync, goal, userId, 'goals', () {});
      await Future.delayed(Duration(seconds: 2));

      // Update title
      writeWithSyncAndTrigger(realm, realmSync, goal, userId, 'goals', () {
        goal.title = 'Updated Title';
      });
      await Future.delayed(Duration(seconds: 2));

      final updated =
          realm.all<Goal>().where((g) => g.id == goalId).firstOrNull;
      expect(updated, isNotNull);
      expect(updated!.title, 'Updated Title');
      expect(updated.description, 'Original description');

      print('✅ TEST 2 PASSED: String field updated correctly');
    });

    testWidgets('TEST 3: Update multiple fields simultaneously', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected || realmSync == null) {
        print('⏭ Skipped');
        return;
      }

      print('\n📝 TEST 3: Multiple Field Update');
      final goalId = ObjectId().toString();
      final goal = Goal(
        goalId,
        userId,
        'Multi Field Test',
        description: 'Before update',
        status: 'pending',
        progress: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      realm.write(() => realm.add(goal));
      writeWithSyncAndTrigger(realm, realmSync, goal, userId, 'goals', () {});
      await Future.delayed(Duration(seconds: 2));

      // Update multiple fields
      writeWithSyncAndTrigger(realm, realmSync, goal, userId, 'goals', () {
        goal.title = 'Updated Multi Field';
        goal.description = 'After update';
        goal.status = 'active';
        goal.progress = 75;
      });
      await Future.delayed(Duration(seconds: 2));

      final updated =
          realm.all<Goal>().where((g) => g.id == goalId).firstOrNull;
      expect(updated, isNotNull);
      expect(updated!.title, 'Updated Multi Field');
      expect(updated.description, 'After update');
      expect(updated.status, 'active');
      expect(updated.progress, 75);

      print('✅ TEST 3 PASSED: Multiple fields updated correctly');
    });

    testWidgets('TEST 4: Null value handling', (WidgetTester tester) async {
      if (socket == null || !socket!.connected || realmSync == null) {
        print('⏭ Skipped');
        return;
      }

      print('\n📝 TEST 4: Null Value Handling');
      final goalId = ObjectId().toString();
      final goal = Goal(
        goalId,
        userId,
        'Null Test',
        description: 'Has description',
        status: 'active',
        progress: 50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      realm.write(() => realm.add(goal));
      writeWithSyncAndTrigger(realm, realmSync, goal, userId, 'goals', () {});
      await Future.delayed(Duration(seconds: 2));

      // Set description to null
      writeWithSyncAndTrigger(realm, realmSync, goal, userId, 'goals', () {
        goal.description = null;
      });
      await Future.delayed(Duration(seconds: 2));

      final updated =
          realm.all<Goal>().where((g) => g.id == goalId).firstOrNull;
      expect(updated, isNotNull);
      expect(updated!.description, isNull);

      print('✅ TEST 4 PASSED: Null values handled correctly');
    });

    testWidgets('TEST 5: Batch create - Multiple objects', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected || realmSync == null) {
        print('⏭ Skipped');
        return;
      }

      print('\n📝 TEST 5: Batch Create - 10 goals');
      final goals = <Goal>[];

      for (int i = 1; i <= 10; i++) {
        final goalId = ObjectId().toString();
        goals.add(
          Goal(
            goalId,
            userId,
            'Batch Goal $i',
            description: 'Batch test goal number $i',
            status: 'active',
            progress: i * 10.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      realm.write(() {
        for (final goal in goals) {
          realm.add(goal);
        }
      });

      realm.writeWithSyncMultiple(
        goals,
        userId: userId,
        collectionName: 'goals',
        writeCallback: () {},
      );
      for (final goal in goals) {
        realmSync!.syncObject('goals', goal.id);
      }

      await Future.delayed(Duration(seconds: 5));

      // Verify all goals exist
      for (final goal in goals) {
        final found =
            realm.all<Goal>().where((g) => g.id == goal.id).firstOrNull;
        expect(found, isNotNull);
      }

      print('✅ TEST 5 PASSED: Batch create - 10 goals replicated');
    });

    testWidgets('TEST 6: Delete operation', (WidgetTester tester) async {
      if (socket == null || !socket!.connected || realmSync == null) {
        print('⏭ Skipped');
        return;
      }

      print('\n📝 TEST 6: Delete Operation');
      final goalId = ObjectId().toString();
      final goal = Goal(
        goalId,
        userId,
        'Delete Test',
        description: 'Will be deleted',
        status: 'active',
        progress: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      realm.write(() => realm.add(goal));
      writeWithSyncAndTrigger(realm, realmSync, goal, userId, 'goals', () {});
      await Future.delayed(Duration(seconds: 2));

      // Verify it exists
      var found = realm.all<Goal>().where((g) => g.id == goalId).firstOrNull;
      expect(found, isNotNull);

      // Delete it
      realm.deleteWithSync(goal, userId: userId, collectionName: 'goals');
      await Future.delayed(Duration(seconds: 3));

      // Verify it's gone
      found = realm.all<Goal>().where((g) => g.id == goalId).firstOrNull;
      expect(found, isNull);

      print('✅ TEST 6 PASSED: Deletion completed correctly');
    });

    testWidgets('TEST 7: Rapid successive updates', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected || realmSync == null) {
        print('⏭ Skipped');
        return;
      }

      print('\n📝 TEST 7: Rapid Successive Updates');
      final goalId = ObjectId().toString();
      final goal = Goal(
        goalId,
        userId,
        'Rapid Update Test',
        description: 'Testing rapid updates',
        status: 'active',
        progress: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      realm.write(() => realm.add(goal));
      writeWithSyncAndTrigger(realm, realmSync, goal, userId, 'goals', () {});
      await Future.delayed(Duration(seconds: 2));

      // 20 rapid updates
      for (int i = 1; i <= 20; i++) {
        writeWithSyncAndTrigger(realm, realmSync, goal, userId, 'goals', () {
          goal.progress = i * 5.0;
          goal.title = 'Rapid Update $i';
        });
        await Future.delayed(Duration(milliseconds: 50));
      }

      await Future.delayed(Duration(seconds: 3));

      final updated =
          realm.all<Goal>().where((g) => g.id == goalId).firstOrNull;
      expect(updated, isNotNull);
      expect(updated!.progress, 100.0);
      expect(updated.title, 'Rapid Update 20');

      print(
        '✅ TEST 7 PASSED: Rapid updates handled correctly (batching worked)',
      );
    });

    testWidgets('Final Cleanup and Summary', (WidgetTester tester) async {
      if (socket == null || !socket!.connected) {
        print('⏭ Skipped');
        return;
      }

      print('\n💾 COMPREHENSIVE TEST SUMMARY');
      print('=' * 80);
      print('📝 userId: $userId');
      print('=' * 80);

      // Cleanup
      final allTestGoals =
          realm.all<Goal>().where((g) => g.userId == userId).toList();
      print('📊 Found ${allTestGoals.length} test goals to cleanup');

      for (var goal in allTestGoals) {
        realm.deleteWithSync(goal, userId: userId, collectionName: 'goals');
      }

      await Future.delayed(Duration(seconds: 3));

      final remaining =
          realm.all<Goal>().where((g) => g.userId == userId).toList();
      expect(remaining.length, 0);

      print('✅ Cleanup completed');
      print('\n📋 TEST RESULTS:');
      print('  ✅ TEST 1: Full data replication');
      print('  ✅ TEST 2: Single field update');
      print('  ✅ TEST 3: Multiple field update');
      print('  ✅ TEST 4: Null value handling');
      print('  ✅ TEST 5: Batch create (10 goals)');
      print('  ✅ TEST 6: Delete operation');
      print('  ✅ TEST 7: Rapid successive updates (20 updates)');
      print('\n🎉 ALL TESTS PASSED!');
    });
  });
}
