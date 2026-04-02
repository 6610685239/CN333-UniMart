import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await FavouriteManager.instance.init();

  // TODO: ตั้งค่า Firebase Cloud Messaging (FCM) สำหรับ Push Notification
  // เมื่อ Firebase ถูก configure แล้ว ให้เพิ่ม:
  // 1. await Firebase.initializeApp();
  // 2. final fcmToken = await FirebaseMessaging.instance.getToken();
  // 3. ลงทะเบียน FCM token เมื่อ login สำเร็จ
  // 4. จัดการ notification tap → นำทางไปหน้าที่เกี่ยวข้อง (ChatRoom/TransactionDetail)
  // 5. Handle background messages with FirebaseMessaging.onBackgroundMessage

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniMart',
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      // จุดเริ่มต้นของแอป: ต้องบังคับให้มาหน้า Login ก่อนเสมอ
      home: const LoginScreen(),
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
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}