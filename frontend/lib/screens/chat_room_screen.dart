import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../models/chat_message.dart';
import '../models/product.dart';
import '../services/chat_service.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import 'product_detail_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final bool isLocked;
  final bool isPinned;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.isLocked = false,
    this.isPinned = false,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  // ── Controllers ──
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // ── State ──
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _allRead = false;
  bool _otherTyping = false;
  late bool _isPinned;

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
    _isPinned = widget.isPinned;
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadRoomDetail(), _loadMessages()]);
    ChatService.markAsRead(widget.roomId, widget.currentUserId);
    _initSocket();
    _retryTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _flushPendingQueue());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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
  // Data
  // ─────────────────────────────────────────────

  Future<void> _loadRoomDetail() async {
    try {
      final detail = await ChatService.getRoomDetail(widget.roomId);
      if (mounted && detail['success'] != false) {
        setState(() => _roomDetail = detail);
      }
    } catch (_) {}
  }

  String _getReportedUserId() {
    final buyerId = _roomDetail?['buyerId']?.toString();
    final sellerId = _roomDetail?['sellerId']?.toString();
    if (buyerId == widget.currentUserId) return sellerId ?? '';
    if (sellerId == widget.currentUserId) return buyerId ?? '';
    return '';
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
      _socket!.emit('join_room', widget.roomId);
      _socket!.emit('join_user', widget.currentUserId);
      _socketJoined = true;
      _flushPendingQueue();
    });

    _socket!.on('new_message', _onNewMessage);
    _socket!.on('messages_read', _onMessagesRead);
    _socket!.connect();
  }

  void _cleanupSocket() {
    if (_socket != null) {
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

      if (_messages.any((m) => m.id == msg.id)) return;

      if (msg.senderId == widget.currentUserId) {
        final tempIdx = _messages.indexWhere((m) => m.id.startsWith('temp_'));
        if (tempIdx != -1) {
          setState(() => _messages[tempIdx] = msg);
          _scrollToBottom();
        }
        return;
      }

      setState(() {
        _messages.add(msg);
        _otherTyping = false;
      });
      _scrollToBottom();
      ChatService.markAsRead(widget.roomId, widget.currentUserId);
      _socket?.emit('mark_as_read',
          {'roomId': widget.roomId, 'userId': widget.currentUserId});
    } catch (_) {}
  }

  void _onMessagesRead(dynamic data) {
    if (!mounted) return;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(jsonEncode(data)));
      final readBy = json['readByUserId'];
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
      _allRead = false;
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
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == tempMsg.id);
          if (idx != -1) _messages[idx] = ChatMessage.fromJson(result);
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
    if (isOffline && !_pendingQueue.any((m) => m.id == tempMsg.id)) {
      _pendingQueue.add(tempMsg);
    }
  }

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
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == msg.id);
      if (idx != -1) _messages[idx] = msg.copyWith(status: MessageStatus.pending);
    });
    await _attemptSend(msg, text);
  }

  // ── Read status ────────────────────────────────

  void _checkReadStatus() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].senderId == widget.currentUserId) {
        _allRead = _messages[i].isRead;
        break;
      }
    }
  }

  // ── Helpers ────────────────────────────────────

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

  Future<void> _togglePin() async {
    final newVal = !_isPinned;
    setState(() => _isPinned = newVal);
    try {
      await ChatService.pinRoom(widget.roomId, widget.currentUserId, newVal);
    } catch (_) {
      if (mounted) setState(() => _isPinned = !newVal); // revert on error
    }
  }

  void _showReportDialog() {
    final reasons = [
      'ข้อความไม่เหมาะสม',
      'สแปม / โฆษณา',
      'หลอกลวง / ฉ้อโกง',
      'คุกคาม / ข่มขู่',
      'อื่นๆ',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // ── Title ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Report user',
                style: AppTextStyles.titleS.copyWith(color: AppColors.ink),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'Select a reason',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
            // ── Divider ──
            Divider(height: 1, color: AppColors.divider),
            // ── Reason items ──
            ...reasons.map((r) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _submitReport(r);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(r,
                              style: AppTextStyles.body
                                  .copyWith(color: AppColors.ink)),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                    height: 1,
                    indent: 46,
                    color: AppColors.divider),
              ],
            )),
            // ── Cancel ──
            InkWell(
              onTap: () => Navigator.pop(ctx),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    final reportedUserId = _getReportedUserId();
    if (reportedUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ไม่สามารถระบุผู้ใช้ที่ต้องการรายงานได้'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final result = await ChatService.reportUser(
      widget.roomId, widget.currentUserId, reportedUserId, reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['id'] != null
          ? 'ส่งรายงานเรียบร้อยแล้ว'
          : result['message'] ?? 'ส่งรายงานไม่สำเร็จ'),
      backgroundColor: result['id'] != null ? Colors.green : Colors.red,
    ));
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProductHeader(),
          Expanded(child: _buildMessageList()),
          widget.isLocked ? _buildLockedBar() : _buildInputBar(),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final initial = widget.otherUserName.isNotEmpty
        ? widget.otherUserName[0].toUpperCase()
        : '?';
    final avatarUrl = widget.otherUserAvatar == null
        ? null
        : widget.otherUserAvatar!.startsWith('http')
            ? widget.otherUserAvatar
            : '${AppConfig.uploadsUrl}/${widget.otherUserAvatar}';

    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.divider),
      ),
      leadingWidth: 56,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: AppColors.ink),
          ),
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Center(
                      child: Text(initial,
                          style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: _togglePin,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: _isPinned ? 'เลิกปักหมุด' : 'ปักหมุด',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isPinned ? AppColors.accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: _isPinned
                      ? null
                      : Border.all(color: AppColors.border, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 18,
                  color: _isPinned ? AppColors.ink : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.flag_outlined, size: 20, color: AppColors.textMuted),
          onPressed: _showReportDialog,
          tooltip: 'รายงาน',
        ),
      ],
    );
  }

  // ── Product header ─────────────────────────────

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
    final qty = product['quantity'] ?? 1;

    return GestureDetector(
      onTap: () => _navigateToProductDetail(product),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imgUrl.isNotEmpty
                  ? Image.network(imgUrl,
                      width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _productPlaceholder())
                  : _productPlaceholder(),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700, color: AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    type == 'RENT'
                        ? '฿$rentPrice/เดือน · $qty in stock · for rent'
                        : '฿$price · $qty in stock · for sale',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Text('view →',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _navigateToProductDetail(Map<String, dynamic> productJson) {
    try {
      // Determine the seller name: product owner is either the other user or current user
      final ownerId = productJson['ownerId']?.toString() ?? '';
      final ownerName = ownerId == widget.currentUserId
          ? '' // current user is the seller — name not needed here
          : widget.otherUserName;

      final fullJson = {
        'id': productJson['id'],
        'title': productJson['title'],
        'description': productJson['description'] ?? '',
        'price': productJson['price'],
        'status': productJson['status'] ?? 'AVAILABLE',
        'condition': productJson['condition'] ?? '',
        'images': productJson['images'] ?? [],
        'categoryName': productJson['categoryName'] ?? '',
        'location': productJson['location'] ?? '',
        'ownerId': ownerId,
        'ownerName': ownerName,
        'type': productJson['type'] ?? 'SALE',
        'rentPrice': productJson['rentPrice'],
        'quantity': productJson['quantity'] ?? 1,
        'favouritesCount': productJson['favouritesCount'] ?? 0,
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.shopping_bag_outlined,
          color: AppColors.textMuted, size: 22),
    );
  }

  // ── Message list ───────────────────────────────

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.ink));
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text('ยังไม่มีข้อความ เริ่มสนทนาเลย!',
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textMuted)),
      );
    }

    // Group messages by date for separators
    final items = <_ChatItem>[];
    DateTime? lastDate;
    for (final msg in _messages) {
      final d = DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (lastDate == null || d != lastDate) {
        items.add(_ChatItem.dateSeparator(msg.createdAt));
        lastDate = d;
      }
      items.add(_ChatItem.message(msg));
    }
    if (_allRead) items.add(_ChatItem.readIndicator());
    if (_otherTyping) items.add(_ChatItem.typingIndicator());

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.type == _ItemType.dateSeparator) {
          return _buildDateSeparator(item.date!);
        }
        if (item.type == _ItemType.readIndicator) {
          return _buildReadIndicator();
        }
        if (item.type == _ItemType.typingIndicator) {
          return _buildTypingIndicator();
        }
        return _buildBubble(item.message!);
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    String label;
    if (d == today) {
      label = 'today · ${_weekdayName(date.weekday)} ${date.day} ${_monthName(date.month)}';
    } else if (d == today.subtract(const Duration(days: 1))) {
      label = 'yesterday';
    } else {
      label = '${_weekdayName(date.weekday)} ${date.day} ${_monthName(date.month)}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
      ),
    );
  }

  Widget _buildReadIndicator() {
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 8, top: 2),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text('อ่านแล้ว',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _TypingDot(delay: i * 200)),
        ),
      ),
    );
  }

  // ── Bubble ─────────────────────────────────────

  Widget _buildBubble(ChatMessage msg) {
    final isMe = msg.senderId == widget.currentUserId;
    final isPending = msg.status == MessageStatus.pending;
    final isFailed = msg.status == MessageStatus.failed;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Opacity(
          opacity: isPending ? 0.55 : 1.0,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isFailed
                      ? Colors.red[50]
                      : isMe
                          ? AppColors.ink
                          : AppColors.surface,
                  border: isMe
                      ? null
                      : Border.all(color: AppColors.border, width: 1.5),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isMe ? 14 : 2),
                    bottomRight: Radius.circular(isMe ? 2 : 14),
                  ),
                ),
                child: msg.type == 'image' && msg.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          msg.imageUrl!,
                          width: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 48),
                        ),
                      )
                    : Text(
                        msg.content ?? '',
                        style: AppTextStyles.bodyS.copyWith(
                          color: isFailed
                              ? Colors.red
                              : isMe
                                  ? Colors.white
                                  : AppColors.ink,
                        ),
                      ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textHint),
                  ),
                  if (isPending) ...[
                    const SizedBox(width: 4),
                    const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5)),
                    const SizedBox(width: 2),
                    Text('กำลังส่ง...',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint)),
                  ],
                  if (isFailed) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.error_outline, color: Colors.red, size: 13),
                    const SizedBox(width: 2),
                    Text('ส่งไม่สำเร็จ',
                        style: AppTextStyles.caption
                            .copyWith(color: Colors.red)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _retryMessage(msg),
                      child: Text(
                        'ส่งซ้ำ',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
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
      ),
    );
  }

  // ── Input bar ──────────────────────────────────

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            // Attach button
            GestureDetector(
              onTap: _handleAttachImage,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add,
                    color: AppColors.textMuted, size: 18),
              ),
            ),
            const SizedBox(width: 6),
            // Text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  textInputAction: TextInputAction.newline,
                  maxLines: null,
                  style:
                      AppTextStyles.bodyS.copyWith(color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'message…',
                    hintStyle: AppTextStyles.bodyS
                        .copyWith(color: AppColors.textHint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Send button
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_upward,
                    color: Colors.white, size: 18),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Center(
          child: Text('การสนทนานี้จบลงแล้ว',
              style:
                  AppTextStyles.bodyS.copyWith(color: AppColors.textMuted)),
        ),
      ),
    );
  }

  // ── Date helpers ───────────────────────────────

  String _weekdayName(int wd) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(wd - 1).clamp(0, 6)];
  }

  String _monthName(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[(m - 1).clamp(0, 11)];
  }
}

// ── Typing dot (animated) ──────────────────────────

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FadeTransition(
        opacity: _anim,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.textMuted,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── List item discriminated union ──────────────────

enum _ItemType { message, dateSeparator, readIndicator, typingIndicator }

class _ChatItem {
  final _ItemType type;
  final ChatMessage? message;
  final DateTime? date;

  const _ChatItem._({required this.type, this.message, this.date});

  factory _ChatItem.message(ChatMessage m) =>
      _ChatItem._(type: _ItemType.message, message: m);
  factory _ChatItem.dateSeparator(DateTime d) =>
      _ChatItem._(type: _ItemType.dateSeparator, date: d);
  factory _ChatItem.readIndicator() =>
      const _ChatItem._(type: _ItemType.readIndicator);
  factory _ChatItem.typingIndicator() =>
      const _ChatItem._(type: _ItemType.typingIndicator);
}
