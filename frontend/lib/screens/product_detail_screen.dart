import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'edit_product_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final int currentUserId; // <--- รับค่า ID ของคนดูเข้ามา

  const ProductDetailScreen({
    super.key, 
    required this.product,
    required this.currentUserId, // <--- บังคับส่งมา
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product _product;
  final ApiService api = ApiService();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  // เช็คว่าเป็นเจ้าของไหม?
  bool get isOwner => _product.ownerId == widget.currentUserId;

  Future<void> _updateStatus(String newStatus) async {
    final success = await api.updateStatus(_product.id, newStatus);
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
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("อัปเดตสถานะแล้ว")));
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProductScreen(product: _product)),
    );
    if (result == true) {
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ยืนยันการลบ"),
        content: const Text("คุณแน่ใจหรือไม่ว่าจะลบสินค้านี้?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ยกเลิก")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("ลบ")),
        ],
      ),
    );

    if (confirm == true) {
      final success = await api.deleteProduct(_product.id);
      if (success && mounted) Navigator.pop(context, true);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'RESERVED': return Colors.orange;
      case 'SOLD': return Colors.red;
      default: return Colors.green;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'RESERVED': return 'ติดจอง';
      case 'SOLD': return 'ขายแล้ว';
      default: return 'ว่าง';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: screenHeight * 0.5,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const BackButton(color: Colors.black),
            actions: [
              // ⭐⭐⭐ ถ้าเป็นเจ้าของ ถึงจะเห็นปุ่มแก้ไข/ลบ ⭐⭐⭐
              if (isOwner) 
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.black),
                    onSelected: (value) {
                      if (value == 'edit') _navigateToEdit();
                      if (value == 'delete') _deleteProduct();
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(value: 'edit', child: Text('แก้ไขข้อมูล')),
                      const PopupMenuItem(value: 'delete', child: Text('ลบสินค้า', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    color: Colors.white,
                    width: double.infinity,
                    height: double.infinity,
                    child: _product.images.isNotEmpty
                      ? PageView.builder(
                          itemCount: _product.images.length,
                          onPageChanged: (index) => setState(() => _currentImageIndex = index),
                          itemBuilder: (context, index) => Image.network(
                            '${ApiService.baseUrl}/uploads/${_product.images[index]}',
                            fit: BoxFit.contain,
                          ),
                        )
                      : Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey))),
                  ),
                  if (_product.images.length > 1)
                    Positioned(
                      bottom: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_product.images.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentImageIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index ? Colors.black : Colors.grey.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _product.categoryName.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text("฿ ${_product.price}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(_product.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3)),
                  const SizedBox(height: 16),
                  
                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 4),
                      Text(_product.location, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(thickness: 1, color: Colors.grey),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("สถานะ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 5),
                            
                            // ⭐⭐⭐ ตรงนี้คือหัวใจสำคัญ ⭐⭐⭐
                            // ถ้าเป็นเจ้าของ -> โชว์ Dropdown ให้แก้ได้
                            // ถ้าไม่ใช่ -> โชว์แค่ป้ายข้อความเฉยๆ (ห้ามกด)
                            isOwner 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_product.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _getStatusColor(_product.status))
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _product.status,
                                    isDense: true,
                                    icon: Icon(Icons.arrow_drop_down, color: _getStatusColor(_product.status)),
                                    style: TextStyle(color: _getStatusColor(_product.status), fontWeight: FontWeight.bold),
                                    items: const [
                                      DropdownMenuItem(value: 'AVAILABLE', child: Text("ว่าง")),
                                      DropdownMenuItem(value: 'RESERVED', child: Text("ติดจอง")),
                                      DropdownMenuItem(value: 'SOLD', child: Text("ขายแล้ว")),
                                    ],
                                    onChanged: (val) { if (val != null) _updateStatus(val); },
                                  ),
                                ),
                              )
                            : Container( // กรณีไม่ใช่คนขาย: โชว์แค่ป้ายนิ่งๆ
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_product.status), // สีทึบไปเลย
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(_product.status),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("สภาพ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(_product.condition, style: const TextStyle(fontSize: 16, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text("รายละเอียดสินค้า", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(_product.description, style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.6)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}