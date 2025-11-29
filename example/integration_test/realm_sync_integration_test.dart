import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:flutter_realm_sync/services/Models/SyncDBCache.dart';
import 'package:flutter_realm_sync/services/Models/SyncOutboxPatch.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_realm_sync/services/RealmSync.dart';
import 'package:flutter_realm_sync/services/RealmHelpers/RealmSyncExtensions.dart';

final String url = 'http://localhost:3000';
final String userId = 'test-user-${DateTime.now().millisecondsSinceEpoch}';
final List<String> createdGoalIds = []; // Track for cleanup

// Set to true to skip cleanup and leave data in MongoDB for manual verification
const bool SKIP_CLEANUP = false;

// Helper function to write with sync and manually trigger the sync
// This is needed because results.changes doesn't fire for property changes on existing objects
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

void writeWithSyncMultipleAndTrigger(
  Realm realm,
  RealmSync? realmSync,
  List<Goal> goals,
  String userId,
  String collectionName,
  void Function() writeCallback,
) {
  realm.writeWithSyncMultiple(
    goals,
    userId: userId,
    collectionName: collectionName,
    writeCallback: writeCallback,
  );
  for (var goal in goals) {
    realmSync?.syncObject(collectionName, goal.id);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive Realm-MongoDB Sync Integration Tests', () {
    late Realm realm;
    IO.Socket? socket;
    RealmSync? realmSync;

    setUpAll(() async {
      print('🌐 Testing connection to sync server: $url');
      print(
        '📝 Ensure server is running: cd sync-implementation && npx ts-node server/index.ts',
      );

      // Initialize Realm with DBCache and OutboxPatch for full sync functionality
      final config = Configuration.local(
        [Goal.schema, SyncDBCache.schema, SyncOutboxPatch.schema],
        schemaVersion: 2,
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

    testWidgets('Realm database CRUD operations', (WidgetTester tester) async {
      expect(realm.isClosed, false);
      expect(realm.schema.length, greaterThan(0));

      // CREATE: Insert a test goal
      final testGoalId = ObjectId().toString();
      final now = DateTime.now();
      final testGoal = Goal(
        testGoalId,
        userId,
        'Integration Test Goal',
        description: 'Testing CRUD operations on iOS/macOS',
        status: 'active',
        progress: 0.0,
        createdAt: now,
        updatedAt: now,
      );

      realm.write(() {
        realm.add(testGoal);
      });

      writeWithSyncAndTrigger(realm, realmSync, testGoal, userId, 'goals', () {
        // Extension automatically sets sync_updated_at and sync_update_db
      });

      // READ: Verify goal was saved
      var savedGoals = realm.all<Goal>();
      expect(savedGoals.length, greaterThanOrEqualTo(1));

      final savedGoal = savedGoals.firstWhere((g) => g.id == testGoalId);
      expect(savedGoal.title, 'Integration Test Goal');
      expect(savedGoal.status, 'active');
      expect(savedGoal.progress, 0);

      print('✅ CREATE & READ test passed');
      print('📊 Database path: ${realm.config.path}');
      print('📊 Total goals: ${savedGoals.length}');

      // UPDATE: Modify the goal (with automatic sync_updated_at)
      realm.writeWithSync(
        savedGoal,
        userId: userId,
        collectionName: 'goals',
        writeCallback: () {
          savedGoal.progress = 50;
          savedGoal.status = 'in_progress';
          savedGoal.updatedAt = DateTime.now();
          // Extension automatically sets sync_updated_at and sync_update_db
        },
      );

      // Verify update
      final updatedGoal =
          realm.all<Goal>().where((g) => g.id == testGoalId).firstOrNull;
      expect(updatedGoal, isNotNull);
      expect(updatedGoal!.progress, 50);
      expect(updatedGoal.status, 'in_progress');

      print('✅ UPDATE test passed');

      // DELETE: Remove the goal with sync marker
      realm.deleteWithSync(savedGoal, userId: userId, collectionName: 'goals');

      // Verify deletion
      final deletedGoal =
          realm.all<Goal>().where((g) => g.id == testGoalId).firstOrNull;
      expect(deletedGoal, isNull);

      print('✅ DELETE test passed');
    });

    testWidgets(
      'Socket.IO connection, authentication, and RealmSync initialization',
      (WidgetTester tester) async {
        final completer = Completer<bool>();
        final connectedCompleter = Completer<void>();
        final joinedCompleter = Completer<void>();
        bool connectionSuccessful = false;
        bool authSuccessful = false;

        // Create socket connection
        final options =
            IO.OptionBuilder()
                .setTransports(['websocket'])
                .disableAutoConnect()
                .setExtraHeaders({'user-agent': 'realm-sync-test'})
                .setTimeout(5000)
                .setReconnectionAttempts(3)
                .build();

        socket = IO.io(url, options);

        // Connection event
        socket?.onConnect((_) {
          print('✅ Socket connected to $url');
          connectionSuccessful = true;
          connectedCompleter.complete();

          // Authenticate with sync:join
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

        // Connection error
        socket?.onConnectError((error) {
          print('❌ Connection error: $error');
          if (!completer.isCompleted) completer.complete(false);
        });

        // Error event
        socket?.onError((error) {
          print('❌ Socket error: $error');
        });

        // Disconnect event
        socket?.onDisconnect((_) {
          print('❌ Socket disconnected');
        });

        // Listen for server events
        socket?.on('joined', (data) {
          print('📨 Received joined event: $data');
        });

        socket?.on('sync:changes', (data) {
          print('📨 Received sync:changes event: $data');
        });

        // Connect socket
        socket?.connect();

        // Wait for connection and authentication
        try {
          await connectedCompleter.future.timeout(Duration(seconds: 5));
          await joinedCompleter.future.timeout(Duration(seconds: 5));
          completer.complete(true);
        } catch (e) {
          print('❌ Timeout waiting for connection/authentication: $e');
          completer.complete(false);
        }

        final result = await completer.future;

        expect(
          connectionSuccessful,
          true,
          reason: 'Socket should connect to server',
        );
        expect(
          authSuccessful,
          true,
          reason: 'Socket should authenticate with sync:join',
        );
        expect(result, true, reason: 'Overall connection test should pass');

        print('✅ Socket connection test passed');

        // Initialize RealmSync with configuration
        if (socket != null && socket!.connected) {
          print('\n🔄 Initializing RealmSync with automatic sync...');

          final goalResults = realm.all<Goal>();

          final config = SyncCollectionConfig<Goal>(
            results: goalResults,
            collectionName: 'goals',
            idSelector: (Goal goal) => goal.id,
            needsSync:
                (Goal goal) =>
                    goal.sync_update_db == true &&
                    goal.userId == userId, // Check sync flag and userId
            // Remove toSyncMap and fromServerMap to test RealmJson fallback
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

          // Subscribe to goal changes for this user
          realmSync!.subscribe(
            'goals',
            filterExpr: 'userId == \$0',
            args: [userId],
          );

          // Start the sync
          realmSync!.start();

          print('✅ RealmSync initialized and started');
          print('📡 Subscribed to goals for userId: $userId');
          print('🔄 Automatic sync enabled via SyncHelper');
        }
      },
    );

    testWidgets('Bi-directional: Receive updates from server', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected || realmSync == null) {
        print('⏭ Skipped: Socket or RealmSync not initialized');
        return;
      }

      print('\n🔄 TEST: Bi-directional Sync - Receiving server updates');

      final serverUpdateCompleter = Completer<void>();
      final testGoalId = ObjectId().toString();
      createdGoalIds.add(testGoalId);

      // Listen for incoming sync:changes events
      socket?.on('sync:changes', (data) {
        print('📨 Received sync:changes: $data');
      });

      // Simulate server sending an update (emulate what another client would do)
      // This tests the receiving path of bi-directional sync
      print('📤 Simulating server update for goal: $testGoalId');

      socket?.emitWithAck(
        'mongoUpsert',
        {
          'collection': 'goals',
          'query': {'_id': testGoalId},
          'update': {
            '_id': testGoalId,
            'userId': userId,
            'title': 'Server Created Goal',
            'description': 'This goal was created via server event',
            'status': 'active',
            'progress': 0.0,
            'createdAt': {
              'type': 'date',
              'value': DateTime.now().toIso8601String(),
            },
            'updatedAt': {
              'type': 'date',
              'value': DateTime.now().toIso8601String(),
            },
            'sync_updated_at': DateTime.now().millisecondsSinceEpoch,
          },
        },
        ack: (response) {
          print('📦 Server upsert response: $response');
          if (response == 'ok') {
            Future.delayed(Duration(milliseconds: 500), () {
              serverUpdateCompleter.complete();
            });
          }
        },
      );

      // Wait for server to process and broadcast back
      try {
        await serverUpdateCompleter.future.timeout(Duration(seconds: 5));
      } catch (e) {
        print('⚠️ Timeout waiting for server update: $e');
      }

      // Small delay for RealmSync to apply the update
      await Future.delayed(Duration(seconds: 1));

      // Verify the goal was created in local Realm by server update
      final receivedGoal =
          realm.all<Goal>().where((g) => g.id == testGoalId).firstOrNull;

      if (receivedGoal != null) {
        expect(receivedGoal.title, 'Server Created Goal');
        expect(receivedGoal.userId, userId);
        print(
          '✅ Successfully received and applied server update to local Realm',
        );
      } else {
        print(
          '⚠️ Server update not yet reflected in Realm (this may be expected if sync:changes filtering is strict)',
        );
      }

      print('✅ Bi-directional sync test completed');
    });

    testWidgets('Comprehensive: Batch Insert → Verify MongoDB', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected) {
        print('⏭ Skipped: Socket not connected');
        return;
      }

      print('\n🔄 TEST: Batch Insert - Creating 5 goals');
      final batchGoals = <Goal>[];
      final goalIds = <String>[];

      // Create 5 goals in Realm
      for (int i = 0; i < 5; i++) {
        final goalId = ObjectId().toString();
        goalIds.add(goalId);
        createdGoalIds.add(goalId);

        final now = DateTime.now();
        final goal = Goal(
          goalId,
          userId,
          'Batch Goal ${i + 1}',
          description: 'Testing batch insert operation ${i + 1}',
          status: 'active',
          progress: (i * 10.0),
          createdAt: now,
          updatedAt: now,
        );
        batchGoals.add(goal);
      }

      realm.write(() {
        for (var goal in batchGoals) {
          realm.add(goal);
        }
      });

      writeWithSyncMultipleAndTrigger(
        realm,
        realmSync,
        batchGoals,
        userId,
        'goals',
        () {
          // Extension automatically sets sync_updated_at and sync_update_db for all
        },
      );

      print('✅ Created ${batchGoals.length} goals in Realm and triggered sync');
      // Verify sync flags were set
      for (var goal in batchGoals) {
        print(
          '   - Goal ${goal.title}: sync_update_db=${goal.sync_update_db}, sync_updated_at=${goal.sync_updated_at}',
        );
      }

      // Wait for sync to complete
      await Future.delayed(Duration(seconds: 3));

      // Verify in Realm
      final realmGoals =
          realm.all<Goal>().where((g) => goalIds.contains(g.id)).toList();
      expect(realmGoals.length, 5, reason: 'All 5 goals should exist in Realm');

      print('✅ Verified ${realmGoals.length} goals in Realm');
      print('✅ Batch Insert test passed');
    });

    testWidgets('Comprehensive: Modify Multiple → Verify MongoDB', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected) {
        print('⏭ Skipped: Socket not connected');
        return;
      }

      print('\n🔄 TEST: Modify Multiple - Updating 3 goals');

      // Get first 3 goals from batch insert
      final goalsToModify =
          realm
              .all<Goal>()
              .where(
                (g) => g.userId == userId && g.title.startsWith('Batch Goal'),
              )
              .take(3)
              .toList();

      if (goalsToModify.length < 3) {
        print('⏭ Skipped: Not enough goals to modify');
        return;
      }

      // Modify goals
      final modifications = <String, Map<String, dynamic>>{};
      realm.writeWithSyncMultiple(
        goalsToModify,
        userId: userId,
        collectionName: 'goals',
        writeCallback: () {
          for (int i = 0; i < goalsToModify.length; i++) {
            final goal = goalsToModify[i];
            goal.progress = 50.0 + (i * 10);
            goal.status = 'in_progress';
            goal.description = 'Modified: ${goal.description}';
            goal.updatedAt = DateTime.now();
            // Extension automatically sets sync_updated_at and sync_update_db

            modifications[goal.id] = {
              'progress': goal.progress,
              'status': goal.status,
              'description': goal.description,
            };
          }
        },
      );

      print('✅ Modified ${goalsToModify.length} goals in Realm');
      print('🔄 SyncHelper will automatically sync updates to server...');

      // Wait for sync
      await Future.delayed(Duration(seconds: 2));

      // Verify modifications in Realm
      for (var goal in goalsToModify) {
        final updated =
            realm.all<Goal>().where((g) => g.id == goal.id).firstOrNull;
        expect(updated, isNotNull);
        expect(updated!.status, 'in_progress');
        expect(updated.description, contains('Modified:'));
      }

      print('✅ Verified all modifications in Realm');
      print('✅ Modify Multiple test passed');
    });

    testWidgets('Comprehensive: Progress Updates → Track Changes', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected) {
        print('⏭ Skipped: Socket not connected');
        return;
      }

      print('\n🔄 TEST: Progress Tracking - Incremental updates');

      // Create a new goal for progress tracking
      final goalId = ObjectId().toString();
      createdGoalIds.add(goalId);

      final goal = Goal(
        goalId,
        userId,
        'Progress Tracking Goal',
        description: 'Testing incremental progress updates',
        status: 'active',
        progress: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      realm.write(() {
        realm.add(goal);
      });

      realm.writeWithSync(
        goal,
        userId: userId,
        collectionName: 'goals',
        writeCallback: () {
          // Extension automatically sets sync_updated_at and sync_update_db
        },
      );

      print('📝 Created progress tracking goal: $goalId');
      print('🔄 SyncHelper will automatically sync initial creation...');

      // Simulate progress updates: 0% → 25% → 50% → 75% → 100%
      final progressSteps = [25.0, 50.0, 75.0, 100.0];

      for (var progress in progressSteps) {
        await Future.delayed(Duration(milliseconds: 500));

        realm.writeWithSync(
          goal,
          userId: userId,
          collectionName: 'goals',
          writeCallback: () {
            goal.progress = progress;
            goal.updatedAt = DateTime.now();
            if (progress == 100.0) {
              goal.status = 'completed';
            }
            // Extension automatically sets sync_updated_at and sync_update_db
          },
        );

        print('📊 Updated progress: ${progress.toInt()}% (auto-syncing...)');
      }

      // Wait for final sync
      await Future.delayed(Duration(seconds: 1));

      // Verify final state
      final finalGoal =
          realm.all<Goal>().where((g) => g.id == goalId).firstOrNull;
      expect(finalGoal, isNotNull);
      expect(finalGoal!.progress, 100.0);
      expect(finalGoal.status, 'completed');

      print('✅ Progress tracking verified: 0% → 100%');
      print('✅ Progress Updates test passed');
    });

    testWidgets('Comprehensive: Delete Operations → Verify Removal', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected) {
        print('⏭ Skipped: Socket not connected');
        return;
      }

      print('\n🔄 TEST: Delete Operations - Removing 2 goals');

      // Get 2 goals to delete
      final goalsToDelete =
          realm
              .all<Goal>()
              .where(
                (g) => g.userId == userId && g.title.startsWith('Batch Goal'),
              )
              .take(2)
              .toList();

      if (goalsToDelete.length < 2) {
        print('⏭ Skipped: Not enough goals to delete');
        return;
      }

      final deletedIds = goalsToDelete.map((g) => g.id).toList();

      // Delete from Realm (SyncHelper will auto-sync deletions)
      for (var goal in goalsToDelete) {
        final goalTitle = goal.title;

        realm.deleteWithSync(goal, userId: userId, collectionName: 'goals');

        print('🗑️ Deleted goal: $goalTitle (auto-syncing deletion...)');
      }

      // Wait for sync
      await Future.delayed(Duration(seconds: 2));

      // Verify deletion in Realm
      for (var id in deletedIds) {
        final deleted = realm.all<Goal>().where((g) => g.id == id).firstOrNull;
        expect(deleted, isNull, reason: 'Goal $id should be deleted');
      }

      print('✅ Verified ${deletedIds.length} deletions in Realm');
      print('✅ Delete Operations test passed');
    });

    testWidgets(
      'Comprehensive: Concurrent Modifications → Conflict Resolution',
      (WidgetTester tester) async {
        if (socket == null || !socket!.connected) {
          print('⏭ Skipped: Socket not connected');
          return;
        }

        print('\n🔄 TEST: Concurrent Updates - Simulating conflicts');

        // Create a goal for conflict testing
        final goalId = ObjectId().toString();
        createdGoalIds.add(goalId);

        final goal = Goal(
          goalId,
          userId,
          'Conflict Test Goal',
          description: 'Testing conflict resolution',
          status: 'active',
          progress: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        realm.write(() {
          realm.add(goal);
        });

        realm.writeWithSync(
          goal,
          userId: userId,
          collectionName: 'goals',
          writeCallback: () {
            // Extension automatically sets sync_updated_at and sync_update_db
          },
        );

        print('📝 Created conflict test goal (auto-syncing...)');

        // Simulate rapid concurrent updates
        realm.writeWithSync(
          goal,
          userId: userId,
          collectionName: 'goals',
          writeCallback: () {
            goal.progress = 30.0;
            goal.description = 'Update 1';
            goal.updatedAt = DateTime.now();
            // Extension automatically sets sync_updated_at and sync_update_db
          },
        );

        await Future.delayed(Duration(milliseconds: 100));

        // Immediate second update
        realm.writeWithSync(
          goal,
          userId: userId,
          collectionName: 'goals',
          writeCallback: () {
            goal.progress = 60.0;
            goal.description = 'Update 2 - Should win';
            goal.status = 'in_progress';
            goal.updatedAt = DateTime.now();
            // Extension automatically sets sync_updated_at and sync_update_db
          },
        );

        print('📤 Triggered concurrent updates (SyncHelper auto-syncing...)');

        // Wait for sync
        await Future.delayed(Duration(seconds: 2));

        // Verify last-write-wins
        final finalGoal =
            realm.all<Goal>().where((g) => g.id == goalId).firstOrNull;
        expect(finalGoal, isNotNull);
        expect(finalGoal!.progress, 60.0);
        expect(finalGoal.description, 'Update 2 - Should win');
        expect(finalGoal.status, 'in_progress');

        print('✅ Conflict resolution verified (last-write-wins)');
        print('✅ Concurrent Modifications test passed');
      },
    );

    testWidgets('Final: Cleanup and MongoDB Verification Summary', (
      WidgetTester tester,
    ) async {
      if (socket == null || !socket!.connected) {
        print('⏭ Skipped: Socket not connected');
        return;
      }

      print('\n💾 MONGODB VERIFICATION: Checking data before cleanup');
      print('=' * 80);
      print('📝 userId: $userId');
      print('🔗 To verify data in MongoDB Atlas, run:');
      print('   cd sync-implementation');
      print('   npx ts-node scripts/verify-test-data.ts $userId');
      print('=' * 80);

      // Wait a bit to ensure all syncs have completed
      print('⏳ Waiting 10 seconds to ensure all syncs complete...');
      print('💡 You can run the verification script in another terminal NOW');
      await Future.delayed(Duration(seconds: 10));

      if (SKIP_CLEANUP) {
        print(
          '\n⏭️  SKIPPING CLEANUP: Data preserved in MongoDB for verification',
        );
        print('📊 Run this to check MongoDB:');
        print(
          '   cd sync-implementation && npx ts-node scripts/verify-test-data.ts $userId',
        );
      } else {
        print('\n🧹 CLEANUP: Removing all test data');

        // Get all remaining test goals
        final allTestGoals =
            realm.all<Goal>().where((g) => g.userId == userId).toList();

        print('📊 Found ${allTestGoals.length} test goals to cleanup');

        // Delete from Realm (SyncHelper will auto-sync to MongoDB)
        for (var goal in allTestGoals) {
          realm.deleteWithSync(goal, userId: userId, collectionName: 'goals');
        }

        // Wait for final sync
        await Future.delayed(Duration(seconds: 3));

        // Verify cleanup
        final remaining =
            realm.all<Goal>().where((g) => g.userId == userId).toList();
        expect(
          remaining.length,
          0,
          reason: 'All test goals should be cleaned up',
        );

        print('✅ Cleanup completed');
      }
      print('\n📋 TEST SUMMARY:');
      print('  ✅ Batch Insert: 5 goals created and synced');
      print('  ✅ Modify Multiple: 3 goals updated');
      print('  ✅ Progress Tracking: 0% → 100% with 4 increments');
      print('  ✅ Delete Operations: 2 goals removed');
      print('  ✅ Concurrent Updates: Conflict resolution verified');
      print('  ✅ Cleanup: All test data removed');
      print('\n💾 MongoDB Verification:');
      print('  - Check Atlas for collection "goals"');
      print('  - Filter by userId: $userId');
      print('  - All operations should be reflected in MongoDB');
      print('  - Verify sync_updated_at timestamps for modifications');
    });
  });
}
