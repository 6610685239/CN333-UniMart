import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../config.dart';

class ChatService {
  static String get baseUrl => AppConfig.baseUrl;

  /// สร้างหรือเปิด Chat Room
  /// POST /api/chat/rooms
  static Future<Map<String, dynamic>> createOrOpenRoom(
    String buyerId,
    String sellerId,
    int productId,
  ) async {
    final url = Uri.parse('$baseUrl/chat/rooms');

    try {
      final response = await http.post(
        url,
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

  /// ดึงรายการ Chat Room ของผู้ใช้
  /// GET /api/chat/rooms/:userId
  
  static Future<void> pinRoom(String roomId, String userId, bool isPinned) async {
    final response = await http.put(
        Uri.parse('$baseUrl/chat/$roomId/pin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'isPinned': isPinned}),
    );
    if (response.statusCode != 200) throw Exception('Failed to pin room');
  }

  static Future<void> deleteRoom(String roomId, String userId) async {
    final response = await http.delete(
        Uri.parse('$baseUrl/chat/$roomId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
    if (response.statusCode != 200) throw Exception('Failed to delete room');
  }

  /// Mark all messages in a room as read for a user
  static Future<void> markAsRead(String roomId, String userId) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/chat/$roomId/read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );
    } catch (e) {
      // silent fail — not critical
      print('markAsRead error: $e');
    }
  }

  static Future<List<ChatRoom>> getRooms(String userId) async {
    final url = Uri.parse('$baseUrl/chat/rooms/$userId');

    try {
      final response = await http.get(url);

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

  /// ดึงข้อความใน Chat Room
  /// GET /api/chat/rooms/:roomId/messages
  static Future<List<ChatMessage>> getMessages(String roomId) async {
    final url = Uri.parse('$baseUrl/chat/rooms/$roomId/messages');

    try {
      final response = await http.get(url);

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

  /// ส่งข้อความ
  /// POST /api/chat/messages
  static Future<Map<String, dynamic>> sendMessage(
    String roomId,
    String senderId,
    String content,
    String type,
  ) async {
    final url = Uri.parse('$baseUrl/chat/messages');

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
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'เชื่อมต่อ Server ไม่ได้: $e'};
    }
  }

  /// รายงานผู้ใช้
  /// POST /api/chat/reports
  static Future<Map<String, dynamic>> reportUser(
    String roomId,
    String reporterId,
    String reportedUserId,
    String reason,
  ) async {
    final url = Uri.parse('$baseUrl/chat/reports');

    try {
      final response = await http.post(
        url,
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

  /// Subscribe to messages in a chat room via Supabase Realtime
  /// Returns a stream of new ChatMessage objects
  ///
  /// TODO: Implement Supabase Realtime subscription
  /// This requires the Supabase Flutter client to be initialized.
  /// Example usage once configured:
  ///
  /// ```dart
  /// final supabase = Supabase.instance.client;
  /// return supabase
  ///   .from('chat_messages')
  ///   .stream(primaryKey: ['id'])
  ///   .eq('room_id', roomId)
  ///   .order('created_at')
  ///   .map((list) => list.map((e) => ChatMessage.fromJson(e)).toList());
  /// ```
  static Stream<List<ChatMessage>> subscribeToMessages(String roomId) {
    // Placeholder: returns an empty stream until Supabase Realtime is configured
    return const Stream.empty();
  }
}
