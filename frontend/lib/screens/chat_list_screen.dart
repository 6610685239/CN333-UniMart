import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../models/chat_room.dart';
import '../services/chat_service.dart';
import 'chat_room_screen.dart';

/// Unified chat list — single list with auto-tags [ขาย]/[ซื้อ]/[ปล่อยเช่า]/[เช่า].
class ChatListScreen extends StatefulWidget {
  final String userId;

  const ChatListScreen({super.key, required this.userId});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // ── Theme ──
  static const Color _primary = Color(0xFFFF6F61);

  // ── State ──
  List<ChatRoom> _rooms = [];
  bool _isLoading = true;
  String? _error;

  // ── Socket & polling ──
  IO.Socket? _socket;
  Timer? _pollTimer;
  final Set<String> _joinedRooms = {};

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _initSocket();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) _loadRooms(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cleanupSocket();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Socket
  // ─────────────────────────────────────────────

  void _initSocket() {
    final socketUrl = AppConfig.baseUrl.replaceAll('/api', '');
    final transports = kIsWeb ? ['polling', 'websocket'] : ['websocket'];

    _socket = IO.io(socketUrl, {
      'transports': transports,
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 2000,
      'forceNew': true,
    });

    _socket!.onConnect((_) {
      _socket!.emit('join_user', widget.userId);
      _joinedRooms.clear();
      for (final room in _rooms) {
        _socket!.emit('join_room', room.id);
        _joinedRooms.add(room.id);
      }
    });

    _socket!.on('new_message', (_) {
      if (mounted) _loadRooms(silent: true);
    });

    _socket!.on('messages_read', (_) {
      if (mounted) _loadRooms(silent: true);
    });

    _socket!.connect();
  }

  void _cleanupSocket() {
    if (_socket != null) {
      _socket!.off('new_message');
      _socket!.off('messages_read');
      for (final id in _joinedRooms) {
        _socket!.emit('leave_room', id);
      }
      _joinedRooms.clear();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  // ─────────────────────────────────────────────
  // Data
  // ─────────────────────────────────────────────

  Future<void> _loadRooms({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final rooms = await ChatService.getRooms(widget.userId);
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
      // Join new rooms on socket
      if (_socket?.connected == true) {
        for (final room in rooms) {
          if (!_joinedRooms.contains(room.id)) {
            _socket!.emit('join_room', room.id);
            _joinedRooms.add(room.id);
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

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  /// Format timestamps in local timezone.
  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final local = time; // already .toLocal() in model
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inHours < 1) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inDays < 1) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'เมื่อวาน';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return '${local.day}/${local.month}/${local.year}';
  }

  String _productImageUrl(ChatRoom room) {
    if (room.productImages.isNotEmpty) {
      final img = room.productImages.first;
      if (img.startsWith('http')) return img;
      return '${AppConfig.uploadsUrl}/$img';
    }
    return '';
  }

  Color _tagColor(String tag) {
    if (tag.contains('ขาย') || tag.contains('ปล่อยเช่า')) {
      return Colors.green;
    }
    return Colors.blue;
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('แชท', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              child: const Text('ลองใหม่', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    if (_rooms.isEmpty) {
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
      color: _primary,
      child: ListView.separated(
        itemCount: _rooms.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) => _buildRoomTile(_rooms[index]),
      ),
    );
  }

  Widget _buildRoomTile(ChatRoom room) {
    final tag = room.tagFor(widget.userId);
    final imgUrl = _productImageUrl(room);

    return Dismissible(
      key: Key(room.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await ChatService.deleteRoom(room.id.toString(), widget.userId);
        _loadRooms();
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            // Product thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imgUrl.isNotEmpty
                  ? Image.network(
                      imgUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderImage(),
                    )
                  : _placeholderImage(),
            ),
            // Pinned indicator
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
            // Tag badge
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _tagColor(tag).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: _tagColor(tag),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Other user name
            Expanded(
              child: Text(
                room.otherUserName + (room.isLocked ? ' (จบแล้ว)' : ''),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: room.isLocked ? Colors.grey : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Timestamp
            Text(
              _formatTime(room.lastMessageTime),
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              // Product title + last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.productTitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      room.lastMessageType == 'image'
                          ? '📷 รูปภาพ'
                          : room.lastMessage ?? 'ยังไม่มีข้อความ',
                      style: TextStyle(
                        color: room.unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                        fontWeight: room.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Unread badge
              if (room.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        onTap: () async {
          // Pre-mark as read
          ChatService.markAsRead(room.id.toString(), widget.userId);

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                roomId: room.id,
                currentUserId: widget.userId,
                otherUserName: room.otherUserName,
                isLocked: room.isLocked,
              ),
            ),
          );
          // Refresh on return
          _loadRooms();
        },
        onLongPress: () {
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

  Widget _placeholderImage() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.shopping_bag_outlined, color: _primary, size: 26),
    );
  }
}
