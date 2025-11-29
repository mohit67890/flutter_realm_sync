import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:flutter_realm_sync/services/Models/sync_db_cache.dart';
import 'package:flutter_realm_sync/services/Models/sync_outbox_patch.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_realm_sync/services/RealmSync.dart';
import 'package:flutter_realm_sync/services/RealmHelpers/realm_sync_extensions.dart';
import 'ManyRelationship.dart';

final String url = 'http://localhost:3000';
final String userId = 'scooter-test-${DateTime.now().millisecondsSinceEpoch}';

/// Helper to write with sync and trigger manual sync
void writeWithSyncAndTrigger<T extends RealmObject>(
  Realm realm,
  RealmSync? realmSync,
  T object,
  String Function(T) idSelector,
  String userId,
  String collectionName,
  void Function() writeCallback,
) {
  realm.writeWithSync(
    object,
    userId: userId,
    collectionName: collectionName,
    writeCallback: writeCallback,
  );
  realmSync?.syncObject(collectionName, idSelector(object));
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
        Person.schema,
        Scooter.schema,
        ScooterShop.schema,
        SyncDBCache.schema,
        SyncOutboxPatch.schema,
      ],
      schemaVersion: 1,
      shouldDeleteIfMigrationNeeded: true,
    );
    realm = Realm(config);
    print('✅ Realm database initialized with schema version 1');
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

  testWidgets('TEST 1: Initialize Socket and RealmSync', (
    WidgetTester tester,
  ) async {
    final connectedCompleter = Completer<void>();
    final joinedCompleter = Completer<void>();
    bool connectionSuccessful = false;
    bool authSuccessful = false;

    final options =
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setExtraHeaders({'user-agent': 'scooter-test'})
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
          }
        },
      );
    });

    socket?.onConnectError((error) {
      print('❌ Connection error: $error');
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

    print('🔧 Initializing RealmSync for Scooter and ScooterShop...');

    final scooterResults = realm.all<Scooter>();
    final scooterShopResults = realm.all<ScooterShop>();

    realmSync = RealmSync(
      realm: realm,
      socket: socket!,
      userId: userId,
      configs: [
        SyncCollectionConfig<Scooter>(
          results: scooterResults,
          collectionName: 'scooters',
          idSelector: (scooter) => scooter.id.toString(),
          needsSync: (scooter) => scooter.syncUpdateDb,
          // Minimal configuration - auto-detection enabled
        ),
        SyncCollectionConfig<ScooterShop>(
          results: scooterShopResults,
          collectionName: 'scooter_shops',
          idSelector: (shop) => shop.id.toString(),
          needsSync: (shop) => shop.syncUpdateDb,
          // Minimal configuration - auto-detection enabled
        ),
      ],
    );

    realmSync?.start();
    await Future.delayed(const Duration(milliseconds: 500));
    print('✅ TEST 1 PASSED: Socket & RealmSync initialized');
  });

  testWidgets('TEST 2: Full ScooterShop replication with scooters and owners', (
    WidgetTester tester,
  ) async {
    print('\n📝 TEST 2: Full ScooterShop data replication');

    final shopId = ObjectId();
    final scooter1Id = ObjectId();
    final scooter2Id = ObjectId();
    final owner1Id = ObjectId();
    final owner2Id = ObjectId();

    final owner1 = Person(owner1Id, 'Alice', 'Smith', age: 28);
    final owner2 = Person(owner2Id, 'Bob', 'Jones', age: 35);

    final scooter1 = Scooter(
      scooter1Id,
      'Lightning Blue',
      owner: owner1,
      syncUpdatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      syncUpdateDb: true,
    );

    final scooter2 = Scooter(
      scooter2Id,
      'Thunder Red',
      owner: owner2,
      syncUpdatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      syncUpdateDb: true,
    );

    final shop = ScooterShop(
      shopId,
      'Downtown Scooters',
      syncUpdatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      syncUpdateDb: true,
    );

    realm.write(() {
      realm.add(owner1);
      realm.add(owner2);
      realm.add(scooter1);
      realm.add(scooter2);
      realm.add(shop);
      shop.scooters.addAll([scooter1, scooter2]);
    });

    writeWithSyncAndTrigger(
      realm,
      realmSync,
      shop,
      (s) => s.id.toString(),
      userId,
      'scooter_shops',
      () {},
    );

    writeWithSyncAndTrigger(
      realm,
      realmSync,
      scooter1,
      (s) => s.id.toString(),
      userId,
      'scooters',
      () {},
    );

    writeWithSyncAndTrigger(
      realm,
      realmSync,
      scooter2,
      (s) => s.id.toString(),
      userId,
      'scooters',
      () {},
    );

    await Future.delayed(const Duration(milliseconds: 800));

    final savedShop = realm.find<ScooterShop>(shopId);
    expect(savedShop, isNotNull);
    expect(savedShop!.name, 'Downtown Scooters');
    expect(savedShop.scooters.length, 2);
    expect(savedShop.scooters[0].name, 'Lightning Blue');
    expect(savedShop.scooters[0].owner?.firstName, 'Alice');
    print('✅ TEST 2 PASSED: Full ScooterShop replication');
  });

  testWidgets('TEST 3: Single scooter field update', (
    WidgetTester tester,
  ) async {
    print('\n📝 TEST 3: Single scooter field update');

    final scooterId = ObjectId();
    final ownerId = ObjectId();

    final owner = Person(ownerId, 'Charlie', 'Brown', age: 42);

    final scooter = Scooter(
      scooterId,
      'Initial Name',
      owner: owner,
      syncUpdatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      syncUpdateDb: true,
    );

    realm.write(() {
      realm.add(owner);
      realm.add(scooter);
    });

    writeWithSyncAndTrigger(
      realm,
      realmSync,
      scooter,
      (s) => s.id.toString(),
      userId,
      'scooters',
      () {},
    );

    await Future.delayed(const Duration(milliseconds: 500));

    // Update single field
    writeWithSyncAndTrigger(
      realm,
      realmSync,
      scooter,
      (s) => s.id.toString(),
      userId,
      'scooters',
      () {
        scooter.name = 'Updated Name';
        scooter.syncUpdateDb = true;
        scooter.syncUpdatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      },
    );

    await Future.delayed(const Duration(milliseconds: 500));

    expect(scooter.name, 'Updated Name');
    print('✅ TEST 3 PASSED: Single scooter field update');
  });

  testWidgets('TEST 4: Change scooter owner', (WidgetTester tester) async {
    print('\n📝 TEST 4: Change scooter owner');

    final scooterId = ObjectId();
    final owner1Id = ObjectId();
    final owner2Id = ObjectId();

    final owner1 = Person(owner1Id, 'Dave', 'Wilson', age: 30);
    final owner2 = Person(owner2Id, 'Eve', 'Davis', age: 25);

    final scooter = Scooter(
      scooterId,
      'Green Machine',
      owner: owner1,
      syncUpdatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      syncUpdateDb: true,
    );

    realm.write(() {
      realm.add(owner1);
      realm.add(owner2);
      realm.add(scooter);
    });

    writeWithSyncAndTrigger(
      realm,
      realmSync,
      scooter,
      (s) => s.id.toString(),
      userId,
      'scooters',
      () {},
    );

    await Future.delayed(const Duration(milliseconds: 500));

    // Change owner
    writeWithSyncAndTrigger(
      realm,
      realmSync,
      scooter,
      (s) => s.id.toString(),
      userId,
      'scooters',
      () {
        scooter.owner = owner2;
        scooter.syncUpdateDb = true;
        scooter.syncUpdatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      },
    );

    await Future.delayed(const Duration(milliseconds: 500));

    expect(scooter.owner?.firstName, 'Eve');
    expect(scooter.owner?.lastName, 'Davis');
    print('✅ TEST 4 PASSED: Change scooter owner');
  });

  testWidgets('TEST 5: Add scooter to existing shop', (
    WidgetTester tester,
  ) async {
    print('\n📝 TEST 5: Add scooter to existing shop');

    final shopId = ObjectId();
    final scooter1Id = ObjectId();
    final scooter2Id = ObjectId();
    final ownerId = ObjectId();

    final owner = Person(ownerId, 'Frank', 'Miller', age: 45);

    final scooter1 = Scooter(
      scooter1Id,
      'Yellow Flash',
      owner: owner,
      syncUpdatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      syncUpdateDb: true,
    );

    final shop = ScooterShop(
      shopId,
      'Uptown Scooters',
      syncUpdatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      syncUpdateDb: true,
    );

    realm.write(() {
      realm.add(owner);
      realm.add(scooter1);
      realm.add(shop);
      shop.scooters.add(scooter1);
    });

    writeWithSyncAndTrigger(
      realm,
      realmSync,
      shop,
      (s) => s.id.toString(),
      userId,
      'scooter_shops',
      () {},
    );

    await Future.delayed(const Duration(milliseconds: 500));

    // Add another scooter
    final scooter2 = Scooter(
      scooter2Id,
      'Purple Storm',
      owner: owner,
      syncUpdatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      syncUpdateDb: true,
    );

    writeWithSyncAndTrigger(
      realm,
      realmSync,
      shop,
      (s) => s.id.toString(),
      userId,
      'scooter_shops',
      () {
        realm.add(scooter2);
        shop.scooters.add(scooter2);
        shop.syncUpdateDb = true;
        shop.syncUpdatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      },
    );

    await Future.delayed(const Duration(milliseconds: 500));

    expect(shop.scooters.length, 2);
    expect(shop.scooters[1].name, 'Purple Storm');
    print('✅ TEST 5 PASSED: Add scooter to existing shop');
  });

  testWidgets('TEST 6: Multiple field update on shop', (
    WidgetTester tester,
  ) async {
    print('\n📝 TEST 6: Multiple field update on shop');

    final shopId = ObjectId();

    final shop = ScooterShop(
      shopId,
      'Old Shop Name',
      syncUpdatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      syncUpdateDb: true,
    );

    realm.write(() => realm.add(shop));

    writeWithSyncAndTrigger(
      realm,
      realmSync,
      shop,
      (s) => s.id.toString(),
      userId,
      'scooter_shops',
      () {},
    );

    await Future.delayed(const Duration(milliseconds: 500));

    writeWithSyncAndTrigger(
      realm,
      realmSync,
      shop,
      (s) => s.id.toString(),
      userId,
      'scooter_shops',
      () {
        shop.name = 'New Shop Name';
        shop.syncUpdateDb = true;
        shop.syncUpdatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      },
    );

    await Future.delayed(const Duration(milliseconds: 500));

    expect(shop.name, 'New Shop Name');
    print('✅ TEST 6 PASSED: Multiple field update on shop');
  });
}
