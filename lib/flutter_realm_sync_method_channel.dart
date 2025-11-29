import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_realm_sync_platform_interface.dart';

/// An implementation of [FlutterRealmSyncPlatform] that uses method channels.
class MethodChannelFlutterRealmSync extends FlutterRealmSyncPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_realm_sync');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
