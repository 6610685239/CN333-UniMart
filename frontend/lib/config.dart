import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  /// Base URL สำหรับ API
  /// - Web (Chrome): ใช้ localhost
  /// - Android Emulator: ใช้ 10.0.2.2 (IP พิเศษที่ชี้ไป host machine)
  /// - มือถือจริง: เปลี่ยนเป็น IP ของเครื่องคอม เช่น 192.168.x.x
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    return 'http://10.0.2.2:3000/api';
  }

  /// Base URL สำหรับโหลดรูปภาพ (ไม่มี /api)
  static String get uploadsUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/uploads';
    }
    return 'http://10.0.2.2:3000/uploads';
  }
}
