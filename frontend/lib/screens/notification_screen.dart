import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_notification.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/transaction_service.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import 'chat_room_screen.dart';
import 'transaction_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  final String userId;

  const NotificationScreen({super.key, required this.userId});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'All'; // All | Chat | Orders | Deals

  static const _filters = ['All', 'Chat', 'Orders', 'Deals'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final list = await NotificationService.getNotifications(widget.userId);
      if (mounted) setState(() { _notifications = list; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'โหลดแจ้งเตือนไม่สำเร็จ'; _isLoading = false; });
    }
  }

  Future<void> _markAllRead() async {
    for (final n in _notifications.where((n) => !n.isRead)) {
      await NotificationService.markAsRead(n.id);
    }
    if (mounted) {
      setState(() {
        _notifications = _notifications.map((n) => AppNotification(
          id: n.id, userId: n.userId, type: n.type,
          title: n.title, body: n.body, data: n.data,
          isRead: true, createdAt: n.createdAt,
        )).toList();
      });
    }
  }

  Future<void> _onTap(AppNotification n) async {
    // Mark as read
    if (!n.isRead) {
      await NotificationService.markAsRead(n.id);
      if (mounted) {
        setState(() {
          final i = _notifications.indexWhere((x) => x.id == n.id);
          if (i != -1) {
            _notifications[i] = AppNotification(
              id: n.id, userId: n.userId, type: n.type,
              title: n.title, body: n.body, data: n.data,
              isRead: true, createdAt: n.createdAt,
            );
          }
        });
      }
    }
    if (!mounted) return;

    if (n.type == 'chat_message' && n.data.containsKey('roomId')) {
      final roomId = n.data['roomId'].toString();
      final detail = await ChatService.getRoomDetail(roomId);
      if (!mounted) return;
      // Determine which user is "other" based on current userId
      final buyerId = detail['buyerId'] as String? ?? '';
      final isBuyer = widget.userId == buyerId;
      final otherData = (isBuyer ? detail['seller'] : detail['buyer'])
          as Map<String, dynamic>?;
      final otherUserName = otherData?['displayName'] as String? ??
          otherData?['username'] as String? ??
          'Unknown';
      final otherUserAvatar = otherData?['avatar'] as String?;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId: roomId,
            currentUserId: widget.userId,
            otherUserName: otherUserName,
            otherUserAvatar: otherUserAvatar,
          ),
        ),
      );
    } else if (n.type == 'transaction_update' && n.data.containsKey('transactionId')) {
      final txId = n.data['transactionId'].toString();
      final tx = await TransactionService.getTransactionById(txId);
      if (!mounted || tx == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(
            transaction: tx,
            currentUserId: widget.userId,
          ),
        ),
      );
    }
  }

  List<AppNotification> get _filtered {
    if (_filter == 'All') return _notifications;
    final typeMap = {
      'Chat': 'chat_message',
      'Orders': 'transaction_update',
      'Deals': 'review_received',
    };
    final t = typeMap[_filter];
    return _notifications.where((n) => n.type == t).toList();
  }

  String _emoji(String type) {
    switch (type) {
      case 'chat_message': return '💬';
      case 'transaction_update': return '🛒';
      case 'review_received': return '⭐';
      default: return '🔔';
    }
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${t.day}/${t.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
        title: Text(
          'Notifications',
          style: GoogleFonts.sriracha(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text(
              'Mark all',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: AppTextStyles.body.copyWith(
                              color: AppColors.textMuted)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _load,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('ลองใหม่',
                              style: AppTextStyles.body
                                  .copyWith(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // ── Filter chips ──
                    _buildFilterRow(),
                    // ── List ──
                    Expanded(child: _buildList()),
                  ],
                ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: _filters.map((f) {
          final active = f == _filter;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? AppColors.ink : Colors.transparent,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  f,
                  style: AppTextStyles.caption.copyWith(
                    color: active ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('ยังไม่มีแจ้งเตือน',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.ink,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => _buildItem(items[i], isLast: i == items.length - 1),
      ),
    );
  }

  Widget _buildItem(AppNotification n, {required bool isLast}) {
    return GestureDetector(
      onTap: () => _onTap(n),
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji circle
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(_emoji(n.type),
                        style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  // Text block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: AppTextStyles.bodyS.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(n.createdAt),
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textHint),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Body — Sriracha (main page font)
                        Text(
                          n.body,
                          style: GoogleFonts.sriracha(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Unread dot
                  if (!n.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Dashed bottom border
            if (!isLast)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 1,
                  child: CustomPaint(painter: _DashedLinePainter()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashGap = 4.0;
    final paint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter _) => false;
}
