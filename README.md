# Flutter Realm Sync

A powerful Flutter plugin that enables **real-time bidirectional synchronization** between offline Realm databases and MongoDB Atlas using Socket.IO. This package provides an enhanced alternative to the deprecated Atlas Device Sync, offering more control, flexibility, and cost-effectiveness for your mobile applications.

## 🌟 Why Flutter Realm Sync?

### Atlas Device Sync Deprecated ⚠️

MongoDB's Atlas Device Sync has been **deprecated**, leaving developers without an official real-time sync solution. Flutter Realm Sync fills this gap by providing:

✅ **Full control** over your sync infrastructure  
✅ **Cost-effective** - use your own Socket.IO server  
✅ **Offline-first** - works seamlessly with local Realm databases  
✅ **Real-time updates** - instant sync across all connected devices  
✅ **Conflict resolution** - automatic last-write-wins strategy  
✅ **Production-ready** - comprehensive test coverage and battle-tested

### Key Features

- 🔄 **Bidirectional Sync**: Changes flow seamlessly between local Realm and MongoDB Atlas
- 📱 **Multi-Device Support**: Real-time updates across all connected devices
- 🔌 **Socket.IO Integration**: Reliable WebSocket-based communication
- 💾 **Persistent Sync State**: Remembers sync progress across app restarts
- ⚡ **Batch Operations**: Efficiently handles bulk inserts, updates, and deletes
- 🎯 **Conflict Resolution**: Automatic last-write-wins with timestamp-based tracking
- 🧪 **Comprehensive Testing**: Extensive integration tests ensure reliability
- 🔍 **Change Tracking**: Detailed audit logs of all sync operations
- 🌐 **Historic Sync**: Fetch and apply changes since last sync on reconnection

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_realm_sync: ^0.0.1
  realm_flutter_vector_db: ^1.0.11
  socket_io_client: ^3.1.2
```

Then run:

```bash
flutter pub get
```

## 🚀 Quick Start

### 1. Define Your Realm Model

Create a Realm model with required sync fields:

```dart
import 'package:realm_flutter_vector_db/realm_vector_db.dart';
part 'ChatMessage.realm.dart';

@RealmModel()
@MapTo('chat_messages')
class _ChatMessage {
  @PrimaryKey()
  @MapTo('_id')
  late String id;

  late String text;
  late String senderName;
  late String senderId;
  late DateTime timestamp;

  // Required for sync functionality
  @MapTo('sync_updated_at')
  int? syncUpdatedAt;

  @MapTo('sync_update_db')
  bool syncUpdateDb = false;
}
```

Generate the Realm schema:

```bash
dart run realm_flutter_vector_db generate
```

### 2. Initialize Realm

```dart
import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:flutter_realm_sync/services/Models/SyncMetadata.dart';
import 'package:flutter_realm_sync/services/Models/SyncDBCache.dart';
import 'package:flutter_realm_sync/services/Models/SyncOutboxPatch.dart';

// Configure Realm with your models and sync models
final config = Configuration.local([
  ChatMessage.schema,
  SyncMetadata.schema,    // Required for sync state
  SyncDBCache.schema,     // Required for sync caching
  SyncOutboxPatch.schema, // Required for sync operations
], schemaVersion: 1);

final realm = Realm(config);
```

### 3. Connect to Socket.IO Server

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

final socket = IO.io(
  'http://your-server-url:3000',
  IO.OptionBuilder()
    .setTransports(['websocket'])
    .disableAutoConnect()
    .build(),
);

socket.onConnect((_) {
  print('Connected to sync server');

  // Join sync room
  socket.emitWithAck('sync:join', {'userId': 'your-user-id'}, ack: (data) {
    if (data['success'] == true) {
      print('Successfully joined sync room');
    }
  });
});

socket.connect();
```

### 4. Initialize RealmSync

```dart
import 'package:flutter_realm_sync/services/RealmSync.dart';

final realmSync = RealmSync(
  realm: realm,
  socket: socket,
  userId: 'your-user-id',
  configs: [
    SyncCollectionConfig<ChatMessage>(
      collectionName: 'chat_messages',
      results: realm.all<ChatMessage>(),
      idSelector: (obj) => obj.id,
      needsSync: (obj) => obj.syncUpdateDb,
      fromServerMap: (map) {
        return ChatMessage(
          map['_id'] as String,
          map['text'] as String,
          map['senderName'] as String,
          map['senderId'] as String,
          DateTime.parse(map['timestamp']),
          syncUpdatedAt: map['sync_updated_at'] as int?,
        );
      },
    ),
  ],
);

// Start syncing
realmSync.start();

// Optionally fetch historic changes
realmSync.fetchAllHistoricChanges(applyLocally: true);
```

### 5. Create and Sync Data

```dart
import 'package:flutter_realm_sync/services/RealmHelpers/RealmSyncExtensions.dart';

// Create a new message
final message = ChatMessage(
  ObjectId().toString(),
  'Hello, World!',
  'John Doe',
  'user-123',
  DateTime.now(),
);

// Write with automatic sync timestamp management
realm.writeWithSync(message, () {
  message.syncUpdateDb = true; // Mark for sync
  realm.add(message);
});

// Trigger sync
realmSync.syncObject('chat_messages', message.id);
```

## 📚 Advanced Usage

### Automatic Timestamp Management

The package provides convenient extensions to automatically manage `sync_updated_at` timestamps:

```dart
// Single object update
realm.writeWithSync(message, () {
  message.text = "Updated text";
  message.syncUpdateDb = true;
  // sync_updated_at is set automatically!
});

// Multiple objects update
realm.writeWithSyncMultiple([msg1, msg2, msg3], () {
  msg1.text = "Update 1";
  msg2.text = "Update 2";
  msg3.text = "Update 3";
  // All get the same timestamp for consistency
});
```

