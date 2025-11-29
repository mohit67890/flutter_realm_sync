import 'flutter_realm_sync_platform_interface.dart';

export 'services/RealmHelpers/RealmSyncExtensions.dart';

// Export models
export 'services/Models/SyncMetadata.dart';

class FlutterRealmSync {
  Future<String?> getPlatformVersion() {
    return FlutterRealmSyncPlatform.instance.getPlatformVersion();
  }
}
