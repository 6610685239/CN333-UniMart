import 'dart:convert';
import 'dart:ui' show FontFeature;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../pages/favourite_manager.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/transaction_service.dart';
import '../services/review_service.dart';
import '../config.dart';
import '../shared/theme/app_colors.dart';
import 'edit_product_screen.dart';
import 'chat_room_screen.dart';
import 'seller_profile_screen.dart';

// ── Typography (WF.sans = Sriracha, WF.mono = JetBrains Mono) ─────────────────
// Plus Jakarta Sans (Latin) + NotoSansThai fallback — used for name/price/desc
TextStyle _jak({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double? height,
}) =>
    TextStyle(
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      fontFamilyFallback: const ['NotoSansThai'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

TextStyle _s({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double? height,
}) =>
    GoogleFonts.sriracha(
        fontSize: size, fontWeight: weight, color: color, height: height);

TextStyle _m({
  double size = 10,
  Color color = AppColors.textMuted,
  FontWeight weight = FontWeight.w500,
}) =>
    GoogleFonts.jetBrainsMono(
        fontSize: size, letterSpacing: 0.4, color: color, fontWeight: weight);

// ── Price formatter ────────────────────────────────────────────────────────────
String _fmtPrice(double price) {
  final str = price.toStringAsFixed(0);
  final buf = StringBuffer();
  final len = str.length;
  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buf.write(',');
    buf.write(str[i]);
  }
  return buf.toString();
}

// ── Condition label ────────────────────────────────────────────────────────────
String _conditionDisplay(String c) {
  switch (c.toUpperCase()) {
    case 'NEW':
      return 'New';
    case 'LIKE_NEW':
      return 'Like new';
    case 'GOOD':
      return 'Good';
    case 'FAIR':
      return 'Fair';
    case 'POOR':
      return 'Poor';
    default:
      return c;
  }
}

const _stroke = Color(0xFF2a2a2a);

// ── Dashed border painter ──────────────────────────────────────────────────────
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final double radius;

  const _DashedBorderPainter({
    this.color = _stroke,
    this.strokeWidth = 1.5,
    this.dash = 6,
    this.gap = 4,
    this.radius = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
          size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final m in path.computeMetrics()) {
      double dist = 0;
      bool draw = true;
      while (dist < m.length) {
        final seg = draw ? dash : gap;
        if (draw) canvas.drawPath(m.extractPath(dist, dist + seg), paint);
        dist += seg;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter o) => false;
}

// ─────────────────────────────────────────────────────────────────────────────

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String currentUserId;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.currentUserId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product _product;
  final ApiService _api = ApiService();
  int _currentImageIndex = 0;

  double _sellerRating = 0;
  int _sellerDeals = 0;
  String? _sellerAvatarUrl;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    FavouriteManager.instance.addListener(_refresh);
    _loadSellerStats();
    _loadSellerAvatar();
  }

  Future<void> _loadSellerStats() async {
    try {
      final data = await ReviewService.getCreditScore(_product.ownerId);
      if (mounted) {
        setState(() {
          _sellerRating = (data['averageRating'] as num?)?.toDouble() ?? 0;
          _sellerDeals = (data['totalReviews'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSellerAvatar() async {
    if (_product.ownerId.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/auth/${_product.ownerId}/profile'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final av = data['user']?['avatar'];
        if (av != null && mounted) {
          setState(() {
            _sellerAvatarUrl = av.toString().startsWith('http')
                ? av.toString()
                : '${AppConfig.uploadsUrl}/$av';
          });
        }
      }
    } catch (_) {}
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FavouriteManager.instance.removeListener(_refresh);
    super.dispose();
  }

  bool get isOwner => _product.ownerId == widget.currentUserId;

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _updateStatus(String newStatus) async {
    final success = await _api.updateStatus(_product.id, newStatus);
    if (success) {
      setState(() {
        _product = Product(
          id: _product.id,
          title: _product.title,
          description: _product.description,
          price: _product.price,
          status: newStatus,
          condition: _product.condition,
          images: _product.images,
          categoryName: _product.categoryName,
          location: _product.location,
          ownerId: _product.ownerId,
          ownerName: _product.ownerName,
          type: _product.type,
          rentPrice: _product.rentPrice,
          favouritesCount: _product.favouritesCount,
          createdAt: _product.createdAt,
          quantity: _product.quantity,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('อัปเดตสถานะแล้ว')));
      }
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProductScreen(product: _product)),
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete listing',
                style: GoogleFonts.sriracha(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '"${_product.title}" will be permanently removed and cannot be recovered.',
                style: _jak(size: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.border, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text('Cancel',
                            style: _jak(
                                size: 14,
                                color: AppColors.textMuted)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Delete',
                          style: _jak(
                              size: 14,
                              weight: FontWeight.w700,
                              color: Colors.white),
                        ),
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
    if (confirm == true) {
      final success = await _api.deleteProduct(_product.id);
      if (success && mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _buyOrRent() async {
    final type = _product.type == 'RENT' ? 'RENT' : 'SALE';
    final label = _product.type == 'RENT' ? 'เช่า' : 'ซื้อ';
    final confirm = await showDialog<bool>(
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
              Text(
                'ยืนยันการ$label',
                style: GoogleFonts.sriracha(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'คุณต้องการ$labelสินค้า\n"${_product.title}" ใช่หรือไม่?',
                style: _jak(size: 13, color: AppColors.textMuted),
              ),
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
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Text('ยกเลิก',
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
                        child: Text(
                          'ยืนยัน$label',
                          style: _jak(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.surface),
                        ),
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
    if (confirm != true) return;
    final result = await TransactionService.createTransaction(
        widget.currentUserId, _product.id, type);
    if (!mounted) return;
    final ok = result['success'] != false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'สร้างรายการ${label}สำเร็จ รอผู้ขายยืนยัน'
          : (result['message'] ?? 'ไม่สามารถสร้างธุรกรรมได้')),
      backgroundColor: ok ? AppColors.success : Colors.red,
    ));
    if (ok) {
      // Update local product state to reflect purchase
      final newQty = _product.quantity - 1;
      final newStatus =
          (newQty <= 0 && _product.type == 'SALE') ? 'RESERVED' : _product.status;
      setState(() {
        _product = Product(
          id: _product.id,
          title: _product.title,
          description: _product.description,
          price: _product.price,
          status: newStatus,
          condition: _product.condition,
          images: _product.images,
          categoryName: _product.categoryName,
          location: _product.location,
          ownerId: _product.ownerId,
          ownerName: _product.ownerName,
          type: _product.type,
          rentPrice: _product.rentPrice,
          favouritesCount: _product.favouritesCount,
          createdAt: _product.createdAt,
          quantity: newQty < 0 ? 0 : newQty,
        );
      });
    }
  }

  Future<void> _openChat() async {
    final result = await ChatService.createOrOpenRoom(
        widget.currentUserId, _product.ownerId, _product.id);
    if (!mounted) return;
    if (result['id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId: result['id'],
            currentUserId: widget.currentUserId,
            otherUserName: _product.ownerName,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'ไม่สามารถเปิดแชทได้'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  Color _statusColor(String s) {
    switch (s) {
      case 'RESERVED':
        return Colors.orange;
      case 'SOLD':
        return Colors.red;
      default:
        return AppColors.success;
    }
  }

  String _statusText(String s) {
    if (_product.type == 'RENT') {
      return s == 'AVAILABLE' ? 'ว่าง' : 'ถูกเช่า';
    }
    switch (s) {
      case 'RESERVED':
        return 'ติดจอง';
      case 'SOLD':
        return 'ขายแล้ว';
      default:
        return 'ว่าง';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fav = FavouriteManager.instance;
    final idStr = _product.id.toString();
    final isLiked = fav.isFavourited(idStr);
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageHero(topPad, isLiked, fav, idStr),
                _buildInfoSection(bottomPad),
              ],
            ),
          ),
          // Back button — always visible while scrolling
          Positioned(
            top: topPad + 12,
            left: 12,
            child: _circleBtn(
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.ink),
              onTap: () => Navigator.pop(context),
            ),
          ),
          // Right buttons — always visible while scrolling (owner only)
          if (isOwner)
            Positioned(
              top: topPad + 12,
              right: 12,
              child: Row(
                children: [
                  _circleBtn(
                    child: const Icon(Icons.edit_outlined,
                        size: 16, color: AppColors.ink),
                    onTap: _navigateToEdit,
                  ),
                  const SizedBox(width: 6),
                  _circleBtn(
                    child: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    onTap: _deleteProduct,
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar:
          isOwner ? null : _buildBottomBar(bottomPad),
    );
  }

  // ── Image hero ────────────────────────────────────────────────────────────

  Widget _buildImageHero(
      double topPad, bool isLiked, FavouriteManager fav, String idStr) {
    final heroHeight = 280.0 + topPad;
    return SizedBox(
      height: heroHeight,
      child: Stack(
        children: [
          // Image area
          Positioned.fill(
            child: Container(
              color: AppColors.surface,
              foregroundDecoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _stroke, width: 1.5),
                ),
              ),
              child: _product.images.isNotEmpty
                  ? PageView.builder(
                      itemCount: _product.images.length,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                      itemBuilder: (_, i) {
                        final img = _product.images[i];
                        final url = img.startsWith('http')
                            ? img
                            : '${AppConfig.uploadsUrl}/$img';
                        return GestureDetector(
                          onTap: () => _openFullImage(url),
                          child: Image.network(url, fit: BoxFit.contain),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          size: 64, color: AppColors.textHint),
                    ),
            ),
          ),

          // Dots
          if (_product.images.length > 1)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_product.images.length, (i) {
                  final active = _currentImageIndex == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 16 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.ink
                          : AppColors.ink.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

          // Heart button — top-right (non-owner only)
          if (!isOwner)
            Positioned(
              top: topPad + 12,
              right: 12,
              child: _circleBtn(
                child: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: isLiked ? const Color(0xFFF48FB1) : AppColors.ink,
                ),
                onTap: () =>
                    setState(() => fav.toggle(idStr, product: _product)),
              ),
            ),
        ],
      ),
    );
  }

  void _openFullImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleBtn({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: _stroke, width: 1.5),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  // ── Info section ──────────────────────────────────────────────────────────

  Widget _buildInfoSection(double bottomPad) {
    final isRent = _product.type == 'RENT';

    final priceText = (isRent && _product.price == 0 && _product.rentPrice == 0)
        ? '฿0'
        : isRent
            ? '฿${_fmtPrice(_product.rentPrice)}'
            : '฿${_fmtPrice(_product.price)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Badge row ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isRent ? 'FOR RENT' : 'FOR SALE',
                  style: _s(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_product.categoryName} · ${_conditionDisplay(_product.condition)}',
                style: _m(size: 10, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Title ──────────────────────────────────────────────────────
          Text(
            _product.title,
            style: _jak(size: 22, weight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 8),

          // ── Price row ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(priceText,
                  style: _jak(
                      size: 26,
                      weight: FontWeight.w900,
                      color: AppColors.ink).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              if (isRent && _product.rentPrice > 0) ...[
                const SizedBox(width: 4),
                Text('/วัน',
                    style: _s(
                        size: 14,
                        color: AppColors.textMuted)),
              ],
              const Spacer(),
              if (!isRent && _product.quantity > 0)
                Text(
                  '${_product.quantity} in stock',
                  style: _m(size: 10, color: AppColors.textMuted),
                )
              else if (!isRent && _product.quantity <= 0)
                Text('สินค้าหมด',
                    style: _m(
                        size: 10,
                        color: Colors.red,
                        weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Seller card ────────────────────────────────────────────────
          _buildSellerCard(),
          const SizedBox(height: 16),

          // ── Status + Condition tiles ────────────────────────────────────
          _buildInfoTiles(),
          const SizedBox(height: 16),

          // ── Description ────────────────────────────────────────────────
          Text('Description',
              style: _m(
                  size: 9,
                  color: AppColors.textMuted,
                  weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            _product.description.isNotEmpty ? _product.description : '—',
            style: _jak(
                size: 14,
                color: AppColors.ink,
                height: 1.6),
          ),
          const SizedBox(height: 16),

          // ── Meeting point ──────────────────────────────────────────────
          if (_product.location.isNotEmpty) ...[
            _buildMeetingPoint(),
            const SizedBox(height: 16),
          ],

          SizedBox(height: 24 + bottomPad),
        ],
      ),
    );
  }

  Widget _buildSellerCard() {
    final initial = _product.ownerName.isNotEmpty
        ? _product.ownerName[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: isOwner
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SellerProfileScreen(
                    sellerId: _product.ownerId,
                    sellerName: _product.ownerName,
                    currentUserId: widget.currentUserId,
                  ),
                ),
              ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: _stroke, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: _stroke, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: _sellerAvatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: _sellerAvatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(initial,
                            style: _jak(
                                size: 16, weight: FontWeight.w700)),
                      ),
                    )
                  : Center(
                      child: Text(initial,
                          style: _jak(size: 16, weight: FontWeight.w700)),
                    ),
            ),
            const SizedBox(width: 10),
            // Name + stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _product.ownerName,
                    style: _jak(size: 14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 12, color: AppColors.accent),
                      const SizedBox(width: 3),
                      Text(
                        _sellerRating > 0
                            ? _sellerRating.toStringAsFixed(1)
                            : '—',
                        style: _m(size: 9, weight: FontWeight.w700,
                            color: AppColors.ink),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_sellerDeals} deals',
                        style: _m(size: 9, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // view shop arrow (non-owner only)
            if (!isOwner)
              Text('view shop →',
                  style: _m(size: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── Info rows (key-value with dividers) ──────────────────────────────────

  static const _pillGreenBg  = Color(0xFFEAF3DE);
  static const _pillGreenTxt = Color(0xFF3B6D11);
  static const _pillGreenDot = Color(0xFF3BAA74);
  static const _pillRedBg    = Color(0xFFFCEBEB);
  static const _pillRedTxt   = Color(0xFFA32D2D);
  static const _pillRedDot   = Color(0xFFE24B4A);
  static const _pillGrayBg   = Color(0xFFF1EFE8);
  static const _pillGrayTxt  = Color(0xFF5F5E5A);
  static const _pillBlueBg   = Color(0xFFE6F1FB);
  static const _pillBlueTxt  = Color(0xFF185FA5);

  Widget _buildInfoTiles() {
    final isAvailable = _product.status == 'AVAILABLE';
    final rows = <Widget>[];

    // Status
    rows.add(_infoRow(
      'Status',
      isOwner
          ? _ownerStatusPill()
          : _statusPill(isAvailable),
    ));

    rows.add(const Divider(height: 1, thickness: 0.5, color: AppColors.divider));

    // Condition
    rows.add(_infoRow(
      'Condition',
      _pill(
        _conditionDisplay(_product.condition),
        bg: _pillGrayBg,
        fg: _pillGrayTxt,
      ),
    ));

    rows.add(const Divider(height: 1, thickness: 0.5, color: AppColors.divider));

    // Category
    rows.add(_infoRow(
      'Category',
      _pill(_product.categoryName, bg: _pillBlueBg, fg: _pillBlueTxt),
    ));

    rows.add(const Divider(height: 1, thickness: 0.5, color: AppColors.divider));

    // Stock
    final stockLabel = _product.type == 'RENT' ? 'Availability' : 'Stock';
    final stockText = _product.type == 'RENT'
        ? (isAvailable ? 'Available' : 'Rented')
        : (_product.quantity > 0
            ? '${_product.quantity} item${_product.quantity == 1 ? '' : 's'}'
            : 'Out of stock');
    rows.add(_infoRow(
      stockLabel,
      Text(
        stockText,
        style: _jak(size: 12, weight: FontWeight.w600),
      ),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _infoRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(label,
              style: _jak(size: 12, color: AppColors.textMuted)),
          const Spacer(),
          value,
        ],
      ),
    );
  }

  Widget _pill(String text,
      {required Color bg, required Color fg, Color? dot}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dot,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: _jak(
                  size: 12,
                  weight: FontWeight.w500,
                  color: fg)),
        ],
      ),
    );
  }

  Widget _statusPill(bool available) {
    return _pill(
      _statusText(_product.status),
      bg: available ? _pillGreenBg : _pillRedBg,
      fg: available ? _pillGreenTxt : _pillRedTxt,
      dot: available ? _pillGreenDot : _pillRedDot,
    );
  }

  Widget _ownerStatusPill() {
    final available = _product.status == 'AVAILABLE';
    final items = _product.type == 'RENT'
        ? const [
            DropdownMenuItem(value: 'AVAILABLE', child: Text('ว่าง')),
            DropdownMenuItem(value: 'RESERVED', child: Text('ถูกเช่า')),
          ]
        : const [
            DropdownMenuItem(value: 'AVAILABLE', child: Text('ว่าง')),
            DropdownMenuItem(value: 'RESERVED', child: Text('ติดจอง')),
            DropdownMenuItem(value: 'SOLD', child: Text('ขายแล้ว')),
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: available ? _pillGreenBg : _pillRedBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: available ? _pillGreenDot : _pillRedDot,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _product.status,
              isDense: true,
              style: _jak(
                size: 12,
                weight: FontWeight.w500,
                color: available ? _pillGreenTxt : _pillRedTxt,
              ),
              icon: Icon(Icons.arrow_drop_down,
                  size: 16,
                  color: available ? _pillGreenTxt : _pillRedTxt),
              dropdownColor: AppColors.surface,
              items: items,
              onChanged: (v) {
                if (v != null) _updateStatus(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingPoint() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.place_outlined, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text('MEETING POINT',
                style: _m(size: 8, color: AppColors.textMuted,
                    weight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        CustomPaint(
          foregroundPainter: const _DashedBorderPainter(
              radius: 10, color: AppColors.border),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.location_on_rounded,
                      size: 20, color: AppColors.textMuted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _product.location,
                    style: _jak(size: 13, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(double bottomPad) {
    final isRent = _product.type == 'RENT';
    final canBuy = _product.type == 'RENT'
        ? _product.status == 'AVAILABLE'
        : _product.quantity > 0 && _product.status != 'SOLD';

    final priceLabel = (isRent && _product.price == 0 && _product.rentPrice == 0)
        ? ''
        : isRent
            ? ' · ฿${_fmtPrice(_product.rentPrice)}'
            : ' · ฿${_fmtPrice(_product.price)}';

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(
            top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          // Chat — outline button
          GestureDetector(
            onTap: _openChat,
            child: Container(
              width: 96,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: _stroke, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: AppColors.ink),
                  const SizedBox(width: 5),
                  Text('Chat', style: _s(size: 14, weight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Buy/Rent — primary button
          Expanded(
            child: GestureDetector(
              onTap: canBuy ? _buyOrRent : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: canBuy ? AppColors.ink : AppColors.textHint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  canBuy
                      ? '${isRent ? 'Rent' : 'Buy'}$priceLabel'
                      : 'Unavailable',
                  style: _s(
                      size: 15,
                      weight: FontWeight.w700,
                      color: canBuy ? AppColors.surface : AppColors.surface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

