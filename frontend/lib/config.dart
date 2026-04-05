import 'package:flutter/foundation.dart';

class AppConfig {
  /// Base URL สำหรับ API
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    // สำหรับ Simulator iOS, เครื่องจริงที่รันวง LAN เดียวกัน 
    // หรือ Desktop (Linux/macOS/Windows) ให้ใช้ localhost หรือ IP เครื่องตัวเอง
    return 'http://127.0.0.1:3000/api';
  }

  /// Base URL สำหรับโหลดรูปภาพ (ไม่มี /api)
  static String get uploadsUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/uploads';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/uploads';
    }
    return 'http://127.0.0.1:3000/uploads';
  }
}
