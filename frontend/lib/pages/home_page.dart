import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'favourite_manager.dart';
import '../screens/filter_sheet.dart';
import '../screens/all_products_screen.dart';
import '../screens/product_detail_screen.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../config.dart';
import '../shared/theme/app_colors.dart';

// ── Banner data ────────────────────────────────────────────────────────────────

class _BannerData {
  final String title;
  final String subtitle;
  const _BannerData(this.title, this.subtitle);
}

// ── Typography helpers ─────────────────────────────────────────────────────────
// WF.sans  = Caveat  (all product text, section titles, chips, prices)
// WF.mono  = JetBrains Mono  (labels, "see all", badges)

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

// ── Plus Jakarta Sans + NotoSansThai (name / price / description) ─────────────

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

// ── Sale/Rent badge colours ────────────────────────────────────────────────────

const _saleColor = Color(0xFF22C55E); // green
const _rentColor = AppColors.accent;  // yellow

// ── Price formatter (comma separator) ────────────────────────────────────────

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

// ── Condition label ───────────────────────────────────────────────────────────

String _conditionLabel(String condition) {
  final c = condition.toUpperCase();
  if (c.contains('NEW') || c.contains('หนึ่ง') || c == '1' ||
      c.contains('LIKE')) {
    return 'มือ 1';
  }
  return 'มือ 2';
}

