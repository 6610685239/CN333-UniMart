import 'package:flutter/material.dart';

import '../config.dart';
import '../models/product.dart';
import '../pages/favourite_manager.dart';
import 'product_detail_screen.dart';

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
  static const Color _pink = Color(0xFFF48FB1);
  static const Color _textDark = Color(0xFF1A1F36);
  static const Color _textMid = Color(0xFF8A94A6);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: widget.products.isEmpty
          ? const Center(child: Text('ไม่พบสินค้า'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _pink.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: _textDark, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'พบสินค้าทั้งหมด ${widget.products.length} รายการ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: widget.products.length,
                    itemBuilder: (_, index) => _buildProductCard(widget.products[index]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProductCard(Product product) {
    final fav = FavouriteManager.instance;
    final productIdStr = product.id.toString();
    final isLiked = fav.isFavourited(productIdStr);
    final count = fav.getCount(productIdStr) > 0 ? fav.getCount(productIdStr) : product.favouritesCount;

    Widget imageWidget;
    if (product.images.isNotEmpty) {
      final imgPath = product.images.first;
      final imageUrl = imgPath.startsWith('http') ? imgPath : '${AppConfig.uploadsUrl}/$imgPath';
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey.shade300),
        ),
      );
    } else {
      imageWidget = Center(
        child: Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey.shade300),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product,
              currentUserId: widget.currentUserId,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    color: Colors.white,
                    child: imageWidget,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      product.categoryName,
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: _textMid),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: _textMid, height: 1.3),
                    ),
                    const Spacer(),
                    Text(
                      product.type == 'RENT' && product.rentPrice > 0
                          ? 'เช่า ฿${product.rentPrice.toStringAsFixed(0)}'
                          : '฿${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: _textMid),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  product.createdAt != null
                                      ? _formatDate(product.createdAt!)
                                      : 'ไม่ทราบวันที่',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: _textMid),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => fav.toggle(productIdStr, product: product),
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: _pink,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$count',
                                style: const TextStyle(fontSize: 10, color: _textMid, fontWeight: FontWeight.w700),
                              ),
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}