### Historic Change Sync

Fetch changes that occurred while the app was offline:

```dart
// Fetch all changes since last sync
realmSync.fetchAllHistoricChanges(applyLocally: true);

// Or manually for a specific collection
socket.emitWithAck(
  'sync:get_changes',
  {
    'userId': 'your-user-id',
    'collectionName': 'chat_messages',
    'since': lastSyncTimestamp,
  },
  ack: (response) {
    // Process historic changes
  },
);
```

### Listen to Sync Events

Monitor real-time sync events across all collections:

```dart
final subscription = realmSync.objectChanges.listen((event) {
  print('Synced ${event.collectionName}: ${event.id}');
  // event.object contains the actual RealmObject
});

// Don't forget to cancel when done
subscription.cancel();
```

### Nested Object Support

RealmSync automatically handles nested and embedded objects:

```dart
@RealmModel()
class _ChatRoom {
  @PrimaryKey()
  late String id;

  late String name;

  // Embedded objects are automatically serialized
  late _ChatUser? owner;

  // Lists of embedded objects work too
  late List<_ChatUser> members;
}

@RealmModel(ObjectType.embeddedObject)
class _ChatUser {
  late String id;
  late String name;
  late DateTime joinedAt;
}
```

No additional configuration needed - nested objects are serialized recursively!

### Custom Serialization

For advanced use cases, provide custom serialization:

```dart
SyncCollectionConfig<MyModel>(
  // ... other config ...
  toSyncMap: (obj) {
    return {
      '_id': obj.id,
      'customField': obj.computedValue,
      // Custom transformation logic
    };
  },
  fromServerMap: (map) {
    return MyModel(
      map['_id'],
      customField: map['customField'],
    );
  },
)
```

## 🏗️ Server Setup

Flutter Realm Sync requires a Node.js server with Socket.IO and MongoDB Atlas to handle real-time synchronization.

### Production-Ready Server

We provide a complete, production-ready server implementation:

**🚀 [Realm Sync Server](https://github.com/mohit67890/realm-sync-server)**

This server includes:

- ✅ Socket.IO integration with room-based user isolation
- ✅ MongoDB Atlas connectivity with connection pooling
- ✅ Automatic change broadcasting to connected devices
- ✅ Historic sync support for offline device catch-up
- ✅ Comprehensive error handling and logging
- ✅ TypeScript for type safety
- ✅ Easy deployment to cloud providers

### Quick Server Setup

1. Clone the server repository:

```bash
git clone https://github.com/mohit67890/realm-sync-server.git
cd realm-sync-server
```

2. Install dependencies:

```bash
npm install
```

3. Configure environment variables:

```bash
cp .env.example .env
# Edit .env with your MongoDB Atlas connection string
```

4. Start the server:

```bash
npm run dev  # Development mode
# or
npm start    # Production mode
```

The server will start on `http://localhost:3000` by default.

For detailed setup instructions, deployment guides, and configuration options, visit the [server repository](https://github.com/mohit67890/realm-sync-server).

## 🧪 Testing

The package includes comprehensive integration tests covering:

- ✅ CRUD operations (Create, Read, Update, Delete)
- ✅ Batch operations (bulk inserts, updates)
- ✅ Concurrent modifications and conflict resolution
- ✅ Multi-device synchronization
- ✅ Network interruption handling
- ✅ Historic change synchronization
- ✅ Special characters and edge cases
- ✅ MongoDB replication verification

Run the example app:

```bash
cd example
flutter run -d macos  # or ios, android
```

Run integration tests:

```bash
cd example
flutter test integration_test/realm_sync_integration_test.dart -d macos
```

## 📖 Example App

The package includes a full-featured chat application demonstrating:

- Real-time messaging across multiple devices
- Offline message queuing
- Automatic reconnection and sync
- User presence indicators
- Message persistence with Realm

Check out the [example app](./example/lib/main.dart) for complete implementation details.

## 🔧 Troubleshooting

### Messages Not Syncing

1. **Check Socket Connection**: Ensure `socket.connected` returns `true`
2. **Verify Sync Flags**: Make sure `syncUpdateDb = true` before syncing
3. **Check Server Logs**: Look for errors in your Socket.IO server
4. **Verify MongoDB Connection**: Ensure server can write to MongoDB

### Sync State Not Persisting

Make sure you've included all required sync models in your Realm configuration:

```dart
Configuration.local([
  YourModel.schema,
  SyncMetadata.schema,    // Required!
  SyncDBCache.schema,     // Required!
  SyncOutboxPatch.schema, // Required!
])
```

### Conflicts Not Resolving

The package uses last-write-wins conflict resolution based on `sync_updated_at` timestamps. Ensure:

1. Timestamps are being set (use `writeWithSync()` helpers)
2. Server is correctly comparing timestamps
3. System clocks are reasonably synchronized

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built on top of the excellent [realm_flutter_vector_db](https://pub.dev/packages/realm_flutter_vector_db) package
- Inspired by the now-deprecated MongoDB Atlas Device Sync
- Socket.IO for reliable real-time communication

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/mohit67890/flutter_realm_sync/issues)
- **Discussions**: [GitHub Discussions](https://github.com/mohit67890/flutter_realm_sync/discussions)
- **Server Issues**: [Server GitHub Issues](https://github.com/mohit67890/realm-sync-server/issues)
- **Documentation**: [Full API Documentation](https://pub.dev/documentation/flutter_realm_sync)

---

**Made with ❤️ for the Flutter community**
