import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/onboarding/presentation/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/chat_room_screen.dart';
import 'screens/transaction_list_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/review_screen.dart';
import 'pages/favourite_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;

  try {
    String supabaseUrl;
    String supabaseAnonKey;

    if (kIsWeb) {
      // On web the asset bundle path resolution for dotenv is unreliable —
      // use the values directly since they are visible in the JS bundle anyway.
      supabaseUrl = 'https://ztebnnqowoemjlnzqsad.supabase.co';
      supabaseAnonKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0ZWJubnFvd29lbWpsbnpxc2FkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTE0NzM3OSwiZXhwIjoyMDg2NzIzMzc5fQ.OW0w1NzYeiVrNSejwYI6i-Y4ygZiVI64dwmF_NgpW3I';
    } else {
      await dotenv.load(fileName: '.env');
      supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (supabaseUrl.isEmpty) {
        throw Exception('Missing SUPABASE_URL in frontend/.env');
      }
      if (supabaseAnonKey.isEmpty) {
        throw Exception('Missing SUPABASE_ANON_KEY in frontend/.env');
      }
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    await FavouriteManager.instance.init();
  } catch (e) {
    startupError = e.toString();
  }

  // TODO: ตั้งค่า Firebase Cloud Messaging (FCM) สำหรับ Push Notification
  // เมื่อ Firebase ถูก configure แล้ว ให้เพิ่ม:
  // 1. await Firebase.initializeApp();
  // 2. final fcmToken = await FirebaseMessaging.instance.getToken();
  // 3. ลงทะเบียน FCM token เมื่อ login สำเร็จ
  // 4. จัดการ notification tap → นำทางไปหน้าที่เกี่ยวข้อง (ChatRoom/TransactionDetail)
  // 5. Handle background messages with FirebaseMessaging.onBackgroundMessage

  runApp(MyApp(startupError: startupError));
}


class MyApp extends StatelessWidget {
  final String? startupError;

  const MyApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'App startup failed',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    startupError!,
                    style: const TextStyle(color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniMart',
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      // จุดเริ่มต้นของแอป: ต้องบังคับให้มาหน้า Login ก่อนเสมอ
      home: const SplashScreen(),
      // Named routes for navigation
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/notifications':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => NotificationScreen(userId: args['userId']),
            );
          case '/chat-list':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ChatListScreen(userId: args['userId']),
            );
          case '/chat-room':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                roomId: args['roomId'],
                currentUserId: args['currentUserId'],
                otherUserName: args['otherUserName'] ?? '',
                isLocked: args['isLocked'] ?? false,
              ),
            );
          case '/transactions':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => TransactionListScreen(userId: args['userId']),
            );
          case '/user-profile':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                userId: args['userId'],
                displayName: args['displayName'],
                faculty: args['faculty'],
                tuStatus: args['tuStatus'],
              ),
            );
          case '/review':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ReviewScreen(
                transactionId: args['transactionId'],
                reviewerId: args['reviewerId'],
                revieweeId: args['revieweeId'],
                revieweeName: args['revieweeName'] ?? '',
                revieweeAvatar: args['revieweeAvatar'],
                productTitle: args['productTitle'] ?? '',
                productPrice: (args['productPrice'] as num?)?.toDouble() ?? 0.0,
                productType: args['productType'] ?? 'SALE',
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}