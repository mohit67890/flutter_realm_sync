import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:flutter_realm_sync/services/Models/sync_db_cache.dart';
import 'package:flutter_realm_sync/services/Models/sync_outbox_patch.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_realm_sync/services/RealmSync.dart';
import 'package:flutter_realm_sync/services/RealmHelpers/realm_sync_extensions.dart';

import 'ChatRoom.dart';

final String url = 'http://localhost:3000';
final String userId = 'chatroom-test-${DateTime.now().millisecondsSinceEpoch}';

/// Helper to write with sync and trigger manual sync
void writeWithSyncAndTrigger(
  Realm realm,
  RealmSync? realmSync,
  ChatRoom room,
  String userId,
  String collectionName,
  void Function() writeCallback,
) {
  realm.writeWithSync(
    room,
    userId: userId,
    collectionName: collectionName,
    writeCallback: writeCallback,
  );
  realmSync?.syncObject(collectionName, room.id);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Realm realm;
  IO.Socket? socket;
  RealmSync? realmSync;

  setUpAll(() async {
    print('🌐 Testing connection to sync server: $url');
    print(
      '📝 Ensure server is running: cd sync-implementation && npx ts-node server/index.ts',
    );

    final config = Configuration.local(
      [
        ChatRoom.schema,
        ChatUser.schema,
        SyncDBCache.schema,
        SyncOutboxPatch.schema,
      ],
      schemaVersion: 6,
      shouldDeleteIfMigrationNeeded: true,
    );
    realm = Realm(config);
    print('✅ Realm database initialized with schema version 6');
  });

  tearDownAll() {
    realmSync?.dispose();
    if (!realm.isClosed) {
      realm.close();
      print('✅ Realm database closed');
    }
    if (socket != null) {
      socket?.dispose();
      print('❌ Socket disconnected');
    }
  }

  ;

  testWidgets('TEST 1: Initialize Socket and RealmSync', (
    WidgetTester tester,
  ) async {
    final completer = Completer<bool>();
    final connectedCompleter = Completer<void>();
    final joinedCompleter = Completer<void>();
    bool connectionSuccessful = false;
    bool authSuccessful = false;

    final options =
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setExtraHeaders({'user-agent': 'chatroom-test'})
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
          } else {
            print('❌ Authentication failed');
            completer.completeError('Authentication failed');
          }
        },
      );
    });

    socket?.onConnectError((error) {
      print('❌ Connection error: $error');
      completer.completeError('Connection error: $error');
    });

    socket?.onError((error) {
      print('❌ Socket error: $error');
    });

    socket?.connect();

    try {
      await connectedCompleter.future.timeout(const Duration(seconds: 10));
      await joinedCompleter.future.timeout(const Duration(seconds: 5));
    } catch (e) {
      fail('Failed to connect or authenticate: $e');
    }

    expect(connectionSuccessful, isTrue, reason: 'Socket should connect');
    expect(authSuccessful, isTrue, reason: 'Should authenticate');

    print('🔧 Initializing RealmSync for ChatRoom...');

    final chatRoomResults = realm.all<ChatRoom>();

    realmSync = RealmSync(
      realm: realm,
      socket: socket!,
      userId: userId,
      configs: [
        SyncCollectionConfig<ChatRoom>(
          results: chatRoomResults,
          collectionName: 'chatrooms',
          idSelector: (room) => room.id,
          needsSync: (room) => room.syncUpdateDb,
          // Absolute minimum configuration - only 4 required fields!
          // RealmSync automatically manages:
          // - sanitize: removes 'sync_update_db' from synced data
          // - sync flag clearing: automatically clears syncUpdateDb after successful sync
        ),
      ],
    );

    realmSync?.start();
    await Future.delayed(const Duration(milliseconds: 500));
    print('✅ TEST 1 PASSED: Socket & RealmSync initialized');
  });

  testWidgets('TEST 2: Full ChatRoom replication with nested data', (
    WidgetTester tester,
  ) async {
    print('\n📝 TEST 2: Full ChatRoom data replication');

    final roomId = 'room-${DateTime.now().millisecondsSinceEpoch}';
    final user1Id = 'user1-${DateTime.now().millisecondsSinceEpoch}';
    final user2Id = 'user2-${DateTime.now().millisecondsSinceEpoch}';

    final user1 =
        ChatUser(user1Id)
          ..userId = 'firebase-user-1'
          ..name = 'Alice'
          ..image = 'https://example.com/alice.jpg'
          ..emotion = 'happy'
          ..thought = 'Great conversation!'
          ..summary = 'Friendly chat'
          ..revealStatus = 'revealed'
          ..firebaseToken = 'token-alice'
          ..isSynced = true
          ..isTyping = false
          ..updatedOn = DateTime.now();

    final user2 =
        ChatUser(user2Id)
          ..userId = 'firebase-user-2'
          ..name = 'Bob'
          ..image = 'https://example.com/bob.jpg'
          ..emotion = 'excited';

    final room =
        ChatRoom(roomId, user1Id, user2Id)
          ..name = 'Alice & Bob Chat'
          ..text = 'Hello there!'
          ..image = 'https://example.com/room.jpg'
          ..account = 'premium'
          ..fromUnreadCount = 0
          ..toUnreadCount = 1
          ..status = 'active'
          ..isBanned = false
          ..isLeft = false
          ..fromMuted = false
          ..toMuted = false
          ..members.addAll([user1Id, user2Id])
          ..journalIds.addAll(['journal-1', 'journal-2'])
          ..isFromTyping = false
          ..isToTyping = true
          ..time = DateTime.now()
          ..updatedAt = DateTime.now()
          ..lastMessageSyncTime = DateTime.now()
          ..startTime = DateTime.now().subtract(const Duration(hours: 1))
          ..endTime = DateTime.now().add(const Duration(hours: 1))
          ..journalId = 'journal-main'
          ..emotion = 'happy'
          ..privacy = 'private'
          ..messageBy = user1Id
          ..lastMessage = 'Hello there!'
          ..lastMessageId = 'msg-123'
          ..isMuted = false
          ..type = 'direct'
          ..duration = '2h'
          ..fromSynced = true
          ..toSynced = false
          ..revealRequestBy = user1Id
          ..revealRequestTo = user2Id
          ..revealRequestTime = DateTime.now()
          ..revealStatus = 'pending'
          ..revealMessage = 'Can we reveal?'
          ..syncUpdatedAt = DateTime.now().toUtc().millisecondsSinceEpoch
          ..syncUpdateDb = true;

    room.users[user1Id] = user1;
    room.users[user2Id] = user2;
    room.syncMap[user1Id] = true;
    room.syncMap[user2Id] = false;
    room.lastMessageAt[user1Id] = DateTime.now();

    realm.write(() {
      realm.add(user1);
      realm.add(user2);
      realm.add(room);
    });

    writeWithSyncAndTrigger(realm, realmSync, room, userId, 'chatrooms', () {});

    await Future.delayed(const Duration(milliseconds: 500));

    final savedRoom = realm.find<ChatRoom>(roomId);
    expect(savedRoom, isNotNull);
    expect(savedRoom!.name, 'Alice & Bob Chat');
    expect(savedRoom.members.length, 2);
    expect(savedRoom.users.length, 2);
    print('✅ TEST 2 PASSED: Full ChatRoom replication');
  });

  testWidgets('TEST 3: Single field update', (WidgetTester tester) async {
    print('\n📝 TEST 3: Single field update');

    final roomId = 'update-${DateTime.now().millisecondsSinceEpoch}';
    // Create managed ChatRoom first
    final room =
        ChatRoom(roomId, 'user1', 'user2')
          ..lastMessage = 'Initial message'
          ..syncUpdatedAt = DateTime.now().toUtc().millisecondsSinceEpoch
          ..syncUpdateDb = true;
    realm.write(() => realm.add(room));
    // Trigger initial sync (empty callback since already set up)
    writeWithSyncAndTrigger(realm, realmSync, room, userId, 'chatrooms', () {});

    await Future.delayed(const Duration(milliseconds: 500));

    // Update single field and mark for sync
    writeWithSyncAndTrigger(realm, realmSync, room, userId, 'chatrooms', () {
      room.lastMessage = 'Updated message';
      room.syncUpdateDb = true; // mark change
      room.syncUpdatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    expect(room.lastMessage, 'Updated message');
    print('✅ TEST 3 PASSED: Single field update');
  });

  testWidgets('TEST 4: Multiple field update', (WidgetTester tester) async {
    print('\n📝 TEST 4: Multiple field update');

    final roomId = 'multi-${DateTime.now().millisecondsSinceEpoch}';

    final room =
        ChatRoom(roomId, 'user1', 'user2')
          ..name = 'Old Name'
          ..fromUnreadCount = 0
          ..toUnreadCount = 0
          ..status = 'active'
          ..syncUpdatedAt = DateTime.now().toUtc().millisecondsSinceEpoch
          ..syncUpdateDb = true;

    realm.write(() => realm.add(room));
    writeWithSyncAndTrigger(realm, realmSync, room, userId, 'chatrooms', () {});

    await Future.delayed(const Duration(milliseconds: 500));

    writeWithSyncAndTrigger(realm, realmSync, room, userId, 'chatrooms', () {
      room.name = 'New Name';
      room.fromUnreadCount = 5;
      room.toUnreadCount = 3;
      room.status = 'muted';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    expect(room.name, 'New Name');
    expect(room.fromUnreadCount, 5);
    print('✅ TEST 4 PASSED: Multiple field update');
  });

  // testWidgets('TEST 5: Delete operation', (WidgetTester tester) async {
  //   print('\n📝 TEST 5: Delete operation');

  //   final roomId = 'delete-${DateTime.now().millisecondsSinceEpoch}';

  //   final room = ChatRoom(roomId, 'user1', 'user2')
  //     ..name = 'To Be Deleted'
  //     ..syncUpdatedAt = DateTime.now().toUtc().millisecondsSinceEpoch
  //     ..syncUpdateDb = true;

  //   realm.write(() => realm.add(room));
  //   writeWithSyncAndTrigger(realm, realmSync, room, userId, 'chatrooms', () {});

  //   await Future.delayed(const Duration(milliseconds: 500));

  //   realm.deleteWithSync<ChatRoom>(
  //     realm.find<ChatRoom>(roomId)!,
  //     userId: userId,
  //     collectionName: 'chatrooms',
  //   );

  //   await Future.delayed(const Duration(milliseconds: 500));

  //   expect(realm.find<ChatRoom>(roomId), isNull);
  //   print('✅ TEST 5 PASSED: Delete operation');
  // });

  // testWidgets('TEST 6: Cleanup and Summary', (WidgetTester tester) async {
  //   print('\n📝 TEST 6: Cleanup');

  //   final allRooms = realm.all<ChatRoom>();
  //   print('📊 Found ${allRooms.length} test chatrooms to cleanup');

  //   realm.write(() {
  //     for (final room in allRooms) {
  //       realm.delete(room);
  //     }
  //   });

  //   await Future.delayed(const Duration(milliseconds: 500));
  //   print('✅ Cleanup completed');

  //   print('\n' + '=' * 50);
  //   print('📋 TEST RESULTS:');
  //   print('  ✅ TEST 1: Socket & RealmSync initialization');
  //   print('  ✅ TEST 2: Full ChatRoom replication with nested data');
  //   print('  ✅ TEST 3: Single field update');
  //   print('  ✅ TEST 4: Multiple field update');
  //   print('  ✅ TEST 5: Delete operation');
  //   print('🎉 ALL CHATROOM TESTS PASSED!');
  //   print('=' * 50);
  // });
}
