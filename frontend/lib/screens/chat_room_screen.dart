import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../models/chat_message.dart';
import '../models/product.dart';
import '../services/chat_service.dart';
import 'product_detail_screen.dart';

/// Chat room screen with:
/// - Product header (image, name, price) — tappable to product detail
/// - Load history via REST, then socket for real-time only
/// - Proper socket cleanup on dispose
/// - Read / unread status (อ่านแล้ว indicator)
/// - Offline handling: pending messages + auto-retry
class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String otherUserName;
  final bool isLocked;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.otherUserName,
    this.isLocked = false,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  // ── Constants ──
  static const Color _primary = Color(0xFFFF6F61);

  // ── Controllers ──
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // ── State ──
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _allRead = false; // whether the last own message has been read

  // Room detail (product header)
  Map<String, dynamic>? _roomDetail;

  // ── Socket ──
  IO.Socket? _socket;
  bool _socketJoined = false;

  // ── Offline queue ──
  final List<ChatMessage> _pendingQueue = [];
  Timer? _retryTimer;

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 1. Load room detail (product header) + messages in parallel
    await Future.wait([
      _loadRoomDetail(),
      _loadMessages(),
    ]);
    // 2. Mark as read
    ChatService.markAsRead(widget.roomId, widget.currentUserId);
    // 3. Then connect socket for real-time
    _initSocket();
    // 4. Start offline retry timer
    _retryTimer = Timer.periodic(const Duration(seconds: 5), (_) => _flushPendingQueue());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect socket if needed & flush any pending messages
      if (_socket?.connected != true) _socket?.connect();
      _flushPendingQueue();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _cleanupSocket();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────

  Future<void> _loadRoomDetail() async {
    try {
      final detail = await ChatService.getRoomDetail(widget.roomId);
      if (mounted && detail['product'] != null) {
        setState(() => _roomDetail = detail);
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final messages = await ChatService.getMessages(widget.roomId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
        _checkReadStatus();
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  // Socket — connect AFTER loading history
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
      _socket!.emit('join_room', widget.roomId);
      _socket!.emit('join_user', widget.currentUserId);
      _socketJoined = true;
      // Flush any messages queued while offline
      _flushPendingQueue();
    });

    _socket!.on('new_message', _onNewMessage);
    _socket!.on('messages_read', _onMessagesRead);
    _socket!.connect();
  }

  void _cleanupSocket() {
    if (_socket != null) {
      // Remove listeners first to prevent ghost events
      _socket!.off('new_message');
      _socket!.off('messages_read');
      if (_socketJoined) {
        _socket!.emit('leave_room', widget.roomId);
        _socketJoined = false;
      }
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  void _onNewMessage(dynamic data) {
    if (!mounted) return;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(jsonEncode(data)));
      final msg = ChatMessage.fromJson(json);

      // Dedup
      if (_messages.any((m) => m.id == msg.id)) return;

      if (msg.senderId == widget.currentUserId) {
        // Own message echoed back — replace oldest temp_ message
        final tempIdx = _messages.indexWhere((m) => m.id.startsWith('temp_'));
        if (tempIdx != -1) {
          setState(() => _messages[tempIdx] = msg);
          _scrollToBottom();
        }
        return;
      }

      // Other user's message
      setState(() => _messages.add(msg));
      _scrollToBottom();
      // Auto mark as read since the room is open
      ChatService.markAsRead(widget.roomId, widget.currentUserId);
      _socket?.emit('mark_as_read', {'roomId': widget.roomId, 'userId': widget.currentUserId});
    } catch (_) {}
  }

  void _onMessagesRead(dynamic data) {
    if (!mounted) return;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(jsonEncode(data)));
      final readBy = json['readByUserId'];
      // If the OTHER user read our messages → show "อ่านแล้ว"
      if (readBy != null && readBy != widget.currentUserId) {
        setState(() {
          _allRead = true;
          _messages = _messages.map((m) {
            if (m.senderId == widget.currentUserId && !m.isRead) {
              return m.copyWith(isRead: true);
            }
            return m;
          }).toList();
        });
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // Send message + offline queue
  // ─────────────────────────────────────────────

  Future<void> _sendMessage({String? content, String type = 'text'}) async {
    final text = content ?? _msgCtrl.text.trim();
    if (text.isEmpty) return;
    if (type == 'text') _msgCtrl.clear();

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = ChatMessage(
      id: tempId,
      roomId: widget.roomId,
      senderId: widget.currentUserId,
      content: type == 'text' ? text : null,
      imageUrl: type == 'image' ? text : null,
      type: type,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
    );

    setState(() {
      _messages.add(tempMsg);
      _isSending = true;
      _allRead = false; // new message not yet read by other
    });
    _scrollToBottom();

    await _attemptSend(tempMsg, text);
  }

  Future<void> _attemptSend(ChatMessage tempMsg, String text) async {
    try {
      final result = await ChatService.sendMessage(
        widget.roomId, widget.currentUserId, text, tempMsg.type,
      );

      if (!mounted) return;

      if (result['id'] != null) {
        // Success
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == tempMsg.id);
          if (idx != -1) {
            _messages[idx] = ChatMessage.fromJson(result);
          }
          _pendingQueue.removeWhere((m) => m.id == tempMsg.id);
          _isSending = false;
        });
      } else {
        _markAsFailed(tempMsg);
      }
    } catch (_) {
      _markAsFailed(tempMsg);
    }
  }

  void _markAsFailed(ChatMessage tempMsg) {
    if (!mounted) return;
    // Check if we're likely offline
    final isOffline = _socket?.connected != true;
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == tempMsg.id);
      if (idx != -1) {
        _messages[idx] = tempMsg.copyWith(
          status: isOffline ? MessageStatus.pending : MessageStatus.failed,
        );
      }
      _isSending = false;
    });
    // Add to pending queue for auto-retry if offline
    if (isOffline && !_pendingQueue.any((m) => m.id == tempMsg.id)) {
      _pendingQueue.add(tempMsg);
    }
  }

  /// Auto-retry pending messages when connection is restored.
  Future<void> _flushPendingQueue() async {
    if (_pendingQueue.isEmpty || _socket?.connected != true) return;
    final queue = List<ChatMessage>.from(_pendingQueue);
    for (final msg in queue) {
      final text = msg.type == 'image' ? msg.imageUrl! : msg.content!;
      await _attemptSend(msg, text);
    }
  }

  Future<void> _retryMessage(ChatMessage msg) async {
    final text = msg.type == 'image' ? msg.imageUrl : msg.content;
    if (text == null) return;
    // Reset status to pending
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == msg.id);
      if (idx != -1) {
        _messages[idx] = msg.copyWith(status: MessageStatus.pending);
      }
    });
    await _attemptSend(msg, text);
  }

  // ─────────────────────────────────────────────
  // Read status helpers
  // ─────────────────────────────────────────────

  void _checkReadStatus() {
    // Check if the last own message is read
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].senderId == widget.currentUserId) {
        _allRead = _messages[i].isRead;
        break;
      }
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleAttachImage() {
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
            ...reasons.map((r) => ListTile(
              title: Text(r),
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () {
                Navigator.pop(ctx);
                _submitReport(r);
              },
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
        ],
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    final result = await ChatService.reportUser(widget.roomId, widget.currentUserId, '', reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['id'] != null ? 'ส่งรายงานเรียบร้อยแล้ว' : result['message'] ?? 'ส่งรายงานไม่สำเร็จ'),
      backgroundColor: result['id'] != null ? Colors.green : Colors.red,
    ));
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

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
          // ── Product header ──
          _buildProductHeader(),
          // ── Messages ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('ยังไม่มีข้อความ เริ่มสนทนาเลย!',
                            style: TextStyle(color: Colors.grey, fontSize: 15)),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length + (_allRead ? 1 : 0),
                        itemBuilder: (context, index) {
                          // "อ่านแล้ว" indicator at the very end
                          if (_allRead && index == _messages.length) {
                            return _buildReadIndicator();
                          }
                          return _buildBubble(_messages[index]);
                        },
                      ),
          ),
          // ── Input bar ──
          if (!widget.isLocked) _buildInputBar(),
          if (widget.isLocked) _buildLockedBar(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Product header
  // ─────────────────────────────────────────────

  Widget _buildProductHeader() {
    final product = _roomDetail?['product'] as Map<String, dynamic>?;
    if (product == null) return const SizedBox.shrink();

    final images = product['images'] as List? ?? [];
    final imgUrl = images.isNotEmpty
        ? (images.first.toString().startsWith('http')
            ? images.first.toString()
            : '${AppConfig.uploadsUrl}/${images.first}')
        : '';
    final title = product['title'] ?? '';
    final price = product['price'] ?? 0;
    final type = product['type'] ?? 'SALE';
    final rentPrice = product['rentPrice'] ?? 0;

    return GestureDetector(
      onTap: () => _navigateToProductDetail(product),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imgUrl.isNotEmpty
                  ? Image.network(imgUrl, width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _productPlaceholder())
                  : _productPlaceholder(),
            ),
            const SizedBox(width: 12),
            // Title + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    type == 'RENT' ? '฿$rentPrice/เดือน' : '฿$price',
                    style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _navigateToProductDetail(Map<String, dynamic> productJson) {
    // Build a Product model from the room detail data + fetch via API if needed
    try {
      // Construct a minimal Product-compatible JSON
      final fullJson = {
        'id': productJson['id'],
        'title': productJson['title'],
        'description': '',
        'price': productJson['price'],
        'status': productJson['status'] ?? 'AVAILABLE',
        'condition': '',
        'images': productJson['images'] ?? [],
        'category': null,
        'location': '',
        'ownerId': productJson['ownerId'] ?? '',
        'owner': null,
        'type': productJson['type'] ?? 'SALE',
        'rentPrice': productJson['rentPrice'],
      };
      final product = Product.fromJson(fullJson);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: product,
            currentUserId: widget.currentUserId,
          ),
        ),
      );
    } catch (_) {}
  }

  Widget _productPlaceholder() {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
    );
  }

  // ─────────────────────────────────────────────
  // Read indicator
  // ─────────────────────────────────────────────

  Widget _buildReadIndicator() {
    return const Padding(
      padding: EdgeInsets.only(right: 16, bottom: 8, top: 2),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text('อ่านแล้ว', style: TextStyle(color: Colors.grey, fontSize: 11)),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Message bubble
  // ─────────────────────────────────────────────

  Widget _buildBubble(ChatMessage msg) {
    final isMe = msg.senderId == widget.currentUserId;
    final isPending = msg.status == MessageStatus.pending;
    final isFailed = msg.status == MessageStatus.failed;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Opacity(
          opacity: isPending ? 0.5 : 1.0,
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isFailed
                      ? Colors.red[50]
                      : isMe
                          ? _primary
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
                        child: Image.network(msg.imageUrl!, width: 200, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48)),
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
              // Timestamp + status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  if (isPending) ...[
                    const SizedBox(width: 4),
                    const SizedBox(width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5)),
                    const SizedBox(width: 2),
                    const Text('กำลังส่ง...', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                  if (isFailed) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.error_outline, color: Colors.red, size: 14),
                    const SizedBox(width: 2),
                    const Text('ส่งไม่สำเร็จ', style: TextStyle(color: Colors.red, fontSize: 11)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _retryMessage(msg),
                      child: Text('ส่งซ้ำ',
                          style: TextStyle(
                            color: _primary, fontSize: 11, fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          )),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Input bar
  // ─────────────────────────────────────────────

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.image_outlined, color: Colors.grey[600]),
              onPressed: _handleAttachImage,
              tooltip: 'แนบรูปภาพ',
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _msgCtrl,
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
            Container(
              decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
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

  Widget _buildLockedBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: Colors.grey[200],
        child: const Center(
          child: Text('การสนทนานี้จบลงแล้ว', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ),
      ),
    );
  }
}
