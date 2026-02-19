import 'package:flutter/material.dart';
import 'favourite_manager.dart';
import 'favourited_page.dart';

// ── Local UI-only models ───────────────────────────────────────────────────────

class _CategoryItem {
  final String label;
  final IconData icon;
  final Color color;
  const _CategoryItem(this.label, this.icon, this.color);
}

class _NavItem {
  final IconData filledIcon;
  final IconData outlinedIcon;
  final String label;
  const _NavItem(this.filledIcon, this.outlinedIcon, this.label);
}

// ── HomePage ───────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentBanner = 0;
  int _selectedNav   = 0;
  late PageController _bannerController;

  // Palette
  static const Color _pink     = Color(0xFFF48FB1);
  static const Color _deepPink = Color(0xFFE91E8C);
  static const Color _bgColor  = Color(0xFFF7F8FA);
  static const Color _textDark = Color(0xFF1A1F36);
  static const Color _textMid  = Color(0xFF8A94A6);
  static const Color _inactive = Color(0xFFB0B8C1);

  static const List<_CategoryItem> _categories = [
    _CategoryItem('Hat',         Icons.hive_outlined,          Color(0xFFE3F2FD)), // Soft Pastel Blue (Replaced Grey)
    _CategoryItem('Bags',        Icons.shopping_bag_outlined,  Color(0xFFFFF9C4)), // Soft Pastel Yellow
    _CategoryItem('Clothes',     Icons.dry_cleaning_outlined,  Color(0xFFFFEBEE)), // Soft Pastel Rose
    _CategoryItem('Shoes',       Icons.hiking_outlined,        Color(0xFFF3E5F5)), // Soft Pastel Lavender (Replaced Grey)
    _CategoryItem('Accessories', Icons.watch_outlined,         Color(0xFFFFF3E0)), // Soft Pastel Orange/Gold
    _CategoryItem('Books',       Icons.menu_book_outlined,     Color(0xFFFCE4EC)), // Soft Pastel Pink
    _CategoryItem('Electronics', Icons.devices_outlined,       Color(0xFFE0F2F1)), // Soft Pastel Mint (Replaced Grey)
    _CategoryItem('Others',      Icons.category_outlined,      Color(0xFFE8F5E9)), // Soft Pastel Green
  ];

  static const List<_NavItem> _navItems = [
    _NavItem(Icons.home_rounded,        Icons.home_outlined,       'Home'),
    _NavItem(Icons.chat_bubble_rounded, Icons.chat_bubble_outline, 'Chat'),
    _NavItem(Icons.add_rounded,         Icons.add_rounded,         'Sell'),
    _NavItem(Icons.favorite_rounded,    Icons.favorite_border,     'Favourited'),
    _NavItem(Icons.person_rounded,      Icons.person_outline,      'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _startBannerTimer();
    FavouriteManager.instance.addListener(_refresh);
  }

  void _refresh() { if (mounted) setState(() {}); }

  void _startBannerTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final next = (_currentBanner + 1) % 3;
      _bannerController.animateToPage(next,
        duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      _startBannerTimer();
    });
  }

  @override
  void dispose() {
    FavouriteManager.instance.removeListener(_refresh);
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildBanner(),
                    const SizedBox(height: 22),
                    _buildSectionHeader('Categories', null),
                    const SizedBox(height: 12),
                    _buildCategoryRow(),
                    const SizedBox(height: 26),
                    _buildSectionHeader('Trending Now 🔥', 'See all'),
                    const SizedBox(height: 12),
                    _buildTrendingList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _bgColor, borderRadius: BorderRadius.circular(14)),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search for items...',
                  hintStyle: TextStyle(color: _textMid.withOpacity(0.7), fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: _textMid, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _bgColor, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shopping_bag_outlined, size: 22, color: _textDark),
              ),
              Positioned(right: 8, top: 8,
                child: Container(width: 9, height: 9,
                  decoration: const BoxDecoration(color: _deepPink, shape: BoxShape.circle))),
            ],
          ),
        ],
      ),
    );
  }

  // ── BANNER ───────────────────────────────────────────────────
  Widget _buildBanner() {
    const List<List<Color>> gradients = [
      [Color(0xFFF48FB1), Color(0xFFFFD54F)],
      [Color(0xFFCE93D8), Color(0xFFF48FB1)],
      [Color(0xFFFFCC80), Color(0xFFF48FB1)],
    ];
    const titles    = ['🎉 Flash Sale!', '👗 New Arrivals', '🌸 Season Picks'];
    const subtitles = ['Up to 80% off today', 'Fresh styles just landed', 'Spring collection is here'];

    return Column(
      children: [
        SizedBox(
          height: 155,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: 3,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradients[i],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Stack(children: [
                    Positioned(right: -20, top: -20,
                      child: Container(width: 130, height: 130,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15)))),
                    Positioned(right: 35, bottom: -35,
                      child: Container(width: 90, height: 90,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1)))),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(titles[i], style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          Text(subtitles[i], style: TextStyle(
                            fontSize: 12, color: Colors.white.withOpacity(0.88))),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(color: Colors.white,
                              borderRadius: BorderRadius.circular(20)),
                            child: Text('Shop Now', style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: gradients[i][0]))),
                        ],
                      ),
                    ),
                    Positioned.fill(child: Image.asset('assets/images/banner${i + 1}.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox())),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _currentBanner == i ? 20 : 6, height: 6,
            decoration: BoxDecoration(
              color: _currentBanner == i ? _pink : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3)),
          )),
        ),
      ],
    );
  }

  // ── SECTION HEADER ───────────────────────────────────────────
  Widget _buildSectionHeader(String title, String? action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
            color: _textDark, letterSpacing: -0.3)),
          if (action != null)
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _pink.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
                child: Text('See all', style: TextStyle(
                  color: _deepPink, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  // ── CATEGORIES ───────────────────────────────────────────────
  Widget _buildCategoryRow() {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (_, index) {
          final cat = _categories[index];
          return GestureDetector(
            onTap: () {},
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      color: cat.color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: cat.color.withOpacity(0.5),
                        blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Image.asset(
                        cat.label == 'Clothes'
                            ? 'assets/images/shirt.png'
                            : 'assets/images/${cat.label.toLowerCase()}.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Icon(cat.icon, size: 26, color: Colors.brown.shade400)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(cat.label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _textMid),
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── TRENDING LIST ────────────────────────────────────────────
  Widget _buildTrendingList() {
    return SizedBox(
      height: 268,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: kAllProducts.length,
        itemBuilder: (_, i) => _buildProductCard(kAllProducts[i]),
      ),
    );
  }

  // ── PRODUCT CARD ─────────────────────────────────────────────
  Widget _buildProductCard(ProductItem item) {
    final fav     = FavouriteManager.instance;
    final isLiked = fav.isFavourited(item.id);
    final count   = fav.getCount(item.id);

    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Container(
                  height: 120, width: double.infinity, color: Colors.white,
                  child: Image.asset(item.image, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.image_not_supported_outlined,
                        size: 40, color: Colors.grey.shade300))),
                ),
              ),
              Positioned(top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.07), blurRadius: 4)]),
                  child: Text(item.category,
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: _textMid)),
                )),
            ],
          ),

          // Info area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13, color: _textDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(item.desc,
                    style: TextStyle(fontSize: 9, color: _textMid, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),

                  // Price + heart row (pinned to bottom)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // ราคาเริ่มต้น
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ราคาเริ่มต้น', style: TextStyle(
                              fontSize: 8, color: _textMid, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 1),
                            Text(item.salePrice, style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800, color: _textDark)),
                          ],
                        ),
                      ),
                      // ราคาเช่า
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ราคาเช่า', style: TextStyle(
                              fontSize: 8, color: _textMid, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 1),
                            Text(item.rentPrice, style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800, color: _textDark)),
                          ],
                        ),
                      ),
                      // Heart + count
                      GestureDetector(
                        onTap: () => fav.toggle(item.id),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: isLiked
                                    ? _pink.withOpacity(0.18)
                                    : const Color(0xFFFFEEF5),
                                shape: BoxShape.circle),
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 15,
                                color: _pink),
                            ),
                            if (count > 0) ...[
                              const SizedBox(height: 2),
                              Text('$count', style: TextStyle(
                                fontSize: 8, color: _textMid,
                                fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM NAV ───────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          children: List.generate(_navItems.length, (index) {
            final isSell     = _navItems[index].label == 'Sell';
            final isSelected = _selectedNav == index;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_navItems[index].label == 'Favourited') {
                    setState(() => _selectedNav = index);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FavouritedPage()),
                    ).then((_) {
                      // Reset back to Home tab when returning
                      if (mounted) setState(() => _selectedNav = 0);
                    });
                  } else {
                    setState(() => _selectedNav = index);
                  }
                },
                child: Center(
                  child: isSell
                      ? Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF48FB1), Color(0xFFFFD54F)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: _pink.withOpacity(0.45),
                              blurRadius: 12, offset: const Offset(0, 5))]),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26))
                      : AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? _pink.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                scale: isSelected ? 1.15 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isSelected
                                      ? _navItems[index].filledIcon
                                      : _navItems[index].outlinedIcon,
                                  color: isSelected ? _deepPink : _inactive,
                                  size: 22)),
                              const SizedBox(height: 2),
                              Text(_navItems[index].label, style: TextStyle(
                                fontSize: 9,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? _deepPink : _inactive)),
                            ],
                          ),
                        ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}