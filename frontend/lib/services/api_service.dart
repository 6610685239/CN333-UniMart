import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/category.dart';

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

  // 1. ดึงสินค้าทั้งหมดของ User
  // Future<List<Product>> getMyProducts(String userId) async {
  //   final response = await http.get(Uri.parse('$baseUrl/my-products/$userId'));

  //   if (response.statusCode == 200) {
  //     List<dynamic> body = jsonDecode(response.body);
  //     // แปลง JSON List -> Product List
  //     return body.map((json) => Product.fromJson(json)).toList();
  //   } else {
  //     throw Exception("โหลดข้อมูลไม่สำเร็จ");
  //   }
  // }

  Future<List<Product>> getMyProducts(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/products?ownerId=$userId'),
    );

    print("STATUS CODE: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Product.fromJson(e)).toList();
    } else {
      throw Exception("โหลดข้อมูลไม่สำเร็จ");
    }
  }

  // 2. ลบสินค้า
  Future<bool> deleteProduct(int productId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/products/$productId'),
    );
    return response.statusCode == 200;
  }

  // 3. อัปเดตสถานะ
  Future<bool> updateStatus(int productId, String newStatus) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/products/$productId'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"status": newStatus}),
    );
    return response.statusCode == 200;
  }

  // 4. ดึงสินค้าทั้งหมด (หน้า Home)
  Future<List<Product>> getProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/products'));

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<List<Category>> getCategories() async {
    final url = '$baseUrl/api/categories';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Category.fromJson(e)).toList();
    } else {
      throw Exception("โหลด category ไม่สำเร็จ");
    }
  }
}
