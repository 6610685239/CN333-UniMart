import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../models/chat_room.dart';
import '../services/chat_service.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String userId;

  const ChatListScreen({super.key, required this.userId});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final Color _primaryColor = const Color(0xFFFF6F61);

  List<ChatRoom> _rooms = [];
  bool _isLoading = true;
  String? _error;

  IO.Socket? _socket;
  Timer? _pollTimer;
  final Set<String> _joinedRooms = {};

  List<ChatRoom> get _buyRooms => _rooms.where((r) => r.isBuyer).toList();
  List<ChatRoom> get _sellRooms => _rooms.where((r) => !r.isBuyer).toList();

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _initSocket();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadRooms(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  void _initSocket() {
    final socketUrl = AppConfig.baseUrl.replaceAll('/api', '');
    final transports = kIsWeb ? ['polling', 'websocket'] : ['websocket'];

    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(transports)
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      print('ChatList socket connected: ${_socket!.id}');
      _socket!.emit('join_user', widget.userId);
      _joinedRooms.clear();
      for (final room in _rooms) {
        _socket!.emit('join_room', room.id);
        _joinedRooms.add(room.id);
      }
    });

    _socket!.onConnectError((err) => print('ChatList socket error: $err'));

    _socket!.on('new_message', (data) {
      if (!mounted) return;
      _loadRooms(silent: true);
    });

    _socket!.onDisconnect((_) => print('ChatList socket disconnected'));

    _socket!.connect();
  }

  Future<void> _loadRooms({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final rooms = await ChatService.getRooms(widget.userId);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoading = false;
        });
        if (_socket?.connected == true) {
          for (final room in rooms) {
            if (!_joinedRooms.contains(room.id)) {
              _socket!.emit('join_room', room.id);
              _joinedRooms.add(room.id);
            }
          }
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = 'โหลดรายการแชทไม่สำเร็จ';
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inHours < 1) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inDays < 1) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('แชท', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          bottom: TabBar(
            labelColor: _primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _primaryColor,
            tabs: const [
              Tab(text: 'ซื้อ/เช่า'),
              Tab(text: 'ขาย/ปล่อยเช่า'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTabContent(_buyRooms),
            _buildTabContent(_sellRooms),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(List<ChatRoom> rooms) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadRooms,
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              child: const Text('ลองใหม่', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    if (rooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('ยังไม่มีการสนทนา', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRooms,
      color: _primaryColor,
      child: ListView.separated(
        itemCount: rooms.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) => _buildRoomItem(rooms[index]),
      ),
    );
  }

  Widget _buildRoomItem(ChatRoom room) {
    return Dismissible(
      key: Key(room.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await ChatService.deleteRoom(room.id.toString(), widget.userId);
        _loadRooms();
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _primaryColor.withOpacity(0.1),
              child: Text(
                room.otherUserName.isNotEmpty ? room.otherUserName[0].toUpperCase() : '?',
                style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            if (room.isPinned)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: const Icon(Icons.push_pin, size: 14, color: Colors.orange),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                room.otherUserName + (room.isLocked ? ' (จบแล้ว)' : ''),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: room.isLocked ? Colors.grey : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTime(room.lastMessageTime),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                room.lastMessage ?? 'ยังไม่มีข้อความ',
                style: TextStyle(
                  color: room.unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                  fontWeight: room.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (room.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        onTap: () async {
          // Mark as read immediately when tapping
          ChatService.markAsRead(room.id.toString(), widget.userId);

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomScreen(
                roomId: room.id,
                currentUserId: widget.userId,
                otherUserName: room.otherUserName,
                isLocked: room.isLocked,
              ),
            ),
          );
          _loadRooms();
        },
        onLongPress: () async {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('จัดการแชท'),
              content: const Text('คุณต้องการทำอะไรกับแชทนี้?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ChatService.pinRoom(room.id.toString(), widget.userId, !room.isPinned)
                        .then((_) => _loadRooms());
                  },
                  child: Text(room.isPinned ? 'เลิกปักหมุด' : 'ปักหมุด'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
