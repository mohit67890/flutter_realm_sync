import 'package:flutter/material.dart';
import 'dart:async';
import 'package:realm_flutter_vector_db/realm_vector_db.dart';
import 'package:flutter_realm_sync/services/RealmHelpers/realm_sync_historic_extension.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_realm_sync/services/RealmSync.dart';
import 'package:flutter_realm_sync/services/Models/sync_db_cache.dart';
import 'package:flutter_realm_sync/services/Models/sync_outbox_patch.dart';
import 'package:flutter_realm_sync/services/Models/sync_metadata.dart';
import 'models/ChatMessage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RealmSync Chat Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _serverController = TextEditingController(
    text: 'http://localhost:3000',
  );

  @override
  void dispose() {
    _usernameController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  void _joinChat() {
    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a username')));
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (context) => ChatScreen(
              username: _usernameController.text.trim(),
              serverUrl: _serverController.text.trim(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RealmSync Chat'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.blue),
            const SizedBox(height: 32),
            const Text(
              'Multi-Device Chat Demo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Real-time sync across devices',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              onSubmitted: (_) => _joinChat(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serverController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.cloud),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _joinChat,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Join Chat', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String username;
  final String serverUrl;

  const ChatScreen({
    super.key,
    required this.username,
    required this.serverUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Realm? realm;
  IO.Socket? socket;
  RealmSync? realmSync;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isJoined = false;
  String _connectionStatus = 'Initializing...';
  late String userId;

  @override
  void initState() {
    super.initState();
    userId = 'user-${widget.username}-${DateTime.now().millisecondsSinceEpoch}';
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      // Initialize Realm with in-memory configuration
      final config = Configuration.local([
        ChatMessage.schema,
        SyncDBCache.schema,
        SyncOutboxPatch.schema,
        SyncMetadata.schema,
      ], schemaVersion: 1);
      realm = Realm(config);

      setState(() {
        _connectionStatus = 'Connecting to server...';
      });

      // Initialize Socket
      final options =
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .disableAutoConnect()
              .setTimeout(5000)
              .setReconnectionAttempts(5)
              .build();

      socket = IO.io(widget.serverUrl, options);

      socket?.onConnect((_) {
        print('🔌 Socket connected');
        setState(() {
          _connectionStatus = 'Joining...';
        });

        socket?.emitWithAck(
          'sync:join',
          {'userId': userId},
          ack: (data) {
            print('📨 Join response: $data');
            if (data != null && data['success'] == true) {
              setState(() {
                _isJoined = true;
                _connectionStatus = 'Connected ✓';
              });
              _initializeRealmSync();
            }
          },
        );
      });

      socket?.onDisconnect((_) {
        setState(() {
          _isJoined = false;
          _connectionStatus = 'Disconnected';
        });
      });

      socket?.onConnectError((error) {
        print('❌ Connection error: $error');
        setState(() {
          _connectionStatus = 'Connection error: $error';
        });
      });

      socket?.connect();
    } catch (e) {
      print('❌ Initialization error: $e');
      setState(() {
        _connectionStatus = 'Error: $e';
      });
    }
  }

  void _initializeRealmSync() {
    try {
      if (realm == null) return;

      final results = realm!.all<ChatMessage>();

      print(
        '📋 Initializing RealmSync with ${results.length} existing messages',
      );

      realmSync = RealmSync(
        realm: realm!,
        socket: socket!,
        userId: userId,
        configs: [
          SyncCollectionConfig<ChatMessage>(
            collectionName: 'chat_messages',
            results: results,
            idSelector: (obj) => obj.id,
            needsSync: (obj) => obj.syncUpdateDb,
          ),
        ],
      );

      // Start the sync - this initializes the SyncHelper
      realmSync!.start();
      print('✅ RealmSync initialized and started for chat_messages');

      // Listen for incoming sync messages

      realmSync?.fetchAllHistoricChanges(applyLocally: true);
    } catch (e) {
      print('❌ RealmSync initialization error: $e');
      setState(() {
        _connectionStatus = 'RealmSync error: $e';
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || realm == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    final messageId = ObjectId().toString();

    // Create and add the message
    final tempMessage = ChatMessage(
      messageId,
      messageText,
      widget.username,
      userId,
      DateTime.now(),
    );

    realm!.write(() {
      tempMessage.syncUpdateDb = true; // Mark for sync BEFORE adding
      realm!.add(tempMessage);
    });

    print('📤 Sending message: $messageId - "$messageText"');

    // Trigger sync
    realmSync?.syncObject('chat_messages', messageId);

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    realmSync?.dispose();
    if (realm != null && !realm!.isClosed) realm!.close();
    socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Demo Chat Room'),
            Text(
              _connectionStatus,
              style: TextStyle(
                fontSize: 12,
                color: _isJoined ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          Switch(
            value: socket?.connected ?? false,
            onChanged: (value) {
              if (value) {
                socket?.connect();
              } else {
                socket?.disconnect();
              }
              setState(() {
                _connectionStatus = value ? 'Connected' : 'Disconnected';
                _isJoined = value;
              });
            },
          ),

          GestureDetector(
            onTap: () {
              RealmResults<SyncMetadata> metadataResults = realm!
                  .all<SyncMetadata>()
                  .query('collectionName == "chat_messages"');
              if (metadataResults.isNotEmpty) {
                final metadata = metadataResults.first;
                print(
                  'ℹ️ SyncMetadata for chat_messages: lastRemoteTimestamp=${metadata.lastRemoteTimestamp}',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Last synced at timestamp: ${metadata.lastRemoteTimestamp}',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No sync metadata found for chat_messages'),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                avatar: Icon(
                  _isJoined ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: _isJoined ? Colors.green : Colors.orange,
                ),
                label: Text(widget.username),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                realm == null
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<RealmResultsChanges<ChatMessage>>(
                      stream: realm!.all<ChatMessage>().changes,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final messages = realm!.all<ChatMessage>().query(
                          'TRUEPREDICATE SORT(timestamp ASC)',
                        );

                        if (messages.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages yet',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Send a message to start the conversation',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            final isMe = msg.senderId == userId;

                            return Align(
                              alignment:
                                  isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.blue : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        msg.senderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    Text(
                                      msg.text,
                                      style: TextStyle(
                                        color:
                                            isMe ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      _formatTime(msg.timestamp),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color:
                                            isMe
                                                ? Colors.white70
                                                : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText:
                          _isJoined ? 'Type a message...' : 'Connecting...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
