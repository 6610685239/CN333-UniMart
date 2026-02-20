import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  final Set<String> _myFavourites = {};
  final Map<String, int> _favouriteCounts = {};

  // ✅ เปลี่ยนจาก late String เป็น String? เพื่อป้องกัน LateInitializationError
  String? _userId;
  bool _initialized = false;

  // ── Init: รับ userId จากภายนอก (เรียกหลัง login สำเร็จ) ───
  Future<void> init(String userId) async {
    // ถ้า userId เดิมอยู่แล้วไม่ต้องโหลดซ้ำ
    if (_initialized && _userId == userId) return;
    _initialized = true;
    _userId = userId;

    await _loadFromSupabase();
  }

  // ── โหลดข้อมูลจาก Supabase ─────────────────────────────────
  Future<void> _loadFromSupabase() async {
    // ✅ Guard: ถ้า userId ยังไม่มีให้หยุดทันที ไม่ error
    if (_userId == null) return;

    try {
      // 1. โหลด counts ทั้งหมด (จาก view)
      final counts = await _supabase
          .from('product_favourite_counts')
          .select('product_id, favourite_count');

      for (final row in counts) {
        _favouriteCounts[row['product_id'] as String] =
            row['favourite_count'] as int;
      }

      // 2. โหลด favourites ของ user นี้
      final myFavs = await _supabase
          .from('product_favourites')
          .select('product_id')
          .eq('user_id', _userId!);

      _myFavourites.clear();
      for (final row in myFavs) {
        _myFavourites.add(row['product_id'] as String);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('FavouriteManager load error: $e');
    }
  }

  // ── Toggle: อัปเดต UI ทันที แล้วค่อย sync Supabase ──────────
  void toggle(String productId) {
    // ✅ Guard: ถ้า userId ยังไม่ถูก init ไม่ทำอะไร
    if (_userId == null) {
      debugPrint('FavouriteManager: toggle called before init()');
      return;
    }

    final wasLiked = _myFavourites.contains(productId);

    // อัปเดต local ทันที
    if (wasLiked) {
      _myFavourites.remove(productId);
      _favouriteCounts[productId] = (_favouriteCounts[productId] ?? 1) - 1;
    } else {
      _myFavourites.add(productId);
      _favouriteCounts[productId] = (_favouriteCounts[productId] ?? 0) + 1;
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
        await _supabase
            .from('product_favourites')
            .delete()
            .eq('product_id', productId)
            .eq('user_id', _userId!);
      } else {
        await _supabase.from('product_favourites').insert({
          'product_id': productId,
          'user_id': _userId!,
        });
      }
    } catch (e) {
      // Rollback เมื่อ Supabase error
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

