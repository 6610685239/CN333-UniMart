import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../pages/home_page.dart';

// home_screen.dart ทำหน้าที่เป็น bridge ไปหน้า HomePage ของเรา
// login_screen.dart ยังคง import 'home_screen.dart' เหมือนเดิม ไม่ต้องแก้อะไร

class HomeScreen extends StatefulWidget {
  final String currentUserId; // รับ ID เรามา เพื่อจะได้กรองของตัวเองออก

  const HomeScreen({super.key, required this.currentUserId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService api = ApiService();
  List<Product> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final allProducts = await api.getProducts();
      setState(() {
        // แสดงสินค้าทั้งหมด (รวมของตัวเอง — เจ้าของจะเห็นแต่ซื้อ/เช่าไม่ได้)
        products = allProducts;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading home: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomePage(
      products: products,
      isLoading: isLoading,
      onRetry: _fetchProducts,
      currentUserId: widget.currentUserId,
    );
  }
}