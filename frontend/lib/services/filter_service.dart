import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class FilterService {
  static String get baseUrl => AppConfig.baseUrl;

  /// กรองสินค้าตามเงื่อนไข
  /// GET /api/products/filter
  static Future<Map<String, dynamic>> filterProducts({
    String? faculty,
    String? dormitoryZone,
    String? meetingPoint,
    double? minCredit,
    int? categoryId,
  }) async {
    final queryParams = <String, String>{};

    if (faculty != null && faculty.isNotEmpty) {
      queryParams['faculty'] = faculty;
    }
    if (dormitoryZone != null && dormitoryZone.isNotEmpty) {
      queryParams['dormitoryZone'] = dormitoryZone;
    }
    if (meetingPoint != null && meetingPoint.isNotEmpty) {
      queryParams['meetingPoint'] = meetingPoint;
    }
    if (minCredit != null) {
      queryParams['minCredit'] = minCredit.toString();
    }
    if (categoryId != null) {
      queryParams['categoryId'] = categoryId.toString();
    }

    final url = Uri.parse('$baseUrl/products/filter').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('กรองสินค้าไม่สำเร็จ');
      }
    } catch (e) {
      throw Exception('เชื่อมต่อ Server ไม่ได้: $e');
    }
  }

  /// ดึงรายการจุดนัดพบ
  /// GET /api/meeting-points
  static Future<List<Map<String, dynamic>>> getMeetingPoints() async {
    final url = Uri.parse('$baseUrl/meeting-points');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception('โหลดจุดนัดพบไม่สำเร็จ');
      }
    } catch (e) {
      throw Exception('เชื่อมต่อ Server ไม่ได้: $e');
    }
  }

  /// ดึงรายการโซนหอพัก
  /// GET /api/dormitory-zones
  static Future<List<String>> getDormitoryZones() async {
    final url = Uri.parse('$baseUrl/dormitory-zones');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => e.toString()).toList();
      } else {
        throw Exception('โหลดโซนหอพักไม่สำเร็จ');
      }
    } catch (e) {
      throw Exception('เชื่อมต่อ Server ไม่ได้: $e');
    }
  }
}
