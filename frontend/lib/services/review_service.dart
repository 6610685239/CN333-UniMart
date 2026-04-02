import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/review.dart';
import '../config.dart';

class ReviewService {
  static String get baseUrl => AppConfig.baseUrl;

  /// สร้างรีวิว
  /// POST /api/reviews
  static Future<Map<String, dynamic>> createReview(
    int transactionId,
    String reviewerId,
    String revieweeId,
    int rating,
    String? comment,
  ) async {
    final url = Uri.parse('$baseUrl/reviews');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transactionId': transactionId,
          'reviewerId': reviewerId,
          'revieweeId': revieweeId,
          'rating': rating,
          'comment': comment,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// ดึงรีวิวของผู้ใช้
  /// GET /api/reviews/user/:userId
  static Future<List<Review>> getUserReviews(String userId) async {
    final url = Uri.parse('$baseUrl/reviews/user/$userId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => Review.fromJson(e)).toList();
      } else {
        throw Exception('โหลดรีวิวไม่สำเร็จ');
      }
    } catch (e) {
      throw Exception('เชื่อมต่อ Server ไม่ได้: $e');
    }
  }

  /// ดึง Credit Score ของผู้ใช้
  /// GET /api/reviews/credit/:userId
  static Future<Map<String, dynamic>> getCreditScore(String userId) async {
    final url = Uri.parse('$baseUrl/reviews/credit/$userId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('โหลด Credit Score ไม่สำเร็จ');
      }
    } catch (e) {
      throw Exception('เชื่อมต่อ Server ไม่ได้: $e');
    }
  }
}
