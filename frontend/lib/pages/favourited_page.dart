import 'package:flutter/material.dart';
import 'favourite_manager.dart';
import '../models/product.dart';
import '../config.dart';

class FavouritedPage extends StatefulWidget {
  const FavouritedPage({super.key});

  @override
  State<FavouritedPage> createState() => _FavouritedPageState();
}

class _FavouritedPageState extends State<FavouritedPage> {
  // Palette (same as HomePage)
  static const Color _pink     = Color(0xFFF48FB1);
  static const Color _deepPink = Color(0xFFE91E8C);
  static const Color _bgColor  = Color(0xFFF7F8FA);
  static const Color _textDark = Color(0xFF1A1F36);
  static const Color _textMid  = Color(0xFF8A94A6);

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

    return Container(
      color: _bgColor,
      child: favourited.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: favourited.length,
              itemBuilder: (_, i) => _buildFavCard(favourited[i]),
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

  // ── FAVOURITE CARD ──────
  Widget _buildFavCard(Product item) {
    final fav     = FavouriteManager.instance;
    final productIdStr = item.id.toString();
    final isLiked = fav.isFavourited(productIdStr);
    final count   = fav.getCount(productIdStr);

    Widget imageWidget;
    if (item.images.isNotEmpty) {
      final imgPath = item.images.first;
      final imageUrl = imgPath.startsWith('http')
          ? imgPath
          : '${AppConfig.uploadsUrl}/$imgPath';
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.image_not_supported_outlined,
            size: 36, color: Colors.grey.shade300)),
      );
    } else {
      imageWidget = Center(
        child: Icon(Icons.image_not_supported_outlined,
          size: 36, color: Colors.grey.shade300));
    }

    return Container(
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
                  child: imageWidget,
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
                  child: Text(item.categoryName,
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
                  Text(item.title, style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13, color: _textDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(item.description,
                    style: TextStyle(fontSize: 9, color: _textMid, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),

                  // Price + heart row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // ราคาเริ่มต้น
                      if (item.type != 'RENT')
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ราคาเริ่มต้น', style: TextStyle(
                                fontSize: 8, color: _textMid, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 1),
                              Text('฿${item.price.toStringAsFixed(0)}', style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, color: _textDark)),
                            ],
                          ),
                        ),
                      // ราคาเช่า
                      if (item.rentPrice > 0)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ราคาเช่า', style: TextStyle(
                                fontSize: 8, color: _textMid, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 1),
                              Text('฿${item.rentPrice.toStringAsFixed(0)}', style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, color: _textDark)),
                            ],
                          ),
                        ),
                      // Heart + count
                      GestureDetector(
                        onTap: () => fav.toggle(productIdStr, product: item),
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

}