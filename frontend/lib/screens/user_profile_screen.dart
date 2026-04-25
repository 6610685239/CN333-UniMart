import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../pages/favourite_manager.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/review_service.dart';
import '../services/transaction_service.dart';
import '../config.dart';
import '../shared/theme/app_colors.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'my_shop_screen.dart';
import 'notification_screen.dart';
import 'transaction_list_screen.dart';

// ── Typography ─────────────────────────────────────────────────────────────────
// Plus Jakarta Sans — body text, labels, names, menu rows, tile numbers
// JetBrains Mono   — eyebrows (CREDIT SCORE, ACCOUNT), student ID, footer, captions
// Sriracha         — display numbers (stat strip, donut score)

TextStyle _jak({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double letterSpacing = 0,
}) =>
    TextStyle(
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      fontFamilyFallback: const ['NotoSansThai'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

TextStyle _mono({
  double size = 9,
  Color color = AppColors.textMuted,
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0.4,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: weight,
    );

// ── Donut gauge ───────────────────────────────────────────────────────────────

class _DonutGaugePainter extends CustomPainter {
  final double score;
  _DonutGaugePainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 8.0;
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (score > 0) {
      final sweepAngle = (score / 5.0) * 2 * pi * 0.96;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutGaugePainter old) => old.score != score;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? displayName;
  final String? faculty;
  final String? tuStatus;
  final int unreadNotificationCount;
  final String? joinedAt;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.displayName,
    this.faculty,
    this.tuStatus,
    this.unreadNotificationCount = 0,
    this.joinedAt,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  double _creditScore = 0.0;
  int _totalReviews = 0;
  String? _avatarUrl;
  // local preview (real-time) – set immediately after picking
  XFile? _localAvatarFile;
  Uint8List? _localAvatarBytes; // used on web
  bool _avatarUploading = false;
  int _sellingCount = 0;
  int _activeOrderCount = 0;
  int _historyCount = 0;
  bool _statsLoading = true;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadAll();
    FavouriteManager.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    FavouriteManager.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadCredit(), _loadAvatarAndUser(), _loadStats()]);
  }

  Future<void> _loadCredit() async {
    try {
      final data = await ReviewService.getCreditScore(widget.userId);
      if (mounted) {
        setState(() {
          _creditScore = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
          _totalReviews = data['totalReviews'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAvatarAndUser() async {
    try {
      final user = await AuthService.getUser();
      if (user != null && mounted) {
        setState(() {
          final av = user['avatar'];
          if (av != null) {
            // Full URL (Supabase) — use directly; legacy filename — prepend uploads base
            _avatarUrl = av.toString().startsWith('http')
                ? av.toString()
                : '${AppConfig.uploadsUrl}/$av';
          }
          _username = user['username'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final results = await Future.wait([
        ApiService().getMyProducts(widget.userId).catchError((_) => <dynamic>[]),
        TransactionService.getUserTransactions(widget.userId)
            .catchError((_) => <String, dynamic>{}),
      ]);

      final products = results[0] as List;
      final txMap = results[1] as Map<String, dynamic>;
      final active = ((txMap['processing'] as List? ?? []).length +
          (txMap['shipping'] as List? ?? []).length);
      final history = (txMap['history'] as List? ?? []).length;

      if (mounted) {
        setState(() {
          _sellingCount = products.length;
          _activeOrderCount = active;
          _historyCount = history;
          _statsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    // ── Show local preview immediately (real-time) ──
    if (mounted) {
      setState(() {
        _localAvatarFile = picked;
        if (kIsWeb) _localAvatarBytes = bytes;
        _avatarUploading = true;
      });
    }

    try {
      // Determine MIME type from file extension
      final ext = picked.name.split('.').last.toLowerCase();
      final mimeType = const {
        'jpg': 'jpeg', 'jpeg': 'jpeg',
        'png': 'png', 'gif': 'gif', 'webp': 'webp',
      }[ext] ?? 'jpeg';

      final request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConfig.baseUrl}/auth/${widget.userId}/avatar'));
      request.files.add(http.MultipartFile.fromBytes(
          'avatar', bytes,
          filename: picked.name,
          contentType: MediaType('image', mimeType)));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final newAvatar = data['avatar'];
        final user = await AuthService.getUser();
        if (user != null) {
          user['avatar'] = newAvatar;
          await AuthService.saveUser(user);
        }
        if (mounted) {
          setState(() {
            // Server now returns a full Supabase public URL — use directly
            _avatarUrl = newAvatar;
            _avatarUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('อัปเดตรูปโปรไฟล์แล้ว'),
            backgroundColor: Colors.green,
          ));
        }
      } else {
        if (mounted) {
          setState(() {
            // Revert preview on failure
            _localAvatarFile = null;
            _localAvatarBytes = null;
            _avatarUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('อัปโหลดไม่สำเร็จ กรุณาลองใหม่'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localAvatarFile = null;
          _localAvatarBytes = null;
          _avatarUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _goEditProfile() async {
    final user = await AuthService.getUser();
    if (user == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Log out?', style: _jak(size: 18, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Are you sure you want to log out?',
                  style: _jak(size: 13, color: AppColors.textMuted)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Text('Cancel',
                            style: _jak(size: 14, weight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Log Out',
                            style: _jak(
                                size: 14,
                                weight: FontWeight.w700,
                                color: AppColors.surface)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName?.isNotEmpty == true
        ? widget.displayName!
        : 'ไม่ระบุชื่อ';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final savedCount = FavouriteManager.instance.favouritedProducts.length;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(name, initial, savedCount),
            _buildCreditCard(),
            _buildActionTiles(),
            const SizedBox(height: 14),
            _buildAccountMenu(),
            _buildLogOut(),
            _buildFooter(),
            SizedBox(height: 72 + bottomPad),
          ],
        ),
      ),
    );
  }

  // ── Zone 1 · Hero ──────────────────────────────────────────────────────────

  Widget _buildHero(String name, String initial, int savedCount) {
    final sub = _subLine();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Settings button — top right
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 10, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _goEditProfile,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(
                          color: const Color(0x402A2A2A), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.settings_outlined,
                        size: 15, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),

          // Avatar — 80×80, accent fill, white ring + ink outer via shadow
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _avatarUploading ? null : _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.white,
                        spreadRadius: 3,
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0xFF2A2A2A),
                        spreadRadius: 4,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildAvatarContent(initial),
                  ),
                ),
                if (_avatarUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black26,
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                if (!_avatarUploading)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          // Name
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              name,
              style: _jak(
                  size: 20,
                  weight: FontWeight.w700,
                  letterSpacing: -0.4),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Sub: faculty · Year N
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              sub,
              style: _jak(size: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],

          // Badge row: TU verified icon + student ID
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_rounded,
                  size: 13, color: Color(0xFF4A90D9)),
              const SizedBox(width: 3),
              Text(
                'TU verified',
                style: _mono(size: 10, color: AppColors.textMuted, weight: FontWeight.w600),
              ),
              if (_username != null && _username!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  _username!,
                  style: _mono(size: 10, color: AppColors.textMuted),
                ),
              ],
            ],
          ),

          // Stat strip
          const SizedBox(height: 14),
          _buildStatStrip(savedCount),
        ],
      ),
    );
  }

  Widget _buildStatStrip(int savedCount) {
    final stats = [
      (_statsLoading ? '—' : '$_sellingCount', 'Listings'),
      (_statsLoading ? '—' : '$_activeOrderCount', 'Orders'),
      ('$savedCount', 'Saved'),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) Container(width: 1, height: 56, color: AppColors.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      stats[i].$1,
                      style: GoogleFonts.sriracha(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats[i].$2,
                      style: _mono(size: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _subLine() {
    if (widget.faculty?.isNotEmpty == true) return widget.faculty!;
    return '';
  }

  /// Builds the inner content of the avatar circle.
  /// Priority: local file (real-time) → remote URL → initial letter
  Widget _buildAvatarContent(String initial) {
    // 1. Local file picked from gallery (real-time preview)
    if (_localAvatarFile != null) {
      if (kIsWeb && _localAvatarBytes != null) {
        return Image.memory(_localAvatarBytes!, fit: BoxFit.cover,
            width: 80, height: 80);
      } else if (!kIsWeb) {
        return Image.file(File(_localAvatarFile!.path), fit: BoxFit.cover,
            width: 80, height: 80);
      }
    }
    // 2. Remote URL (already uploaded)
    if (_avatarUrl != null) {
      return Image.network(
        _avatarUrl!,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        errorBuilder: (_, __, ___) => _avatarInitial(initial),
      );
    }
    // 3. Fallback: initial letter
    return _avatarInitial(initial);
  }

  Widget _avatarInitial(String initial) {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.sriracha(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          height: 1.0,
        ),
      ),
    );
  }

  // ── Zone 2 · Credit score card ─────────────────────────────────────────────

  Widget _buildCreditCard() {
    final score = _creditScore;
    final reviews = _totalReviews;
    final total = reviews.clamp(1, 30);
    final filled = reviews == 0
        ? 0
        : ((score / 5.0) * total).round().clamp(0, total);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Top half — donut + text block
          Container(
            decoration: const BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _donutGauge(score),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CREDIT SCORE',
                        style: _mono(
                            size: 10,
                            color: AppColors.textMuted,
                            letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _scoreLabel(score),
                        style: _jak(size: 15, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reviews > 0
                            ? 'Top ${_topPercent(score)}% at Thammasat'
                            : 'No reviews yet',
                        style: _jak(
                          size: 11,
                          weight: FontWeight.w600,
                          color: reviews > 0
                              ? const Color(0xFFB8860B)
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),
          // Bottom half — segment bar + caption
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    total,
                    (i) => Expanded(
                      child: Container(
                        margin:
                            EdgeInsets.only(right: i < total - 1 ? 2 : 0),
                        height: 5,
                        decoration: BoxDecoration(
                          color: i < filled
                              ? AppColors.ink
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Based on $reviews completed deals',
                  style: _mono(size: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _donutGauge(double score) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(64, 64),
            painter: _DonutGaugePainter(score),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                score.toStringAsFixed(1),
                style: GoogleFonts.sriracha(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.1,
                ),
              ),
              Text('/5.0', style: _mono(size: 8)),
            ],
          ),
        ],
      ),
    );
  }

  String _scoreLabel(double score) {
    if (score == 0) return 'No reviews yet';
    if (score >= 4.5) return 'Excellent seller';
    if (score >= 4.0) return 'Great seller';
    if (score >= 3.0) return 'Good seller';
    return 'New seller';
  }

  int _topPercent(double score) {
    if (score >= 4.8) return 5;
    if (score >= 4.5) return 12;
    if (score >= 4.0) return 25;
    if (score >= 3.5) return 40;
    return 60;
  }

  // ── Zone 3 · Content body ──────────────────────────────────────────────────

  Widget _buildActionTiles() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // My Shop tile — accent-soft fill
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyShopScreen(currentUserId: widget.userId)),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('My Shop',
                              style: _jak(size: 11, color: AppColors.textMuted)),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: AppColors.textHint),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statsLoading ? '— listings' : '$_sellingCount listings',
                      style: _jak(size: 16, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Orders tile — white fill
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        TransactionListScreen(userId: widget.userId)),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Orders',
                              style: _jak(size: 11, color: AppColors.textMuted)),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: AppColors.textHint),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statsLoading
                          ? '— active'
                          : '$_activeOrderCount active',
                      style: _jak(size: 16, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountMenu() {
    final unread = widget.unreadNotificationCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACCOUNT',
            style: _mono(
                size: 10, color: AppColors.textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: [
                _menuRow(
                  title: 'Reviews',
                  sub: _totalReviews > 0
                      ? '$_totalReviews reviews · avg ★ ${_creditScore.toStringAsFixed(1)}'
                      : 'No reviews yet',
                  onTap: null,
                ),
                _menuDivider(),
                _menuRow(
                  title: 'Notifications',
                  sub: unread > 0 ? '$unread unread' : 'All caught up',
                  badge: unread > 0 ? unread : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            NotificationScreen(userId: widget.userId)),
                  ),
                ),
                _menuDivider(),
                _menuRow(
                  title: 'Change password',
                  sub: null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ChangePasswordScreen(userId: widget.userId)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuRow({
    required String title,
    String? sub,
    int? badge,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _jak(size: 14, weight: FontWeight.w600)),
                  if (sub != null) ...[
                    const SizedBox(height: 1),
                    Text(sub,
                        style: _jak(size: 11, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: _jak(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (onTap != null)
              Text('›',
                  style: _jak(size: 18, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _menuDivider() =>
      Container(height: 1, color: AppColors.divider);

  Widget _buildLogOut() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GestureDetector(
        onTap: _logout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Text(
            'Log out',
            style: _jak(
                size: 14,
                weight: FontWeight.w600,
                color: const Color(0xFFE53E3E)),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr = '${months[now.month - 1]} ${now.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Center(
        child: Text(
          'CN333 · UniMart v1.0 · $dateStr',
          style: _mono(size: 10, color: AppColors.textHint),
        ),
      ),
    );
  }
}