// ── HomePage ───────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  final List<Product> products;
  final bool isLoading;
  final VoidCallback? onRetry;
  final String currentUserId;
  final int unreadNotificationCount;
  final VoidCallback? onNotificationTap;

  const HomePage({
    super.key,
    required this.products,
    required this.isLoading,
    this.onRetry,
    required this.currentUserId,
    this.unreadNotificationCount = 0,
    this.onNotificationTap,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentBanner = 0;
  late final PageController _bannerController;
  Timer? _bannerTimer;

  List<Product>? _filteredProducts;
  bool _isFiltered = false;
  String? _selectedCategory;
  String _typeFilter = 'ALL';

  List<String> _categoryNames = ['All'];

  // ── Search ──────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  static const _banners = [
    _BannerData('Final exam sale 📚', 'Up to 50% off textbooks'),
    _BannerData('New arrivals 👟', 'Fresh listings every hour'),
    _BannerData('Meet on campus 🤝', 'Safe, fast, TU-verified'),
  ];

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _startBannerTimer();
    FavouriteManager.instance.addListener(_refresh);
    _loadCategories();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentBanner + 1) % _banners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ApiService().getCategories();
      if (mounted) {
        setState(() =>
            _categoryNames = ['All', ...cats.map((c) => c.name)]);
      }
    } catch (_) {
      if (mounted && widget.products.isNotEmpty) {
        final names = widget.products
            .map((p) => p.categoryName)
            .toSet()
            .toList()
          ..sort();
        setState(() => _categoryNames = ['All', ...names]);
      }
    }
  }

  @override
  void didUpdateWidget(covariant HomePage old) {
    super.didUpdateWidget(old);
    if (old.products.isEmpty &&
        widget.products.isNotEmpty &&
        _categoryNames.length <= 1) {
      final names = widget.products
          .map((p) => p.categoryName)
          .toSet()
          .toList()
        ..sort();
      setState(() => _categoryNames = ['All', ...names]);
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    FavouriteManager.instance.removeListener(_refresh);
    super.dispose();
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  List<Product> _getBaseProducts() {
    final source = (_isFiltered && _filteredProducts != null)
        ? _filteredProducts!
        : widget.products;
    return source.where((p) {
      if (p.ownerId == widget.currentUserId) return false;
      if (_typeFilter != 'ALL' && p.type != _typeFilter) return false;
      if (_selectedCategory != null &&
          _selectedCategory != 'All' &&
          p.categoryName != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Product> _getTrending() {
    final list = _getBaseProducts()
        .where((p) => p.price >= 500)
        .toList();
    list.sort((a, b) {
      final fc = b.favouritesCount.compareTo(a.favouritesCount);
      if (fc != 0) return fc;
      return (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0));
    });
    return list;
  }

  List<Product> _getRecent() {
    final list = List<Product>.from(_getBaseProducts());
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  List<Product> _getSearchResults(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    final terms = q.split(RegExp(r'\s+'));
    final base = widget.products
        .where((p) => p.ownerId != widget.currentUserId)
        .toList();
    return base.where((p) {
      final haystack = [
        p.title,
        p.description,
        p.categoryName,
        p.ownerName,
      ].join(' ').toLowerCase();
      return terms.every((t) => haystack.contains(t));
    }).toList()
      ..sort((a, b) {
        // Boost exact title match to top
        final aTitle = a.title.toLowerCase().contains(q) ? 0 : 1;
        final bTitle = b.title.toLowerCase().contains(q) ? 0 : 1;
        if (aTitle != bTitle) return aTitle - bTitle;
        return b.favouritesCount.compareTo(a.favouritesCount);
      });
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openAllProducts(String title, List<Product> products) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllProductsScreen(
          title: title,
          products: products,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
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

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, __) => FilterSheet(
          onFilterApplied: (products, _) {
            setState(() {
              if (products != null) {
                _filteredProducts = products;
                _isFiltered = true;
              } else {
                _filteredProducts = null;
                _isFiltered = false;
              }
            });
          },
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final trending = _getTrending();
    final recent = _getRecent();
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isSearching = _searchQuery.trim().isNotEmpty;
    final searchResults = isSearching ? _getSearchResults(_searchQuery) : <Product>[];

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildSearchBar(),
                  const SizedBox(height: 8),

                  if (isSearching) ...[
                    // ── Search results ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: [
                          Text(
                            '${searchResults.length} result${searchResults.length == 1 ? '' : 's'} for ',
                            style: _mono(size: 10, color: AppColors.textMuted),
                          ),
                          Text(
                            '"${_searchQuery.trim()}"',
                            style: _mono(size: 10, color: AppColors.ink, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    if (searchResults.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 60, bottom: 88 + bottomPad),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
                              const SizedBox(height: 10),
                              Text('No results found',
                                  style: _jak(size: 15, weight: FontWeight.w600, color: AppColors.textMuted)),
                              const SizedBox(height: 4),
                              Text('Try different keywords',
                                  style: _mono(size: 10, color: AppColors.textHint)),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 88 + bottomPad),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 160 / 220,
                          ),
                          itemCount: searchResults.length,
                          itemBuilder: (_, i) => _productCard(searchResults[i]),
                        ),
                      ),
                  ] else ...[
                    // ── Normal home layout ──────────────────────────────
                    _buildTypeFilter(),
                    const SizedBox(height: 6),
                    _buildCategoryStrip(),
                    const SizedBox(height: 10),
                    _buildBanner(),
                    const SizedBox(height: 16),
                    if (widget.isLoading || trending.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Trending now',
                        onSeeAll: () =>
                            _openAllProducts('Trending now', trending),
                      ),
                      const SizedBox(height: 8),
                      _buildProductRow(trending,
                          emptyMsg: 'No trending products yet'),
                      const SizedBox(height: 16),
                    ],
                    _buildSectionHeader(
                      'Recently added',
                      onSeeAll: () =>
                          _openAllProducts('Recently added', recent),
                    ),
                    const SizedBox(height: 8),
                    _buildRecentGrid(recent),
                    SizedBox(height: 88 + bottomPad),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Wordmark: big "U" + "nimart" in Caveat, "." in accent
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'U',
                style: GoogleFonts.sriracha(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  height: 1.0,
                ),
              ),
              Text(
                'nimart',
                style: GoogleFonts.sriracha(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  height: 1.0,
                ),
              ),
              Text(
                '.',
                style: GoogleFonts.sriracha(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Bell — circle border, accent dot if unread
          Semantics(
            label: 'Notifications',
            button: true,
            child: GestureDetector(
              onTap: widget.onNotificationTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.border, width: 1.5),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 18, color: AppColors.ink),
                    if (widget.unreadNotificationCount > 0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.bg, width: 1.5),
                          ),
                        ),
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

  // ── Banner ─────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            PageView.builder(
              controller: _bannerController,
              itemCount: _banners.length,
              onPageChanged: (i) =>
                  setState(() => _currentBanner = i),
              itemBuilder: (_, i) => Image.asset(
                'assets/images/banner${i + 1}.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent, AppColors.accentSoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            // Dots — bottom-right
            Positioned(
              right: 10,
              bottom: 8,
              child: Row(
                children: List.generate(_banners.length, (i) {
                  final active = _currentBanner == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.only(left: 3),
                    width: active ? 12 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    final isSearching = _searchQuery.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSearching ? AppColors.ink : AppColors.border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
          color: AppColors.surface,
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search_rounded,
                size: 18,
                color: isSearching ? AppColors.ink : AppColors.textHint),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: _jak(size: 14),
                decoration: InputDecoration(
                  hintText: 'Search books, bikes, jackets…',
                  hintStyle: _jak(size: 14, color: AppColors.textHint),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchFocus.unfocus(),
              ),
            ),
            if (isSearching)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _searchFocus.unfocus();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: AppColors.textMuted),
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  // ── Type filter ────────────────────────────────────────────────────────────

  Widget _buildTypeFilter() {
    const filters = [
      ('ALL', 'All'),
      ('SALE', '฿ For sale'),
      ('RENT', '↻ For rent'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (int i = 0; i < filters.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _typeChip(filters[i].$1, filters[i].$2)),
          ],
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final active = _typeFilter == value;
    return Semantics(
      label: label,
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: () => setState(() => _typeFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Text(
            label,
            style: _jak(
              size: 14,
              weight: FontWeight.w600,
              color: active ? AppColors.surface : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  // ── Category strip ─────────────────────────────────────────────────────────

  Widget _buildCategoryStrip() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.78, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categoryNames.length,
          itemBuilder: (_, i) {
            final name = _categoryNames[i];
            final isAll = name == 'All';
            final displayName = name;
            final active = isAll
                ? (_selectedCategory == null ||
                    _selectedCategory == 'All')
                : _selectedCategory == name;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(
                    () => _selectedCategory = isAll ? null : name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.border, width: 1.5),
                  ),
                  child: Text(
                    displayName,
                    style: _jak(
                      size: 13,
                      weight: FontWeight.w600,
                      color: active
                          ? AppColors.surface
                          : AppColors.ink,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title,
      {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title,
              style: _jak(size: 18, weight: FontWeight.w900)),
          GestureDetector(
            onTap: onSeeAll,
            child: Text('See All >',
                style: _mono(size: 10, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  // ── Horizontal row (Trending) ──────────────────────────────────────────────

  Widget _buildProductRow(List<Product> products,
      {required String emptyMsg}) {
    if (widget.isLoading) return _loadingIndicator(250);
    if (products.isEmpty) return _emptyState(emptyMsg);
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 160,
            child: _productCard(products[i]),
          ),
        ),
      ),
    );
  }

  // ── Vertical grid (Recently added) ────────────────────────────────────────

  Widget _buildRecentGrid(List<Product> products) {
    if (widget.isLoading) return _skeletonGrid();
    if (products.isEmpty) return _emptyState('No products yet');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 160 / 220,
        ),
        itemCount: products.length,
        itemBuilder: (_, i) => _productCard(products[i]),
      ),
    );
  }

  // ── Product card (matches AllProductsScreen style) ─────────────────────────

  Widget _productCard(Product product) {
    final fav = FavouriteManager.instance;
    final idStr = product.id.toString();
    final isLiked = fav.isFavourited(idStr);
    final liveCount = fav.getCount(idStr);
    final favCount = liveCount > 0 ? liveCount : product.favouritesCount;

    final priceText = (product.price == 0 && product.type == 'RENT')
        ? '฿0'
        : (product.type == 'RENT' && product.rentPrice > 0)
            ? 'เช่า ฿${_formatPrice(product.rentPrice)}'
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
            // ── Image (big, flex like skeleton) ──────────────────────
            Expanded(
              flex: 13,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _imageContent(product),
                  // Sold out overlay
                  if (product.status == 'SOLD' || product.quantity <= 0)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'SOLD OUT',
                            style: _mono(
                                size: 9,
                                color: AppColors.surface,
                                weight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
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
                  // Condition badge — bottom-left
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _conditionBadge(product.condition),
                  ),
                ],
              ),
            ),
            // ── Info (compact, like skeleton text area) ───────────────
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
                                  weight: FontWeight.w700),
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
        style: _mono(size: 8, color: AppColors.ink, weight: FontWeight.w700),
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

  // ── Date helper ────────────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ── Loading / empty ────────────────────────────────────────────────────────

  // ── Skeleton — horizontal row ──────────────────────────────────────────────

  Widget _loadingIndicator(double height) {
    // height param kept for callers; we use 250 for cards.
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _SkeletonCard(width: 160),
        ),
      ),
    );
  }

  // ── Skeleton — 2-col grid ──────────────────────────────────────────────────

  Widget _skeletonGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 160 / 220,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => _SkeletonCard(),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Text('○',
                style: _sans(size: 32, color: AppColors.textHint)),
            const SizedBox(height: 6),
            Text(message,
                style: _sans(size: 14, color: AppColors.textMuted)),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: widget.onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Retry',
                    style: _sans(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.surface,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Skeleton card ─────────────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  final double? width;
  const _SkeletonCard({this.width});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
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

  Widget _bone({double? width, double height = 14, double radius = 6}) {
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
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Expanded(
            flex: 13,
            child: _bone(width: double.infinity, height: double.infinity, radius: 0),
          ),
          // Text area
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bone(width: double.infinity, height: 12),
                const SizedBox(height: 5),
                _bone(width: 80, height: 10),
                const SizedBox(height: 8),
                _bone(width: 60, height: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
