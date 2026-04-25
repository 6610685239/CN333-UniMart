import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../pages/home_page.dart';

class HomeScreen extends StatefulWidget {
  final String currentUserId;
  final int unreadNotificationCount;
  final VoidCallback? onNotificationTap;

  const HomeScreen({
    super.key,
    required this.currentUserId,
    this.unreadNotificationCount = 0,
    this.onNotificationTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final all = await _api.getProducts();
      if (mounted) {
        setState(() {
          _products = all;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomePage(
      products: _products,
      isLoading: _isLoading,
      onRetry: _fetchProducts,
      currentUserId: widget.currentUserId,
      unreadNotificationCount: widget.unreadNotificationCount,
      onNotificationTap: widget.onNotificationTap,
    );
  }
}
