import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_realm_sync_method_channel.dart';

abstract class FlutterRealmSyncPlatform extends PlatformInterface {
  /// Constructs a FlutterRealmSyncPlatform.
  FlutterRealmSyncPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterRealmSyncPlatform _instance = MethodChannelFlutterRealmSync();

  /// The default instance of [FlutterRealmSyncPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterRealmSync].
  static FlutterRealmSyncPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterRealmSyncPlatform] when
  /// they register themselves.
  static set instance(FlutterRealmSyncPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
