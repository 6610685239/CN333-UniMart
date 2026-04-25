import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../config.dart';

// ── FavouriteManager — Supabase-backed singleton ──────────────────────────────

class FavouriteManager extends ChangeNotifier {
  FavouriteManager._();

  static FavouriteManager? _instance;
  static FavouriteManager get instance {
    _instance ??= FavouriteManager._();
    return _instance!;
  }

  // Local cache
  final Set<String>    _myFavourites    = {};   // product ids this user favourited
  final Map<String, int> _favouriteCounts = {}; // product id -> total count
  List<Product> _favouritedProductsList = [];    // cached product details

  // User id from auth
  String _userId = '';
  bool _initialized = false;

  // ── Init: call once after login or from app startup ─────────
  Future<void> init() async {
    // Use currentUserId from auth
    final user = await AuthService.getUser();
    final newUserId = user?['id'] ?? '';

    // Skip if no user or already initialized with same user
    if (newUserId.isEmpty) {
      debugPrint('FavouriteManager: No authenticated user found');
      return;
    }

    if (_initialized && _userId == newUserId) return;

    // Reset state for new user or first init
    _myFavourites.clear();
    _favouriteCounts.clear();
    _favouritedProductsList = [];
    _userId = newUserId;
    _initialized = true;

    await _loadFromSupabase();
  }

  // ── โหลดข้อมูลจาก Supabase ─────────────────────────────────
  Future<void> _loadFromSupabase() async {
    // ✅ Guard: ถ้า userId ยังไม่มีให้หยุดทันที ไม่ error
    if (_userId == null) return;

    try {
      // 1. All favourite counts (from view — may not exist)
      try {
        final counts = await _supabase
            .from('product_favourite_counts')
            .select('product_id, favourite_count');

        for (final row in counts) {
          _favouriteCounts[row['product_id'].toString()] =
              row['favourite_count'] as int;
        }
      } catch (e) {
        debugPrint('FavouriteManager: product_favourite_counts view not available, skipping counts');
      }

      // 2. โหลด favourites ของ user นี้
      final myFavs = await _supabase
          .from('product_favourites')
          .select('product_id')
          .eq('user_id', _userId!);

      _myFavourites.clear();
      for (final row in myFavs) {
        _myFavourites.add(row['product_id'].toString());
      }

      // 3. Fetch product details for favourited items
      await fetchFavouritedProducts();

      notifyListeners();
    } catch (e) {
      debugPrint('FavouriteManager load error: $e');
    }
  }

  // ── Fetch product details from API for favourited product IDs ──
  Future<void> fetchFavouritedProducts() async {
    debugPrint('FavouriteManager.fetchFavouritedProducts: _myFavourites=$_myFavourites');
    if (_myFavourites.isEmpty) {
      _favouritedProductsList = [];
      notifyListeners();
      return;
    }

    try {
      final List<Product> products = [];
      for (final productId in _myFavourites) {
        try {
          final url = Uri.parse('${AppConfig.baseUrl}/products/$productId');
          debugPrint('FavouriteManager: Fetching $url');
          final response = await http.get(url);
          debugPrint('FavouriteManager: Response ${response.statusCode} for product $productId');
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            products.add(Product.fromJson(data));
          }
        } catch (e) {
          debugPrint('FavouriteManager: Failed to fetch product $productId: $e');
        }
      }
      _favouritedProductsList = products;
      notifyListeners();
    } catch (e) {
      debugPrint('FavouriteManager fetchFavouritedProducts error: $e');
    }
  }

  // ── Toggle favourite — instant UI, background Supabase sync ──
  void toggle(String productId, {Product? product}) {
    debugPrint('FavouriteManager.toggle($productId) userId=$_userId initialized=$_initialized');
    if (_userId.isEmpty) {
      debugPrint('FavouriteManager: Cannot toggle - no userId');
      return;
    }
    final wasLiked = _myFavourites.contains(productId);

    // อัปเดต local ทันที
    if (wasLiked) {
      _myFavourites.remove(productId);
      _favouriteCounts[productId] = (_favouriteCounts[productId] ?? 1) - 1;
      _favouritedProductsList.removeWhere((p) => p.id.toString() == productId);
    } else {
      _myFavourites.add(productId);
      _favouriteCounts[productId] = (_favouriteCounts[productId] ?? 0) + 1;
      // Add product to list immediately if provided
      if (product != null && !_favouritedProductsList.any((p) => p.id == product.id)) {
        _favouritedProductsList.add(product);
      }
    }
    notifyListeners();

    // Sync Supabase ใน background
    _syncToSupabase(productId, wasLiked);
  }

  Future<void> _syncToSupabase(String productId, bool wasLiked) async {
    // ✅ Guard อีกชั้น
    if (_userId == null) return;

    try {
      if (wasLiked) {
        debugPrint('FavouriteManager: DELETE product_id=$productId user_id=$_userId');
        await _supabase
            .from('product_favourites')
            .delete()
            .eq('product_id', productId)
            .eq('user_id', _userId);
        debugPrint('FavouriteManager: DELETE OK');
      } else {
        debugPrint('FavouriteManager: INSERT product_id=$productId user_id=$_userId');
        await _supabase.from('product_favourites').insert({
          'product_id': productId,
          'user_id': _userId!,
        });
        debugPrint('FavouriteManager: INSERT OK');
        // Fetch the newly favourited product details
        await _fetchSingleProduct(productId);
      }
    } catch (e) {
      // Rollback เมื่อ Supabase error
      if (wasLiked) {
        _myFavourites.add(productId);
        _favouriteCounts[productId] = (_favouriteCounts[productId] ?? 0) + 1;
      } else {
        _myFavourites.remove(productId);
        _favouriteCounts[productId] = (_favouriteCounts[productId] ?? 1) - 1;
        _favouritedProductsList.removeWhere((p) => p.id.toString() == productId);
      }
      notifyListeners();
      debugPrint('FavouriteManager sync error: $e');
    }
  }

  // ── Fetch a single product and add to cached list ──
  Future<void> _fetchSingleProduct(String productId) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/products/$productId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final product = Product.fromJson(data);
        // Avoid duplicates
        if (!_favouritedProductsList.any((p) => p.id == product.id)) {
          _favouritedProductsList.add(product);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('FavouriteManager: Failed to fetch product $productId: $e');
    }
  }

  // ── Getters ────────────────────────────────────────────────
  bool isFavourited(String productId) => _myFavourites.contains(productId);
  int getCount(String productId) => _favouriteCounts[productId] ?? 0;
  List<ProductItem> get favouritedProducts =>
      kAllProducts.where((p) => _myFavourites.contains(p.id)).toList();
}

  List<Product> get favouritedProducts => List.unmodifiable(_favouritedProductsList);
}
