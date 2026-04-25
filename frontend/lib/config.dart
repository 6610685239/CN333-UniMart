import 'package:flutter/foundation.dart';

class AppConfig {
  // Railway public URL — update this when you get the domain from Railway
  static const _railwayUrl = 'https://cn333-unimart-production.up.railway.app';

  /// Base URL สำหรับ API
  static String get baseUrl {
    if (kIsWeb) {
      return '$_railwayUrl/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://127.0.0.1:3000/api';
  }

  /// Base URL สำหรับโหลดรูปภาพ (ไม่มี /api)
  static String get uploadsUrl {
    if (kIsWeb) {
      return '$_railwayUrl/uploads';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/uploads';
    }
    return 'http://127.0.0.1:3000/uploads';
  }
}
