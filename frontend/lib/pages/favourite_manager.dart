import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

// ── Product Model (shared across pages) ───────────────────────────────────────

class ProductItem {
  final String id;
  final String category;
  final String name;
  final String desc;
  final String salePrice;
  final String rentPrice;
  final String image;

  const ProductItem({
    required this.id,
    required this.category,
    required this.name,
    required this.desc,
    required this.salePrice,
    required this.rentPrice,
    required this.image,
  });
}

// ── All products (single source of truth) ─────────────────────────────────────

const List<ProductItem> kAllProducts = [
  ProductItem(
    id: 'warrix',
    category: 'Clothes',
    name: 'Warrix',
    desc: 'TU Cheer Shirt 2024 (Golden Seed Edition) Official',
    salePrice: '฿290',
    rentPrice: '฿100',
    image: 'assets/images/product1.png',
  ),
  ProductItem(
    id: 'dinopark',
    category: 'Clothes',
    name: 'Dinopark',
    desc: 'Classic DinoPark T-shirt',
    salePrice: '฿180',
    rentPrice: '฿50',
    image: 'assets/images/product3.png',
  ),
  ProductItem(
    id: 'nanyang',
    category: 'Shoes',
    name: 'Nanyang',
    desc: 'Nanyang Changdao Flipflop',
    salePrice: '฿90',
    rentPrice: '฿20',
    image: 'assets/images/product2.png',
  ),
  ProductItem(
    id: 'wowchicken',
    category: 'Others',
    name: 'WoW Chicken',
    desc: 'Thai Style Grilled Chicken',
    salePrice: '฿5',
    rentPrice: '฿-',
    image: 'assets/images/product4.png',
  ),
];

// ── FavouriteManager — Supabase-backed singleton ──────────────────────────────

class FavouriteManager extends ChangeNotifier {
  FavouriteManager._();

  static FavouriteManager? _instance;

  static FavouriteManager get instance {
    _instance ??= FavouriteManager._();
    return _instance!;
  }

  SupabaseClient get _supabase => Supabase.instance.client;
  // Local cache
  final Set<String> _myFavourites = {}; // product ids this user favourited
  final Map<String, int> _favouriteCounts = {}; // product id -> total count

  // Simple device-level user id (replace with auth.uid() if using Supabase Auth)
  late final String _userId;
  bool _initialized = false;

  // ── Init: call once from main.dart or app startup ─────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Generate a stable device ID (in production use device_info_plus or auth)
    _userId = 'user_${Random().nextInt(999999).toString().padLeft(6, '0')}';
    // NOTE: Replace above with shared_preferences to persist across restarts:
    // final prefs = await SharedPreferences.getInstance();
    // _userId = prefs.getString('device_id') ?? _generateAndSave(prefs);

    await _loadFromSupabase();
  }

  // ── Load all counts + this user's favourites from Supabase ─
  Future<void> _loadFromSupabase() async {
    try {
      // 1. All favourite counts (from view)
      final counts = await _supabase
          .from('product_favourite_counts')
          .select('product_id, favourite_count');

      for (final row in counts) {
        _favouriteCounts[row['product_id'] as String] =
            row['favourite_count'] as int;
      }

      // 2. This user's favourites
      final myFavs = await _supabase
          .from('product_favourites')
          .select('product_id')
          .eq('user_id', _userId);

      for (final row in myFavs) {
        _myFavourites.add(row['product_id'] as String);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('FavouriteManager load error: $e');
    }
  }

  // ── Toggle favourite — instant UI, background Supabase sync ──
  void toggle(String productId) {
    final wasLiked = _myFavourites.contains(productId);

    // 1. Update local state immediately (zero delay)
    if (wasLiked) {
      _myFavourites.remove(productId);
      _favouriteCounts[productId] = (_favouriteCounts[productId] ?? 1) - 1;
    } else {
      _myFavourites.add(productId);
      _favouriteCounts[productId] = (_favouriteCounts[productId] ?? 0) + 1;
    }
    notifyListeners(); // UI updates instantly here

    // 2. Sync to Supabase in background (fire-and-forget)
    _syncToSupabase(productId, wasLiked);
  }

  Future<void> _syncToSupabase(String productId, bool wasLiked) async {
    try {
      if (wasLiked) {
        await _supabase
            .from('product_favourites')
            .delete()
            .eq('product_id', productId)
            .eq('user_id', _userId);
      } else {
        await _supabase.from('product_favourites').insert({
          'product_id': productId,
          'user_id': _userId,
        });
      }
    } catch (e) {
      // Rollback on Supabase error
      if (wasLiked) {
        _myFavourites.add(productId);
        _favouriteCounts[productId] = (_favouriteCounts[productId] ?? 0) + 1;
      } else {
        _myFavourites.remove(productId);
        _favouriteCounts[productId] = (_favouriteCounts[productId] ?? 1) - 1;
      }
      notifyListeners();
      debugPrint('FavouriteManager sync error: $e');
    }
  }

  // ── Getters ────────────────────────────────────────────────
  bool isFavourited(String productId) => _myFavourites.contains(productId);

  int getCount(String productId) => _favouriteCounts[productId] ?? 0;

  List<ProductItem> get favouritedProducts =>
      kAllProducts.where((p) => _myFavourites.contains(p.id)).toList();
}
