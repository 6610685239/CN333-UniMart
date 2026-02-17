// frontend/lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart'; // (ถ้ายังไม่ได้ใช้ Comment ไว้ก่อนได้)

class ApiService {
  // ⚠️ สำหรับรันบน Edge (Web) หรือ iOS Simulator ใช้ localhost ได้เลย
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  // ⚠️ ถ้าจะรัน Android Emulator ให้เปลี่ยนเป็น:
  // static const String baseUrl = 'http://10.0.2.2:3000/api';

  // 1. ฟังก์ชัน Verify (เช็ค User/Pass)
  static Future<Map<String, dynamic>> verifyUser(
    String username,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/auth/verify');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      print('Verify Response: ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      print('Error Verify: $e');
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  // 2. ฟังก์ชัน Register (บันทึกข้อมูล)
  static Future<Map<String, dynamic>> registerUser(
    Map<String, dynamic> userData,
  ) async {
    final url = Uri.parse('$baseUrl/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }
}
