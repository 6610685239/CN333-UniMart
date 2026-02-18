import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'edit_product_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product _product;
  final ApiService api = ApiService();

  // ตัวแปรเก็บหน้าที่เลื่อนอยู่ปัจจุบัน
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  // --- ฟังก์ชันเดิม (Update Status, Delete, Edit) ---
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
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("อัปเดตสถานะแล้ว")));
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(product: _product),
      ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ยกเลิก"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("ลบ"),
          ),
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
      case 'RESERVED':
        return Colors.orange;
      case 'SOLD':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณความสูงหน้าจอ
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      // ให้รูปภาพกินพื้นที่ขึ้นไปถึงขอบบนสุด (หลัง Status bar)
      body: CustomScrollView(
        slivers: [
          // ส่วน App Bar และ รูปภาพ
          SliverAppBar(
            expandedHeight: screenHeight * 0.5, // รูปสูงครึ่งจอ
            pinned: true, // เลื่อนแล้ว Bar ยังค้างอยู่ข้างบน
            backgroundColor:
                Colors.white, // เพิ่ม: บังคับให้ AppBar เป็นสีขาวตอนย่อ
            elevation: 0, // เพิ่ม: ลบเงาตอนย่อ
            leading: const BackButton(color: Colors.black),
            actions: [
              // ปุ่มเมนูจัดการ (Edit/Delete)
              Container(
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black),
                  onSelected: (value) {
                    if (value == 'edit') _navigateToEdit();
                    if (value == 'delete') _deleteProduct();
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('แก้ไขข้อมูล'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'ลบสินค้า',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // 1. Image Slider
                  // ⭐⭐⭐ แก้ตรงนี้: เอา Container สีขาวมาห่อไว้ ⭐⭐⭐
                  Container(
                    color: Colors.white, // <-- บังคับพื้นหลังสีขาว
                    width: double.infinity,
                    height: double.infinity,
                    child: _product.images.isNotEmpty
                        ? PageView.builder(
                            itemCount: _product.images.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) => Image.network(
                              '${ApiService.baseUrl}/uploads/${_product.images[index]}',
                              fit: BoxFit
                                  .contain, // <-- แนะนำ: เปลี่ยนเป็น contain เพื่อให้เห็นครบทุกส่วน โดยไม่โดนตัด (ขอบที่เหลือจะเป็นสีขาวแทน)
                              // หรือถ้าอยากให้เต็มจอโดยยอมโดนตัดขอบ ก็ใช้ fit: BoxFit.cover เหมือนเดิม
                            ),
                          )
                        : Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 80,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),

                  // 2. Scroll Indicator (จุดๆ เลื่อนตามรูป)
                  if (_product.images.length > 1)
                    Positioned(
                      bottom: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_product.images.length, (
                          index,
                        ) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentImageIndex == index
                                ? 24
                                : 8, // ถ้ารูปปัจจุบันจะยาวกว่า
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index
                                  ? Colors.black
                                  : Colors.white.withOpacity(0.5),
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

          // ส่วนเนื้อหาด้านล่าง
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // หมวดหมู่ (ตัวเล็ก สีจาง)
                  Text(
                    _product.categoryName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ราคา
                  Text(
                    "฿ ${_product.price}",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 20,
                      ), // ไอคอนหมุดสีแดง
                      const SizedBox(width: 4),
                      Text(
                        _product.location,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ชื่อสินค้า
                  Text(
                    _product.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 24),
                  const SizedBox(height: 16),

                  // หัวข้อ: สถานะ และ สภาพ
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "สถานะ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Dropdown สถานะ (ปรับให้ดู Minimal)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  _product.status,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getStatusColor(_product.status),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _product.status,
                                  isDense: true,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: _getStatusColor(_product.status),
                                  ),
                                  style: TextStyle(
                                    color: _getStatusColor(_product.status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'AVAILABLE',
                                      child: Text("ว่าง"),
                                    ),
                                    DropdownMenuItem(
                                      value: 'RESERVED',
                                      child: Text("ติดจอง"),
                                    ),
                                    DropdownMenuItem(
                                      value: 'SOLD',
                                      child: Text("ขายแล้ว"),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) _updateStatus(val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "สภาพ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _product.condition,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // หัวข้อ: รายละเอียดสินค้า
                  const Text(
                    "รายละเอียดสินค้า",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _product.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                      height: 1.6, // ระยะห่างบรรทัดให้อ่านง่าย
                    ),
                  ),

                  const SizedBox(height: 40), // พื้นที่ว่างด้านล่าง
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
