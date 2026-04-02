import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_notification.dart';
import '../config.dart';

class NotificationService {
  static String get baseUrl => AppConfig.baseUrl;

  /// ดึงรายการแจ้งเตือนของผู้ใช้
  /// GET /api/notifications/:userId
  static Future<List<AppNotification>> getNotifications(String userId) async {
    final url = Uri.parse('$baseUrl/notifications/$userId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => AppNotification.fromJson(e)).toList();
      } else {
        throw Exception('โหลดแจ้งเตือนไม่สำเร็จ');
      }
    } catch (e) {
      throw Exception('เชื่อมต่อ Server ไม่ได้: $e');
    }
  }

  /// อ่านแจ้งเตือน (mark as read)
  /// PATCH /api/notifications/:id/read
  static Future<Map<String, dynamic>> markAsRead(
    String notificationId,
  ) async {
    final url = Uri.parse('$baseUrl/notifications/$notificationId/read');

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

  /// ดึงจำนวนแจ้งเตือนที่ยังไม่อ่าน
  /// GET /api/notifications/:userId/unread-count
  static Future<int> getUnreadCount(String userId) async {
    final url = Uri.parse('$baseUrl/notifications/$userId/unread-count');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unreadCount'] ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      return 0;
    }
  }

  /// อัปเดตการตั้งค่าแจ้งเตือน
  /// PATCH /api/notifications/:userId/settings
  static Future<Map<String, dynamic>> updateSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    final url = Uri.parse('$baseUrl/notifications/$userId/settings');

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(settings),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// ลงทะเบียน FCM token
  ///
  /// TODO: Implement FCM token registration
  /// This requires Firebase Cloud Messaging to be configured.
  /// Example usage once configured:
  ///
  /// ```dart
  /// final fcmToken = await FirebaseMessaging.instance.getToken();
  /// if (fcmToken != null) {
  ///   await updateSettings(userId, {'fcm_token': fcmToken});
  /// }
  /// ```
  static Future<void> registerFcmToken(String userId) async {
    // Placeholder: FCM token registration will be implemented
    // when Firebase Cloud Messaging is configured in the Flutter app.
  }
}
