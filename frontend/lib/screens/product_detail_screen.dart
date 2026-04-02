import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/transaction_service.dart';
import '../config.dart';
import 'edit_product_screen.dart';
import 'chat_room_screen.dart';
import 'user_profile_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String currentUserId; // <--- รับค่า ID ของคนดูเข้ามา

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
          ownerName: _product.ownerName,
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

  /// ซื้อ/เช่าสินค้า — เรียก TransactionService.createTransaction
  Future<void> _buyOrRent() async {
    final type = _product.type == 'RENT' ? 'RENT' : 'SALE';
    final actionLabel = _product.type == 'RENT' ? 'เช่า' : 'ซื้อ';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ยืนยันการ$actionLabel'),
        content: Text('คุณต้องการ$actionLabelสินค้า "${_product.title}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ยืนยัน$actionLabel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await TransactionService.createTransaction(
      widget.currentUserId,
      _product.id,
      type,
    );

    if (!mounted) return;

    if (result['success'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'ไม่สามารถสร้างธุรกรรมได้'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('สร้างรายการ$actionLabelสำเร็จ รอผู้ขายยืนยัน'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// เปิดแชทกับผู้ขาย — เรียก ChatService.createOrOpenRoom แล้วนำทางไป ChatRoomScreen
  Future<void> _openChat() async {
    final result = await ChatService.createOrOpenRoom(
      widget.currentUserId,
      _product.ownerId,
      _product.id,
    );

    if (!mounted) return;

    if (result['id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            roomId: result['id'],
            currentUserId: widget.currentUserId,
            otherUserName: _product.ownerName,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'ไม่สามารถเปิดแชทได้'),
          backgroundColor: Colors.red,
        ),
      );
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

  String _getStatusText(String status) {
    if (_product.type == 'RENT') {
      // ⭐ สำหรับของเช่า
      switch (status) {
        case 'RESERVED':
          return 'ถูกเช่า';
        case 'SOLD': // เผื่อเหนียว เผื่อมีใครกดผิดมา
          return 'ถูกเช่า';
        default:
          return 'ว่าง';
      }
    } else {
      // ⭐ สำหรับของขาย (เหมือนเดิม)
      switch (status) {
        case 'RESERVED':
          return 'ติดจอง';
        case 'SOLD':
          return 'ขายแล้ว';
        default:
          return 'ว่าง';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      // --------------------------------------------------------
      // ⭐⭐⭐ เพิ่มส่วนปุ่ม Chat ด้านล่าง (Bottom Bar) ⭐⭐⭐
      // --------------------------------------------------------
      bottomNavigationBar: isOwner
          ? null // ถ้าเป็นเจ้าของร้าน ไม่ต้องมีปุ่ม
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5), // เงาขึ้นข้างบน
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // ปุ่มหัวใจ (Favorite)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.favorite_border),
                        onPressed: () {
                          // TODO: ทำระบบกดถูกใจ
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ปุ่มทักแชท (Chat Button)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openChat(),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text(
                          "ทักแชท",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ปุ่มซื้อ/เช่า (Buy/Rent Button)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _product.status == 'AVAILABLE'
                            ? () => _buyOrRent()
                            : null,
                        icon: Icon(_product.type == 'RENT'
                            ? Icons.access_time
                            : Icons.shopping_cart),
                        label: Text(
                          _product.type == 'RENT' ? "เช่า" : "ซื้อ",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6F61),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[500],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

      // --------------------------------------------------------
      body: CustomScrollView(
        // ใช้ CustomScrollView ตามเดิม (ถ้าแก้แล้วไม่ดำ) หรือใช้ SingleChildScrollView ก็ได้
        slivers: [
          SliverAppBar(
            expandedHeight: screenHeight * 0.45, // ปรับความสูงรูป
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: const BackButton(color: Colors.black), // ปุ่มย้อนกลับสีดำ
            actions: [
              if (isOwner)
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
                  // ส่วนแสดงรูปภาพ (PageView)
                  Container(
                    color: Colors.white,
                    width: double.infinity,
                    height: double.infinity,
                    child: _product.images.isNotEmpty
                        ? PageView.builder(
                            itemCount: _product.images.length,
                            onPageChanged: (index) =>
                                setState(() => _currentImageIndex = index),
                            itemBuilder: (context, index) => Image.network(
                              '${AppConfig.uploadsUrl}/${_product.images[index]}',
                              fit: BoxFit
                                  .contain, // ปรับเป็น contain ให้เห็นทั้งรูป
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
                  // จุดไข่ปลาบอกตำแหน่งรูป
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
                            width: _currentImageIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index
                                  ? Colors.black
                                  : Colors.grey.withOpacity(0.5),
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
                  // หมวดหมู่
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

                  // // ราคา
                  // Text(
                  //   "฿ ${_product.price}",
                  //   style: const TextStyle(
                  //     fontSize: 28,
                  //     fontWeight: FontWeight.bold,
                  //     color: Colors.black87,
                  //   ),
                  // ),
                  // const SizedBox(height: 8),

                  // ราคา
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _product.type == 'RENT'
                            ? "฿ ${_product.rentPrice}"
                            : "฿ ${_product.price}",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _product.type == 'RENT'
                              ? Colors.blue[700]
                              : Colors.black87,
                        ),
                      ),
                      if (_product.type == 'RENT')
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4.0, left: 4.0),
                          child: Text(
                            "/ Day",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      const Spacer(),

                      // เพิ่มป้ายบอกประเภทตรงข้ามราคา
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _product.type == 'RENT'
                              ? Colors.blue[50]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _product.type == 'RENT'
                                ? Colors.blue
                                : Colors.grey,
                          ),
                        ),
                        child: Text(
                          _product.type == 'RENT' ? "For Rent" : "For Sale",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _product.type == 'RENT'
                                ? Colors.blue[700]
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ชื่อสินค้า
                  Text(
                    _product.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _product.location.isNotEmpty
                            ? _product.location
                            : 'ไม่ระบุสถานที่',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ผู้ขาย
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black,
                        child: Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (!isOwner) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfileScreen(
                                  userId: _product.ownerId,
                                  displayName: _product.ownerName,
                                ),
                              ),
                            );
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ผู้ขาย:",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _product.ownerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(thickness: 1, color: Colors.grey),
                  const SizedBox(height: 16),

                  // สถานะ และ สภาพ
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
                            isOwner
                                ? Container(
                                    // เจ้าของแก้สถานะได้
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
                                          color: _getStatusColor(
                                            _product.status,
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: _getStatusColor(
                                            _product.status,
                                          ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        // ⭐ เอา const ออก แล้วใช้ if เช็ค type เพื่อแสดง item ที่ต่างกัน
                                        items: _product.type == 'RENT'
                                            ? const [
                                                // รายการสำหรับ "ปล่อยเช่า"
                                                DropdownMenuItem(
                                                  value: 'AVAILABLE',
                                                  child: Text("ว่าง"),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'RESERVED',
                                                  child: Text("ถูกเช่า"),
                                                ),
                                              ]
                                            : const [
                                                // รายการสำหรับ "ขายขาด"
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
                                  )
                                : Container(
                                    // คนอื่นเห็นแค่ป้าย
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_product.status),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getStatusText(_product.status),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
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

                  // รายละเอียดสินค้า (แบบมีกรอบสวยๆ)
                  const Padding(
                    padding: EdgeInsets.only(left: 4.0),
                    child: Text(
                      "รายละเอียดสินค้า",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: Colors.grey[300]!, width: 1.5),
                    ),
                    child: Text(
                      _product.description.isNotEmpty
                          ? _product.description
                          : '-',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                        height: 1.6,
                      ),
                    ),
                  ),

                  // เว้นที่ด้านล่างเผื่อติดขอบ
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