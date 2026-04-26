import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthService {
  static String get baseUrl => AppConfig.baseUrl;
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'user_data';

  /// ยืนยันตัวตนผ่าน TU API
  /// POST /api/auth/verify
  static Future<Map<String, dynamic>> verify(
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

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// ลงทะเบียนพร้อมรหัสผ่าน UniMart
  /// POST /api/auth/register
  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> userData,
    String appPassword,
  ) async {
    final url = Uri.parse('$baseUrl/auth/register');

    try {
      final body = Map<String, dynamic>.from(userData);
      body['app_password'] = appPassword;

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// เข้าสู่ระบบด้วยรหัสผ่าน UniMart
  /// POST /api/auth/login
  static Future<Map<String, dynamic>> login(
    String username,
    String password, {
    bool rememberMe = true,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['token'] != null && rememberMe) {
        await saveToken(data['token']);
        if (data['user'] != null) {
          await saveUser(data['user']);
        }
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// บันทึก JWT token ลง SharedPreferences
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// ดึง JWT token จาก SharedPreferences
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// ลบ JWT token (logout)
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// บันทึกข้อมูล user ลง SharedPreferences
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// ดึงข้อมูล user จาก SharedPreferences
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  /// ตรวจสอบว่า login อยู่หรือไม่
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  /// Logout — ลบ token และข้อมูล user
  static Future<void> logout() async {
    await removeToken();
  }

}
