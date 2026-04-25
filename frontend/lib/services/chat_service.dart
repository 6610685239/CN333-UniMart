import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../config.dart';

class ChatService {
  static String get baseUrl => AppConfig.baseUrl;

  // =============================================
  // Room CRUD
  // =============================================

  /// POST /api/chat/rooms — create or re-open a room
  static Future<Map<String, dynamic>> createOrOpenRoom(
    String buyerId,
    String sellerId,
    int productId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/rooms'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'buyerId': buyerId,
          'sellerId': sellerId,
          'productId': productId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// GET /api/chat/rooms/:userId — unified room list with product info
  static Future<List<ChatRoom>> getRooms(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/rooms/$userId'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => ChatRoom.fromJson(e)).toList();
      } else {
        throw Exception('โหลดรายการแชทไม่สำเร็จ');
      }
    } catch (e) {
      throw Exception('เชื่อมต่อ Server ไม่ได้: $e');
    }
  }

  /// GET /api/chat/rooms/:roomId/detail — room detail with full product info
  static Future<Map<String, dynamic>> getRoomDetail(String roomId) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/chat/rooms/$roomId/detail'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'ไม่พบห้องสนทนา'};
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  // =============================================
  // Pin / Delete / Read
  // =============================================

  static Future<void> pinRoom(String roomId, String userId, bool isPinned) async {
    final response = await http.put(
      Uri.parse('$baseUrl/chat/$roomId/pin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'isPinned': isPinned}),
    );
    if (response.statusCode != 200) {
      String msg = 'Failed to pin room';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['error'] != null) msg = body['error'].toString();
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> deleteRoom(String roomId, String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/chat/$roomId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
    if (response.statusCode != 200) throw Exception('Failed to delete room');
  }

  static Future<void> markAsRead(String roomId, String userId) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/chat/$roomId/read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );
    } catch (_) {
      // silent — best effort
    }
  }

  // =============================================
  // Messages
  // =============================================

  /// GET /api/chat/rooms/:roomId/messages
  static Future<List<ChatMessage>> getMessages(String roomId) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/chat/rooms/$roomId/messages'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => ChatMessage.fromJson(e)).toList();
      } else {
        throw Exception('โหลดข้อความไม่สำเร็จ');
      }
    } catch (e) {
      throw Exception('เชื่อมต่อ Server ไม่ได้: $e');
    }
  }

  /// POST /api/chat/messages
  static Future<Map<String, dynamic>> sendMessage(
    String roomId,
    String senderId,
    String content,
    String type,
  ) async {
    try {
      final body = <String, dynamic>{
        'roomId': roomId,
        'senderId': senderId,
        'type': type,
      };
      if (type == 'image') {
        body['imageUrl'] = content;
      } else {
        body['content'] = content;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chat/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  // =============================================
  // Reports
  // =============================================

  static Future<Map<String, dynamic>> reportUser(
    String roomId,
    String reporterId,
    String reportedUserId,
    String reason,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/reports'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomId': roomId,
          'reporterId': reporterId,
          'reportedUserId': reportedUserId,
          'reason': reason,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// Placeholder for Supabase Realtime (unused)
  static Stream<List<ChatMessage>> subscribeToMessages(String roomId) {
    return const Stream.empty();
  }
}
