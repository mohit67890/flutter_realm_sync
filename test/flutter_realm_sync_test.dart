import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realm_sync/flutter_realm_sync.dart';
import 'package:flutter_realm_sync/flutter_realm_sync_platform_interface.dart';
import 'package:flutter_realm_sync/flutter_realm_sync_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterRealmSyncPlatform
    with MockPlatformInterfaceMixin
    implements FlutterRealmSyncPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterRealmSyncPlatform initialPlatform = FlutterRealmSyncPlatform.instance;

  test('$MethodChannelFlutterRealmSync is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterRealmSync>());
  });

  test('getPlatformVersion', () async {
    FlutterRealmSync flutterRealmSyncPlugin = FlutterRealmSync();
    MockFlutterRealmSyncPlatform fakePlatform = MockFlutterRealmSyncPlatform();
    FlutterRealmSyncPlatform.instance = fakePlatform;

    expect(await flutterRealmSyncPlugin.getPlatformVersion(), '42');
  });
}
