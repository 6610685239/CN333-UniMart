import 'package:flutter/material.dart';
import 'favourite_manager.dart';

class FavouritedPage extends StatefulWidget {
  const FavouritedPage({super.key});

  @override
  State<FavouritedPage> createState() => _FavouritedPageState();
}

class _FavouritedPageState extends State<FavouritedPage> {
  int _selectedNav = 3; // "Saved" tab is active

  // Palette (same as HomePage)
  static const Color _pink     = Color(0xFFF48FB1);
  static const Color _deepPink = Color(0xFFE91E8C);
  static const Color _bgColor  = Color(0xFFF7F8FA);
  static const Color _textDark = Color(0xFF1A1F36);
  static const Color _textMid  = Color(0xFF8A94A6);
  static const Color _inactive = Color(0xFFB0B8C1);

  static const _navLabels = ['Home', 'Chat', 'Sell', 'Favourited', 'Profile'];
  static const _navFilled = [
    Icons.home_rounded, Icons.chat_bubble_rounded,
    Icons.add_rounded,  Icons.favorite_rounded, Icons.person_rounded,
  ];
  static const _navOutlined = [
    Icons.home_outlined, Icons.chat_bubble_outline,
    Icons.add_rounded,   Icons.favorite_border, Icons.person_outline,
  ];

  @override
  void initState() {
    super.initState();
    FavouriteManager.instance.addListener(_refresh);
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    FavouriteManager.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favourited = FavouriteManager.instance.favouritedProducts;

    return Scaffold(
      backgroundColor: _bgColor,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            // ── Title bar ─────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text('Favourited',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: _textDark)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _bgColor,
                          borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: _textDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────
            Expanded(
              child: favourited.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72, // tall card like Figma
                      ),
                      itemCount: favourited.length,
                      itemBuilder: (_, i) => _buildFavCard(favourited[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── EMPTY STATE ──────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _pink.withOpacity(0.1),
              shape: BoxShape.circle),
            child: Icon(Icons.favorite_border, size: 36, color: _pink)),
          const SizedBox(height: 16),
          const Text('No favourites yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 6),
          Text('Tap the ♡ on any item to save it here',
            style: TextStyle(fontSize: 13, color: _textMid)),
        ],
      ),
    );
  }

  // ── FAVOURITE CARD (Figma style: image top, info below) ──────
  Widget _buildFavCard(ProductItem item) {
    final fav     = FavouriteManager.instance;
    final isLiked = fav.isFavourited(item.id);
    final count   = fav.getCount(item.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Product image ─────────────────────────────────
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                width: double.infinity,
                color: Colors.white,
                child: Image.asset(item.image, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.image_not_supported_outlined,
                      size: 36, color: Colors.grey.shade300))),
              ),
            ),
          ),

          // ── Info ──────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: _textDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  // Description
                  Text(item.desc,
                    style: TextStyle(fontSize: 9, color: _textMid, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),

                  const Spacer(),

                  // ── Prices + heart ────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // ราคาเริ่มต้น
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ราคาเริ่มต้น', style: TextStyle(
                            fontSize: 7.5, color: _textMid, fontWeight: FontWeight.w500)),
                          Text(item.salePrice, style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, color: _textDark)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // ราคาเช่า
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ราคาเช่า', style: TextStyle(
                            fontSize: 7.5, color: _textMid, fontWeight: FontWeight.w500)),
                          Text(item.rentPrice, style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, color: _textDark)),
                        ],
                      ),
                      const Spacer(),
                      // Heart button + count
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
                                    ? _pink.withOpacity(0.15)
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

  // ── BOTTOM NAV (same style as HomePage) ──────────────────────
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
          children: List.generate(_navLabels.length, (index) {
            final isSell     = _navLabels[index] == 'Sell';
            final isSelected = _selectedNav == index;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_navLabels[index] == 'Home') {
                    Navigator.pop(context);
                  } else if (_navLabels[index] != 'Favourited') {
                    // Other tabs: just highlight (no navigation yet)
                    setState(() => _selectedNav = index);
                  }
                  // 'Favourited' tab: already on this page, do nothing
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
                                      ? _navFilled[index]
                                      : _navOutlined[index],
                                  color: isSelected ? _deepPink : _inactive,
                                  size: 22)),
                              const SizedBox(height: 2),
                              Text(_navLabels[index], style: TextStyle(
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