import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String otherUserName;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.otherUserName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final Color _primaryColor = const Color(0xFFFF6F61);
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  // Track failed messages for retry
  final Set<String> _failedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await ChatService.getMessages(widget.roomId);
      if (mounted) {
        setState(() { _messages = messages; _isLoading = false; });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Supabase Realtime subscription placeholder
  void _subscribeToMessages() {
    // TODO: Replace with actual Supabase Realtime subscription
    // when Supabase Flutter client is configured.
    // ChatService.subscribeToMessages(widget.roomId).listen((messages) {
    //   if (mounted) {
    //     setState(() => _messages = messages);
    //     _scrollToBottom();
    //   }
    // });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? content, String type = 'text'}) async {
    final text = content ?? _messageController.text.trim();
    if (text.isEmpty) return;

    if (type == 'text') _messageController.clear();

    // Optimistic UI: add message locally
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = ChatMessage(
      id: tempId,
      roomId: widget.roomId,
      senderId: widget.currentUserId,
      content: type == 'text' ? text : null,
      imageUrl: type == 'image' ? text : null,
      type: type,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMessage);
      _isSending = true;
    });
    _scrollToBottom();

    final result = await ChatService.sendMessage(
      widget.roomId,
      widget.currentUserId,
      text,
      type,
    );

    if (mounted) {
      if (result['id'] != null) {
        // Success — replace temp message with server response
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == tempId);
          if (idx != -1) {
            _messages[idx] = ChatMessage.fromJson(result);
          }
          _failedMessageIds.remove(tempId);
          _isSending = false;
        });
      } else {
        // Failed — mark as failed
        setState(() {
          _failedMessageIds.add(tempId);
          _isSending = false;
        });
      }
    }
  }

  Future<void> _retryMessage(ChatMessage msg) async {
    setState(() {
      _failedMessageIds.remove(msg.id);
      _messages.removeWhere((m) => m.id == msg.id);
    });
    await _sendMessage(content: msg.type == 'image' ? msg.imageUrl : msg.content, type: msg.type);
  }

  void _handleAttachImage() {
    // Placeholder: show snackbar until image picker is integrated
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ฟีเจอร์แนบรูปภาพกำลังพัฒนา...')),
    );
  }

  void _showReportDialog() {
    final reasons = [
      'ข้อความไม่เหมาะสม',
      'สแปม / โฆษณา',
      'หลอกลวง / ฉ้อโกง',
      'คุกคาม / ข่มขู่',
      'อื่นๆ',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('รายงานผู้ใช้', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('เลือกเหตุผลในการรายงาน', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ...reasons.map((reason) => ListTile(
              title: Text(reason),
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () {
                Navigator.pop(ctx);
                _submitReport(reason);
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    // We don't know the other user's ID directly, but we can derive it
    // For now, pass a placeholder — the backend can resolve from roomId
    final result = await ChatService.reportUser(
      widget.roomId,
      widget.currentUserId,
      '', // reportedUserId — resolved by backend from room participants
      reason,
    );

    if (mounted) {
      if (result['id'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งรายงานเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'ส่งรายงานไม่สำเร็จ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.otherUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.red),
            tooltip: 'รายงาน',
            onPressed: _showReportDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('ยังไม่มีข้อความ เริ่มสนทนาเลย!',
                            style: TextStyle(color: Colors.grey, fontSize: 15)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                      ),
          ),
          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isMe = msg.senderId == widget.currentUserId;
    final isFailed = _failedMessageIds.contains(msg.id);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isFailed
                    ? Colors.red[50]
                    : isMe
                        ? _primaryColor
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: msg.type == 'image' && msg.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        msg.imageUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                      ),
                    )
                  : Text(
                      msg.content ?? '',
                      style: TextStyle(
                        color: isFailed ? Colors.red : (isMe ? Colors.white : Colors.black87),
                        fontSize: 15,
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            // Time + failed status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                if (isFailed) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.error_outline, color: Colors.red, size: 14),
                  const SizedBox(width: 2),
                  const Text('ส่งไม่สำเร็จ', style: TextStyle(color: Colors.red, fontSize: 11)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _retryMessage(msg),
                    child: Text(
                      'ส่งซ้ำ',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Attach image button
            IconButton(
              icon: Icon(Icons.image_outlined, color: Colors.grey[600]),
              onPressed: _handleAttachImage,
              tooltip: 'แนบรูปภาพ',
            ),
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'พิมพ์ข้อความ...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Send button
            Container(
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _isSending ? null : () => _sendMessage(),
                tooltip: 'ส่ง',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
