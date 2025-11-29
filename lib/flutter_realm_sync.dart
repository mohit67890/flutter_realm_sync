import 'flutter_realm_sync_platform_interface.dart';

export 'services/RealmHelpers/realm_sync_extensions.dart';

// Export models
export 'services/Models/sync_metadata.dart';

class FlutterRealmSync {
  Future<String?> getPlatformVersion() {
    return FlutterRealmSyncPlatform.instance.getPlatformVersion();
  }
}
