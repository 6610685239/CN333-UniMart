import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/review_service.dart';
import '../config.dart';
import 'product_detail_screen.dart';

/// หน้าโปรไฟล์ผู้ขาย (read-only) — ดูได้อย่างเดียว ไม่สามารถแก้ไข
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

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  static const Color _coral = Color(0xFFFF6F61);
  static const Color _textDark = Color(0xFF1A1F36);
  static const Color _textMid = Color(0xFF8A94A6);

  bool _isLoading = true;
  String? _avatarUrl;
  String _displayName = '';
  String? _faculty;
  String? _tuStatus;
  double _creditScore = 0.0;
  int _totalReviews = 0;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadCredit(),
      _loadProducts(),
    ]);
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
              _faculty = user['faculty'];
              _tuStatus = user['tu_status'];
              if (user['avatar'] != null) {
                _avatarUrl = '${AppConfig.uploadsUrl}/${user['avatar']}';
              }
            });
          }
        }
      }
    } catch (e) {
      // Use fallback name
      if (mounted) setState(() => _displayName = widget.sellerName);
    }
  }

  Future<void> _loadCredit() async {
    try {
      final data = await ReviewService.getCreditScore(widget.sellerId);
      if (mounted) {
        setState(() {
          _creditScore = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
          _totalReviews = data['totalReviews'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    try {
      final api = ApiService();
      final result = await api.getMyProducts(widget.sellerId);
      if (mounted) {
        setState(() {
          // แสดงเฉพาะสินค้าที่ AVAILABLE
          _products =
              result.where((p) => p.status == 'AVAILABLE').toList();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _displayName.isNotEmpty ? _displayName : widget.sellerName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('โปรไฟล์ผู้ขาย'),
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _isLoading = true);
                await _loadAll();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // ── Avatar (read-only) ──
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: _coral.withOpacity(0.12),
                      backgroundImage:
                          _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                      child: _avatarUrl == null
                          ? Text(initial,
                              style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: _coral))
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _textDark)),
                    if (_faculty != null && _faculty!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_faculty!,
                            style:
                                TextStyle(fontSize: 13, color: _textMid)),
                      ),
                    if (_tuStatus != null && _tuStatus!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _tuStatus == 'ปกติ'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('สถานะ: $_tuStatus',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _tuStatus == 'ปกติ'
                                      ? Colors.green
                                      : Colors.orange)),
                        ),
                      ),

                    const SizedBox(height: 20),
                    // ── Credit Score ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 36),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _creditScore > 0
                                    ? _creditScore.toStringAsFixed(1)
                                    : '-',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _creditScore > 0
                                        ? Colors.amber[800]
                                        : _textMid),
                              ),
                              Text(
                                  'Credit Score จาก $_totalReviews รีวิว',
                                  style: TextStyle(
                                      fontSize: 12, color: _textMid)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    // ── สินค้าของผู้ขาย ──
                    Row(
                      children: [
                        Icon(Icons.storefront_outlined,
                            color: _coral, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'สินค้าของผู้ขาย (${_products.length})',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_products.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('ยังไม่มีสินค้า',
                                style: TextStyle(
                                    fontSize: 14, color: _textMid)),
                          ],
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) =>
                            _buildProductCard(_products[index]),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProductCard(Product product) {
    final hasImage = product.images.isNotEmpty;
    final imageUrl = hasImage
        ? (product.images.first.startsWith('http') ? product.images.first : '${AppConfig.uploadsUrl}/${product.images.first}')
        : null;

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
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: AspectRatio(
                aspectRatio: 1,
                child: imageUrl != null
                    ? Image.network(imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _placeholder())
                    : _placeholder(),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1F36))),
                    const Spacer(),
                    Text(
                      product.type == 'RENT'
                          ? '฿${product.rentPrice.toStringAsFixed(0)}/วัน'
                          : '฿${product.price.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _coral),
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

  Widget _placeholder() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.image_outlined, size: 40, color: Colors.grey[400]),
    );
  }
}
