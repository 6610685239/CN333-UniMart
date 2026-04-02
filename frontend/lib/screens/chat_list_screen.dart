import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rooms = await ChatService.getRooms(widget.userId);
      if (mounted) setState(() { _rooms = rooms; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'โหลดรายการแชทไม่สำเร็จ'; _isLoading = false; });
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('แชท', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                )
              : _rooms.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('ยังไม่มีการสนทนา', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRooms,
                      color: _primaryColor,
                      child: ListView.separated(
                        itemCount: _rooms.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) => _buildRoomItem(_rooms[index]),
                      ),
                    ),
    );
  }

  Widget _buildRoomItem(ChatRoom room) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: _primaryColor.withOpacity(0.1),
        child: Text(
          room.otherUserName.isNotEmpty ? room.otherUserName[0].toUpperCase() : '?',
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              room.otherUserName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              roomId: room.id,
              currentUserId: widget.userId,
              otherUserName: room.otherUserName,
            ),
          ),
        );
        // Refresh rooms when returning from chat
        _loadRooms();
      },
    );
  }
}
