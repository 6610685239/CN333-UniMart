import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import '../config.dart';

class TransactionService {
  static String get baseUrl => AppConfig.baseUrl;

  /// สร้างธุรกรรมใหม่
  /// POST /api/transactions
  static Future<Map<String, dynamic>> createTransaction(
    String buyerId,
    int productId,
    String type,
  ) async {
    final url = Uri.parse('$baseUrl/transactions');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'buyerId': buyerId,
          'productId': productId,
          'type': type,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// Seller ยืนยัน (PENDING → PROCESSING)
  /// PATCH /api/transactions/:id/confirm
  static Future<Map<String, dynamic>> confirmTransaction(int id) async {
    final url = Uri.parse('$baseUrl/transactions/$id/confirm');

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// Seller ส่งมอบ (PROCESSING → SHIPPING)
  /// PATCH /api/transactions/:id/ship
  static Future<Map<String, dynamic>> shipTransaction(int id) async {
    final url = Uri.parse('$baseUrl/transactions/$id/ship');

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// Renter คืนของ — RENT only (SHIPPING → RETURNING)
  /// PATCH /api/transactions/:id/return
  static Future<Map<String, dynamic>> returnTransaction(int id) async {
    final url = Uri.parse('$baseUrl/transactions/$id/return');
    try {
      final response = await http.patch(url,
          headers: {'Content-Type': 'application/json'});
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// Buyer/Owner ยืนยันเสร็จสิ้น (SHIPPING→COMPLETED for SALE, RETURNING→COMPLETED for RENT)
  /// PATCH /api/transactions/:id/complete
  static Future<Map<String, dynamic>> completeTransaction(int id) async {
    final url = Uri.parse('$baseUrl/transactions/$id/complete');

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// ยกเลิกธุรกรรม (PENDING/PROCESSING → CANCELED)
  /// PATCH /api/transactions/:id/cancel
  static Future<Map<String, dynamic>> cancelTransaction(
    int id,
    String canceledBy,
    String reason,
  ) async {
    final url = Uri.parse('$baseUrl/transactions/$id/cancel');

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'canceledBy': canceledBy,
          'cancelReason': reason,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// ดึงรายการธุรกรรมของผู้ใช้ (grouped by status)
  /// GET /api/transactions/user/:userId
  /// Returns Map with keys: processing, shipping, history, canceled
  static Future<Map<String, List<Transaction>>> getUserTransactions(
      String userId) async {
    final url = Uri.parse('$baseUrl/transactions/user/$userId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw FormatException(
              'รูปแบบข้อมูลไม่ถูกต้อง: คาดหวัง grouped object แต่ได้ ${decoded.runtimeType}');
        }

        final Map<String, dynamic> grouped = decoded;
        const expectedKeys = ['processing', 'shipping', 'history', 'canceled'];

        return {
          for (final key in expectedKeys)
            key: (grouped[key] is List)
                ? (grouped[key] as List)
                    .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
                    .toList()
                : <Transaction>[],
        };
      } else {
        throw Exception('โหลดรายการธุรกรรมไม่สำเร็จ');
      }
    } on FormatException {
      rethrow;
    } catch (e) {
      throw Exception('เชื่อมต่อ Server ไม่ได้: $e');
    }
  }
}
