import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'favourite_manager.dart';
import '../models/product.dart';
import '../config.dart';
import '../shared/theme/app_colors.dart';
import '../screens/product_detail_screen.dart';

// ── Typography (mirrors home_page.dart exactly) ───────────────────────────────

TextStyle _sans({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double? height,
}) =>
    GoogleFonts.sriracha(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

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

// ── Page ──────────────────────────────────────────────────────────────────────

class FavouritedPage extends StatefulWidget {
  final String currentUserId;
  final VoidCallback? onExplore;
  const FavouritedPage({super.key, required this.currentUserId, this.onExplore});

  @override
  State<FavouritedPage> createState() => _FavouritedPageState();
}

class _FavouritedPageState extends State<FavouritedPage> {
  String? _selectedCategory; // null = All

  @override
  void initState() {
    super.initState();
    FavouriteManager.instance.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FavouriteManager.instance.removeListener(_refresh);
    super.dispose();
  }

  void _openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  // ── Derived data ──────────────────────────────────────────────────────────

  List<Product> get _filtered {
    final all = FavouriteManager.instance.favouritedProducts;
    if (_selectedCategory == null) return all;
    return all
        .where((p) => p.categoryName == _selectedCategory)
        .toList();
  }

  /// Returns category names with their counts, sorted alphabetically.
  List<(String, int)> get _categoryChips {
    final all = FavouriteManager.instance.favouritedProducts;
    final counts = <String, int>{};
    for (final p in all) {
      if (p.categoryName.isNotEmpty) {
        counts[p.categoryName] = (counts[p.categoryName] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => (e.key, e.value)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final favourited = FavouriteManager.instance.favouritedProducts;
    final filtered = _filtered;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Favourite',
                      style: GoogleFonts.sriracha(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.favorite,
                        size: 20, color: Color(0xFFF48FB1)),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${favourited.length} items saved',
                  style: _mono(size: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          // ── Category chips ──
          if (_categoryChips.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // "All" chip
                  _categoryChip(
                    label: 'All (${favourited.length})',
                    active: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  for (final chip in _categoryChips) ...[
                    const SizedBox(width: 6),
                    _categoryChip(
                      label: '${chip.$1} (${chip.$2})',
                      active: _selectedCategory == chip.$1,
                      onTap: () => setState(
                          () => _selectedCategory = chip.$1),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 8),

          // ── Grid or empty state ──
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(favourited.isEmpty)
                : GridView.builder(
                    padding:
                        EdgeInsets.fromLTRB(16, 0, 16, 88 + bottomPad),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 160 / 220,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _productCard(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Category chip ─────────────────────────────────────────────────────────

  Widget _categoryChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Text(
          label,
          style: _jak(
            size: 12,
            weight: FontWeight.w600,
            color: active ? AppColors.surface : AppColors.ink,
          ),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool nothingSaved) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            nothingSaved ? Icons.favorite_border : Icons.filter_list,
            size: 52,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            nothingSaved ? 'Nothing saved yet' : 'No items in this category',
            style: _sans(size: 16, weight: FontWeight.w600,
                color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            nothingSaved
                ? 'Tap ♥ on any listing to save it here'
                : 'Try selecting a different category',
            style: _mono(size: 10, color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
          if (nothingSaved) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: widget.onExplore,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Explore listings',
                  style: _sans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Product card — exact match to home_page.dart Trending card ─────────────

  Widget _productCard(Product product) {
    final fav = FavouriteManager.instance;
    final idStr = product.id.toString();
    final isLiked = fav.isFavourited(idStr);
    final liveCount = fav.getCount(idStr);
    final favCount = liveCount > 0 ? liveCount : product.favouritesCount;

    final priceText = (product.type == 'RENT' && product.rentPrice > 0)
        ? 'เช่า ฿${_formatPrice(product.rentPrice)}'
        : (product.type == 'RENT' && product.price > 0)
            ? 'เช่า ฿${_formatPrice(product.price)}'
            : '฿${_formatPrice(product.price)}';

    return GestureDetector(
      onTap: () => _openProduct(product),
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
            // ── Image (big, flex like home Trending) ──────────────────
            Expanded(
              flex: 13,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _imageContent(product),
                  // Category badge — top-left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _categoryBadge(product.categoryName),
                  ),
                  // Type badge — top-right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _typeBadge(product.type),
                  ),
                  // Condition badge — bottom-left (matches home Trending)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _conditionBadge(product.condition),
                  ),
                ],
              ),
            ),
            // ── Info ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Plus Jakarta Sans — same as home_page Trending card
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
                      GestureDetector(
                        onTap: () =>
                            fav.toggle(idStr, product: product),
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 17,
                              color: const Color(0xFFF48FB1),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$favCount',
                              style: _mono(
                                size: 11,
                                color: AppColors.textMuted,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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
          color: isRent ? AppColors.accent : const Color(0xFF22C55E),
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
        style: _mono(
            size: 8, color: AppColors.ink, weight: FontWeight.w700),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _conditionBadge(String condition) {
    final label = _conditionLabel(condition);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: _mono(size: 8, color: Colors.white, weight: FontWeight.w700),
      ),
    );
  }

  // ── Image ──────────────────────────────────────────────────────────────────

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
}
