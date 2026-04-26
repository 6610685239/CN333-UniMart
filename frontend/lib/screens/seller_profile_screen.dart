import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/review.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/review_service.dart';
import '../config.dart';
import '../shared/theme/app_colors.dart';
import 'chat_room_screen.dart';
import 'product_detail_screen.dart';

// ── Typography (mirrors my_shop_screen.dart) ──────────────────────────────────

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

TextStyle _mono({
  double size = 9,
  Color color = AppColors.textMuted,
  FontWeight weight = FontWeight.w500,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      letterSpacing: 0.4,
      color: color,
      fontWeight: weight,
    );

// ── Helpers ───────────────────────────────────────────────────────────────────

const _saleColor = Color(0xFF22C55E);
const _rentColor = AppColors.accent;

String _formatPrice(double price) {
  final str = price.toStringAsFixed(0);
  final buf = StringBuffer();
  final len = str.length;
  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buf.write(',');
    buf.write(str[i]);
  }
  return buf.toString();
}

String _conditionLabel(String condition) {
  final c = condition.toUpperCase();
  if (c.contains('NEW') || c.contains('หนึ่ง') || c == '1' ||
      c.contains('LIKE')) {
    return 'มือ 1';
  }
  return 'มือ 2';
}

// ── SellerProfileScreen ───────────────────────────────────────────────────────

class SellerProfileScreen extends StatefulWidget {
  final String sellerId;
  final String sellerName;
  final String currentUserId;

