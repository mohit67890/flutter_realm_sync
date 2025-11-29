import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

final String url = 'http://localhost:3000';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Simple two socket connection test', (WidgetTester tester) async {
    print('\n🌐 Testing two socket connections to: $url\n');

    // Socket 1
    final socket1Connected = Completer<void>();
    final socket1 = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket1.onConnect((_) {
      print('✅ Socket 1: Connected!');
      socket1Connected.complete();
    });
    socket1.onConnectError((error) => print('❌ Socket 1: Error: $error'));

    print('🔌 Socket 1: Connecting...');
    socket1.connect();
    await socket1Connected.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('Socket 1 timeout'),
    );

    print('\n⏳ Waiting 1 second before socket 2...\n');
    await Future.delayed(const Duration(seconds: 1));

    // Socket 2
    final socket2Connected = Completer<void>();
    final socket2 = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket2.onConnect((_) {
      print('✅ Socket 2: Connected!');
      socket2Connected.complete();
    });
    socket2.onConnectError((error) => print('❌ Socket 2: Error: $error'));

    print('🔌 Socket 2: Connecting...');
    socket2.connect();
    await socket2Connected.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('Socket 2 timeout'),
    );

    print('\n✅ SUCCESS: Both sockets connected!\n');

    socket1.dispose();
    socket2.dispose();
  });
}
