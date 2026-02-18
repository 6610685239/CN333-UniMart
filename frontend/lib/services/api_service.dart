import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ApiService {
  // แก้ IP ตรงนี้ที่เดียว จบ!
  static const String baseUrl = "http://10.0.2.2:3000"; 

  // 1. ดึงสินค้าทั้งหมดของ User
  Future<List<Product>> getMyProducts(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/my-products/$userId'));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      // แปลง JSON List -> Product List
      return body.map((json) => Product.fromJson(json)).toList();
    } else {
      throw Exception("โหลดข้อมูลไม่สำเร็จ");
    }
  }

  // 2. ลบสินค้า
  Future<bool> deleteProduct(int productId) async {
    final response = await http.delete(Uri.parse('$baseUrl/products/$productId'));
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

  // ... (เดี๋ยวค่อยทยอยย้ายฟังก์ชัน Add/Update มาทีหลัง)
}