  const SellerProfileScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    required this.currentUserId,
  });

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isLoading = true;
  String? _avatarUrl;
  String _displayName = '';
  double _creditScore = 0.0;
  int _totalReviews = 0;
  List<Product> _products = [];      // AVAILABLE only — shown in listings tab
  List<Product> _allProducts = [];   // all statuses — used to get a productId for chat
  List<Review> _reviews = [];
  bool _chatLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _displayName = widget.sellerName; // show immediately before API responds
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await Future.wait([_loadProfile(), _loadCredit(), _loadProducts()]);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/auth/${widget.sellerId}/profile'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['user'] != null) {
          final user = data['user'];
          if (mounted) {
            setState(() {
              _displayName = user['display_name_th'] ??
                  user['display_name_en'] ??
                  user['username'] ??
                  widget.sellerName;
              final av = user['avatar'];
              if (av != null) {
                _avatarUrl = av.toString().startsWith('http')
                    ? av.toString()
                    : '${AppConfig.uploadsUrl}/$av';
              }
            });
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _displayName = widget.sellerName);
    }
  }

  Future<void> _loadCredit() async {
    try {
      final data = await ReviewService.getCreditScore(widget.sellerId);
      final reviews = await ReviewService.getUserReviews(widget.sellerId);
      if (mounted) {
        setState(() {
          _creditScore =
              (data['averageRating'] as num?)?.toDouble() ?? 0.0;
          _totalReviews = data['totalReviews'] as int? ?? 0;
          _reviews = reviews;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    try {
      final result = await ApiService().getMyProducts(widget.sellerId);
      if (mounted) {
        setState(() {
          _allProducts = result;
          _products = result.where((p) => p.status == 'AVAILABLE').toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _openChat() async {
    if (_chatLoading) return;
    if (_allProducts.isEmpty) return;
    setState(() => _chatLoading = true);

    // Use any product (any status) — backend requires a valid productId
    final productId = _allProducts.first.id;

    final result = await ChatService.createOrOpenRoom(
      widget.currentUserId,
      widget.sellerId,
      productId,
    );

    if (!mounted) return;
    setState(() => _chatLoading = false);

    if (result['id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId: result['id'],
            currentUserId: widget.currentUserId,
            otherUserName: _displayName.isNotEmpty
                ? _displayName
                : widget.sellerName,
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name =
        _displayName.isNotEmpty ? _displayName : widget.sellerName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.ink))
                  : NestedScrollView(
                      headerSliverBuilder: (_, __) => [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              _buildProfileHero(name, initial),
                              const SizedBox(height: 14),
                              _buildTabBar(),
                            ],
                          ),
                        ),
                      ],
                      body: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildListingsTab(bottomPad),
                          _buildReviewsTab(bottomPad),
                          _buildAboutTab(name, bottomPad),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(left: 8),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Shop',
              style: GoogleFonts.sriracha(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile hero ───────────────────────────────────────────────────────────

  Widget _buildProfileHero(String name, String initial) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentSoft,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: _avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: _avatarUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _avatarInitial(initial),
                  )
                : _avatarInitial(initial),
          ),
          const SizedBox(height: 8),
          // Name
          Text(name,
              style: _jak(size: 18, weight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '★ ${_creditScore.toStringAsFixed(1)}',
                style: _mono(
                    size: 11,
                    color: AppColors.ink,
                    weight: FontWeight.w700),
              ),
              _dot(),
              Text(
                '$_totalReviews deals',
                style: _mono(size: 11, color: AppColors.textMuted),
              ),
              _dot(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 13, color: Color(0xFF4A90D9)),
                  const SizedBox(width: 3),
                  Text(
                    'TU verified',
                    style: _mono(
                        size: 10,
                        color: AppColors.textMuted,
                        weight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Message button — only shown when there's a valid product to link chat to
          if (_allProducts.isNotEmpty) GestureDetector(
            onTap: _openChat,
            child: Container(
              height: 34,
              width: 140,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(20),
                color: AppColors.surface,
              ),
              child: _chatLoading
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.ink),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 14, color: AppColors.ink),
                        const SizedBox(width: 6),
                        Text('Message',
                            style: _jak(
                                size: 13, weight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarInitial(String initial) {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('·',
            style: _mono(size: 11, color: AppColors.textMuted)),
      );

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      'Listings (${_products.length})',
      'Reviews ($_totalReviews)',
      'About',
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        labelPadding: const EdgeInsets.only(right: 4),
        indicatorColor: AppColors.ink,
        indicatorWeight: 2,
        dividerColor: Colors.transparent,
        labelStyle: _jak(size: 13, weight: FontWeight.w700),
        unselectedLabelStyle: _jak(
            size: 13,
            weight: FontWeight.w500,
            color: AppColors.textMuted),
        tabs: tabs
            .map((t) => Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(t),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Listings tab ───────────────────────────────────────────────────────────

  Widget _buildListingsTab(double bottomPad) {
    if (_products.isEmpty) {
      return _emptyState('No listings yet.', bottomPad);
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.ink,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + bottomPad),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 160 / 230,
        ),
        itemCount: _products.length,
        itemBuilder: (_, i) => _productCard(_products[i]),
      ),
    );
  }

  // ── Reviews tab ────────────────────────────────────────────────────────────

  Widget _buildReviewsTab(double bottomPad) {
    if (_reviews.isEmpty) {
      return _emptyState('No reviews yet.', bottomPad);
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + bottomPad),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _reviewCard(_reviews[i]),
    );
  }

  Widget _reviewCard(Review review) {
    final initial = (review.reviewerName?.isNotEmpty == true)
        ? review.reviewerName![0].toUpperCase()
        : '?';
    return Container(
      padding: const EdgeInsets.all(12),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentSoft,
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(initial,
                      style: _jak(size: 13, weight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.reviewerName ?? 'Anonymous',
                  style: _jak(size: 13, weight: FontWeight.w700),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 13,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              '"${review.comment}"',
              style:
                  _jak(size: 12, color: AppColors.textMuted, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  // ── About tab ──────────────────────────────────────────────────────────────

  Widget _buildAboutTab(String name, double bottomPad) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seller Info',
              style: _jak(size: 14, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          _infoRow('Seller', name),
          _infoRow('Listings', _products.length.toString()),
          _infoRow(
              'Rating',
              _creditScore > 0
                  ? '${_creditScore.toStringAsFixed(1)} / 5.0'
                  : 'No reviews yet'),
          _infoRow('Total reviews', _totalReviews.toString()),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: _jak(size: 13, color: AppColors.textMuted)),
          Text(value,
              style: _jak(size: 13, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Product card (trending style) ──────────────────────────────────────────

  Widget _productCard(Product product) {
    final priceText = (product.type == 'RENT' && product.rentPrice > 0)
        ? 'เช่า ฿${_formatPrice(product.rentPrice)}'
        : (product.type == 'RENT' && product.price > 0)
            ? 'เช่า ฿${_formatPrice(product.price)}'
            : '฿${_formatPrice(product.price)}';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: product,
            currentUserId: widget.currentUserId,
          ),
        ),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ────────────────────────────────────────────────
            Expanded(
              flex: 13,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _imageContent(product),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _categoryBadge(product.categoryName),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _typeBadge(product.type),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _conditionBadge(product.condition),
                  ),
                ],
              ),
            ),
            // ── Info ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _jak(size: 12, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _jak(size: 10, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        priceText,
                        style: _jak(size: 13, weight: FontWeight.w800),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.favorite_border,
                              size: 14, color: Color(0xFFF48FB1)),
                          const SizedBox(width: 3),
                          Text(
                            '${product.favouritesCount}',
                            style: _mono(
                                size: 9,
                                color: AppColors.textMuted,
                                weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Badges ─────────────────────────────────────────────────────────────────

  Widget _typeBadge(String type) {
    final isRent = type == 'RENT';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isRent ? 'RENT' : 'SALE',
        style: _mono(
          size: 8,
          color: isRent ? _rentColor : _saleColor,
          weight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _categoryBadge(String name) {
    if (name.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style:
            _mono(size: 8, color: AppColors.ink, weight: FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _conditionBadge(String condition) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _conditionLabel(condition),
        style: _mono(size: 8, color: Colors.white, weight: FontWeight.w700),
      ),
    );
  }

  // ── Image content ──────────────────────────────────────────────────────────

  Widget _imageContent(Product product) {
    if (product.images.isEmpty) {
      return Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 40, color: Colors.grey.shade300),
      );
    }
    final imgPath = product.images.first;
    final url = imgPath.startsWith('http')
        ? imgPath
        : '${AppConfig.uploadsUrl}/$imgPath';
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (_, __) => Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 40, color: Colors.grey.shade300),
      ),
      errorWidget: (_, __, ___) => Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 40, color: Colors.grey.shade300),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _emptyState(String message, double bottomPad) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('○',
                style: GoogleFonts.sriracha(
                    fontSize: 36, color: AppColors.textHint)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  _jak(size: 14, color: AppColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
