import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config.dart';
import '../models/product.dart';
import '../pages/favourite_manager.dart';
import '../shared/theme/app_colors.dart';
import 'product_detail_screen.dart';

// ── Typography ────────────────────────────────────────────────────────────────

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
      c.contains('LIKE')) return 'มือ 1';
  return 'มือ 2';
}

// ── Screen ────────────────────────────────────────────────────────────────────

enum _Sort { newest, priceLow, priceHigh, mostLiked }

class AllProductsScreen extends StatefulWidget {
  final String title;
  final List<Product> products;
  final String currentUserId;

  const AllProductsScreen({
    super.key,
    required this.title,
    required this.products,
    required this.currentUserId,
  });

  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends State<AllProductsScreen> {
  String _typeFilter = 'ALL';
  String? _categoryFilter;
  _Sort _sort = _Sort.newest;

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

  // ── Derived ───────────────────────────────────────────────────────────────

  List<Product> get _filtered {
    var list = widget.products.where((p) {
      if (_typeFilter != 'ALL' && p.type != _typeFilter) return false;
      if (_categoryFilter != null && p.categoryName != _categoryFilter)
        return false;
      return true;
    }).toList();

    switch (_sort) {
      case _Sort.newest:
        list.sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        break;
      case _Sort.priceLow:
        list.sort((a, b) {
          final pa = a.type == 'RENT' ? a.rentPrice : a.price;
          final pb = b.type == 'RENT' ? b.rentPrice : b.price;
          return pa.compareTo(pb);
        });
        break;
      case _Sort.priceHigh:
        list.sort((a, b) {
          final pa = a.type == 'RENT' ? a.rentPrice : a.price;
          final pb = b.type == 'RENT' ? b.rentPrice : b.price;
          return pb.compareTo(pa);
        });
        break;
      case _Sort.mostLiked:
        list.sort((a, b) => b.favouritesCount.compareTo(a.favouritesCount));
        break;
    }
    return list;
  }

  List<String> get _categories {
    final seen = <String>{};
    return widget.products
        .map((p) => p.categoryName)
        .where((n) => n.isNotEmpty && seen.add(n))
        .toList()
      ..sort();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final filtered = _filtered;
    final cats = _categories;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
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
                        border:
                            Border.all(color: AppColors.border, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.sriracha(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.0,
                      ),
                    ),
                  ),
                  Text(
                    '${filtered.length} items',
                    style: _mono(size: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Type + Sort row ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _typeChip('ALL', 'All'),
                  const SizedBox(width: 6),
                  _typeChip('SALE', 'Sale'),
                  const SizedBox(width: 6),
                  _typeChip('RENT', 'Rent'),
                  const Spacer(),
                  _sortButton(),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Category chips ────────────────────────────────────────────
            if (cats.isNotEmpty)
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _catChip(null, 'All'),
                    for (final c in cats) ...[
                      const SizedBox(width: 6),
                      _catChip(c, c),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 10),

            // ── Grid ──────────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48, color: AppColors.textHint),
                          const SizedBox(height: 10),
                          Text('No products found',
                              style: _jak(
                                  size: 15,
                                  weight: FontWeight.w600,
                                  color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text('passed: ${widget.products.length} | filter: $_typeFilter | cat: $_categoryFilter',
                              style:
                                  _mono(size: 10, color: AppColors.textHint)),
                        ],
                      ),
                    )
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
      ),
    );
  }

  // ── Chips ──────────────────────────────────────────────────────────────────

  Widget _typeChip(String value, String label) {
    final active = _typeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _typeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Text(
          label,
          style: _mono(
            size: 10,
            color: active ? AppColors.surface : AppColors.ink,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _catChip(String? value, String label) {
    final active = _categoryFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _categoryFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Text(
          label,
          style: _mono(
            size: 9,
            color: active ? AppColors.surface : AppColors.ink,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _sortButton() {
    final labels = {
      _Sort.newest: 'Newest',
      _Sort.priceLow: 'Price ↑',
      _Sort.priceHigh: 'Price ↓',
      _Sort.mostLiked: 'Popular',
    };
    return GestureDetector(
      onTap: () => _showSortSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 13, color: AppColors.ink),
            const SizedBox(width: 4),
            Text(
              labels[_sort]!,
              style: _mono(
                  size: 10, color: AppColors.ink, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortSheet() {
    final options = {
      _Sort.newest: 'Newest first',
      _Sort.priceLow: 'Price: low to high',
      _Sort.priceHigh: 'Price: high to low',
      _Sort.mostLiked: 'Most popular',
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Sort by',
                style: _jak(size: 16, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final entry in options.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _sort == entry.key
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: _sort == entry.key
                      ? AppColors.ink
                      : AppColors.textMuted,
                ),
                title: Text(entry.value,
                    style: _jak(
                      size: 14,
                      weight: _sort == entry.key
                          ? FontWeight.w700
                          : FontWeight.w400,
                    )),
                onTap: () {
                  setState(() => _sort = entry.key);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Product card (exact match to home_page trending card) ──────────────────

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
            // ── Image ──────────────────────────────────────────────────
            Expanded(
              flex: 13,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _imageContent(product),
                  Positioned(
                    top: 8, left: 8,
                    child: _categoryBadge(product.categoryName),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: _typeBadge(product.type),
                  ),
                  Positioned(
                    bottom: 8, left: 8,
                    child: _conditionBadge(product.condition),
                  ),
                ],
              ),
            ),
            // ── Info ───────────────────────────────────────────────────
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
                      Text(priceText,
                          style: _jak(size: 13, weight: FontWeight.w800)),
                      GestureDetector(
                        onTap: () => fav.toggle(idStr, product: product),
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
                            Text('$favCount',
                                style: _mono(
                                    size: 11,
                                    color: AppColors.textMuted,
                                    weight: FontWeight.w700)),
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
      child: Text(name,
          style: _mono(size: 8, color: AppColors.ink, weight: FontWeight.w700),
          overflow: TextOverflow.ellipsis),
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
