## 0.0.1

**🎉 Initial Release - The Official Atlas Device Sync Replacement**

### ✨ Core Features

* **Real-time Bidirectional Sync**: Seamless synchronization between Realm database and MongoDB Atlas
* **Socket.IO Integration**: Reliable WebSocket-based communication for instant updates
* **Offline-First Architecture**: Full CRUD operations work offline with automatic sync when online
* **Conflict Resolution**: Automatic last-write-wins strategy with millisecond-precision timestamps
* **Batch Operations**: Intelligent batching and debouncing for optimal network usage
* **Production-Ready Server**: Complete Node.js + TypeScript server included

### 🔧 Technical Capabilities

* **Multi-Device Support**: Real-time updates across iOS, Android, macOS, and web
* **Historic Sync**: Catch up on missed changes after being offline
* **Persistent Sync State**: Remembers sync progress across app restarts using `SyncMetadata`
* **Smart Outbox**: Persistent outbox with retry logic and exponential backoff
* **Change Tracking**: Detailed audit logs with `SyncDBCache` for all operations
* **Custom Serialization**: Support for custom `toSyncMap` and `fromServerMap` functions
* **Nested Objects**: Automatic serialization of embedded objects and relationships

### 🎨 Developer Experience

* **Automatic Timestamp Management**: `writeWithSync()` and `writeWithSyncMultiple()` helpers
* **Pre-Processors**: `emitPreProcessor` callback for custom data transformation before sync
* **Type-Safe**: Full generic support with `SyncCollectionConfig<T>`
* **Comprehensive Validation**: `SyncValidator` catches configuration issues early
* **Event Streams**: `changes` stream for monitoring all sync events
* **Manual Sync Triggers**: `syncObject()` and `syncObjects()` for explicit sync control

### 📦 Included Models

* `SyncMetadata`: Tracks last remote timestamps per collection
* `SyncDBCache`: Caches diffs for offline conflict resolution
* `SyncOutboxPatch`: Persistent outbox for reliable sync operations

### 🧪 Battle-Tested

* Comprehensive integration tests covering:
  * CRUD operations (Create, Read, Update, Delete)
  * Batch operations (bulk inserts, updates)
  * Concurrent modifications and conflict resolution
  * Multi-device synchronization
  * Network interruption handling
  * Historic change synchronization
  * Special characters and edge cases
  * MongoDB replication verification

### 📚 Documentation

* Complete README with quick start guide
* Architecture diagrams and data flow visualization
* Full-featured chat example app
* Production benchmark data
* Troubleshooting guide

### 🔗 Related Projects

* Server: [realm-sync-server](https://github.com/mohit67890/realm-sync-server)
* Built with: [realm_flutter_vector_db](https://pub.dev/packages/realm_flutter_vector_db)

### 🙏 Acknowledgments

Built as an open-source replacement for the deprecated MongoDB Atlas Device Sync.
Designed for the Flutter community by developers who refused to accept vendor lock-in.
