import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../models/chat_room.dart';
import '../services/chat_service.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String userId;

  const ChatListScreen({super.key, required this.userId});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatRoom> _rooms = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  IO.Socket? _socket;
  Timer? _pollTimer;
  final Set<String> _joinedRooms = {};

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
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Socket ─────────────────────────────────────

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

  // ── Data ───────────────────────────────────────

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

  // ── Helpers ────────────────────────────────────

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Y';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }

  List<ChatRoom> get _filteredRooms {
    if (_searchQuery.isEmpty) return List<ChatRoom>.from(_rooms);
    final q = _searchQuery.toLowerCase();
    return _rooms.where((r) {
      return r.otherUserName.toLowerCase().contains(q) ||
          r.productTitle.toLowerCase().contains(q) ||
          (r.lastMessage?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<ChatRoom> get _pinnedRooms =>
      _filteredRooms.where((r) => r.isPinned && !r.isLocked).toList();

  List<ChatRoom> get _activeRooms =>
      _filteredRooms.where((r) => !r.isPinned && !r.isLocked).toList();

  List<ChatRoom> get _endedRooms =>
      _filteredRooms.where((r) => r.isLocked).toList();


  // ── Build ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        'Chats',
        style: GoogleFonts.sriracha(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (_, __) => const _SkeletonChatTile(),
            ),
          ),
        ],
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!,
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _loadRooms,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('ลองใหม่',
                    style: AppTextStyles.body.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }

    final pinned = _pinnedRooms;
    final active = _activeRooms;
    final ended = _endedRooms;
    final hasAny = pinned.isNotEmpty || active.isNotEmpty || ended.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadRooms,
      color: AppColors.ink,
      child: CustomScrollView(
        slivers: [
          // ── Search ──
          SliverToBoxAdapter(child: _buildSearchBar()),

          // ── Empty state ──
          if (!hasAny)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 56, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    Text('ยังไม่มีการสนทนา',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),

          // ── Pinned section ──
          if (pinned.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionHeader('📌  Pinned')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildRoomTile(pinned[i]),
                childCount: pinned.length,
              ),
            ),
          ],

          // ── All chats section ──
          if (active.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                  pinned.isNotEmpty ? 'All Chats' : 'All Chats'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildRoomTile(active[i]),
                childCount: active.length,
              ),
            ),
          ],

          // ── Ended section ──
          if (ended.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionHeader('🔒  Ended')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildRoomTile(ended[i]),
                childCount: ended.length,
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SizedBox(
        height: 48,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: AppTextStyles.body.copyWith(color: AppColors.ink),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.bg,
            hintText: '⌕  Search chats',
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
            isDense: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textHint,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRoomTile(ChatRoom room) {
    final initial = room.otherUserName.isNotEmpty
        ? room.otherUserName[0].toUpperCase()
        : '?';

    return Dismissible(
      key: Key(room.id.toString()),
      direction: DismissDirection.horizontal,
      // ── Swipe right → pin / unpin ──────────────────────────────────
      background: Container(
        color: AppColors.accentSoft,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              room.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              color: AppColors.ink,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              room.isPinned ? 'Unpin' : 'Pin',
              style: TextStyle(
                fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
      // ── Swipe left → delete ─────────────────────────────────────────
      secondaryBackground: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Pin / unpin — don't dismiss the tile
          try {
            await ChatService.pinRoom(
                room.id.toString(), widget.userId, !room.isPinned);
            _loadRooms(silent: true);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not update pin')),
              );
            }
          }
          return false;
        } else {
          // Delete — dismiss the tile
          try {
            await ChatService.deleteRoom(room.id.toString(), widget.userId);
            _loadRooms(silent: true);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not delete chat')),
              );
            }
          }
          return true;
        }
      },
      child: InkWell(
        onTap: () async {
          ChatService.markAsRead(room.id.toString(), widget.userId);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                roomId: room.id,
                currentUserId: widget.userId,
                otherUserName: room.otherUserName,
                otherUserAvatar: room.otherUserAvatar,
                isLocked: room.isLocked,
                isPinned: room.isPinned,
              ),
            ),
          );
          _loadRooms();
        },
        onLongPress: () => _showRoomOptions(room),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Avatar ──
                  _buildAvatar(initial, room.isPinned, room.otherUserAvatar,
                      isLocked: room.isLocked),
                  const SizedBox(width: 12),
                  // ── Content ──
                  Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.otherUserName,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: room.isLocked
                                  ? AppColors.textMuted
                                  : AppColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(room.lastMessageTime),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textHint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Last message
                    Text(
                      room.lastMessageType == 'image'
                          ? '📷 รูปภาพ'
                          : room.lastMessage ?? 'ยังไม่มีข้อความ',
                      style: AppTextStyles.bodyS.copyWith(
                        color: room.unreadCount > 0
                            ? AppColors.ink
                            : AppColors.textMuted,
                        fontWeight: room.unreadCount > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Product context
                    Text(
                      '${room.productTitle} · ฿${room.productType == 'RENT' ? room.productRentPrice : room.productPrice}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // ── Unread badge ──
              if (room.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
                ],
              ),
            ),
            const _DashedDivider(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String initial, bool isPinned, String? avatarRaw,
      {bool isLocked = false}) {
    final avatarUrl = avatarRaw == null
        ? null
        : avatarRaw.startsWith('http')
            ? avatarRaw
            : '${AppConfig.uploadsUrl}/$avatarRaw';

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 44,
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
                          style: AppTextStyles.titleS
                              .copyWith(color: AppColors.ink)),
                    ),
                  )
                : Center(
                    child: Text(initial,
                        style:
                            AppTextStyles.titleS.copyWith(color: AppColors.ink)),
                  ),
          ),
          if (isLocked)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.textHint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    size: 10, color: Colors.white),
              ),
            )
          else if (isPinned)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.push_pin,
                    size: 10, color: AppColors.ink),
              ),
            ),
        ],
      ),
    );
  }

  void _showRoomOptions(ChatRoom room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Pin / unpin
            ListTile(
              leading: Icon(
                room.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                color: AppColors.ink,
                size: 20,
              ),
              title: Text(
                room.isPinned ? 'Unpin chat' : 'Pin chat',
                style: AppTextStyles.body.copyWith(color: AppColors.ink),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await ChatService.pinRoom(
                      room.id.toString(), widget.userId, !room.isPinned);
                  _loadRooms(silent: true);
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not update pin')),
                    );
                  }
                }
              },
            ),
            // Delete
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              title: Text(
                'Delete chat',
                style: AppTextStyles.body.copyWith(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await ChatService.deleteRoom(
                      room.id.toString(), widget.userId);
                  _loadRooms(silent: true);
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not delete chat')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton chat tile ────────────────────────────────────────────────────────

class _SkeletonChatTile extends StatefulWidget {
  const _SkeletonChatTile();

  @override
  State<_SkeletonChatTile> createState() => _SkeletonChatTileState();
}

class _SkeletonChatTileState extends State<_SkeletonChatTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _bone({double? width, double height = 12, double radius = 6}) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [
              Color(0xFFE8E6DF),
              Color(0xFFF5F3EE),
              Color(0xFFE8E6DF),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar circle
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment(_anim.value - 1, 0),
                      end: Alignment(_anim.value + 1, 0),
                      colors: const [
                        Color(0xFFE8E6DF),
                        Color(0xFFF5F3EE),
                        Color(0xFFE8E6DF),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Text lines
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _bone(height: 13)),
                        const SizedBox(width: 8),
                        _bone(width: 32, height: 10),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _bone(width: double.infinity, height: 11),
                    const SizedBox(height: 5),
                    _bone(width: 120, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
        const _DashedDivider(),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashW = 5.0;
          const dashG = 4.0;
          final count = (constraints.maxWidth / (dashW + dashG)).floor();
          return Row(
            children: List.generate(
              count,
              (_) => Container(
                width: dashW,
                height: 1,
                margin: const EdgeInsets.only(right: dashG),
                color: AppColors.divider,
              ),
            ),
          );
        },
      ),
    );
  }
}
