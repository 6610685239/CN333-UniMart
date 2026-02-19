import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // ✅ เอาป้ายแดงๆ คำว่า DEBUG มุมขวาบนออก (ของเพื่อน)
      title: 'UniMart',
      theme: ThemeData(
        // ✅ ใช้สีธีมหลักเป็นสีส้ม/ชมพูที่คุณทำไว้ (หรือจะเปลี่ยนเป็น Colors.blue ตามเพื่อนก็ได้ครับ)
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6F61)), 
        scaffoldBackgroundColor: Colors.white, // ✅ พื้นหลังแอปสีขาว (ของเพื่อน)
        fontFamily: 'NotoSansThai', // ✅ ใช้ฟอนต์ภาษาไทย (ของเพื่อน)
        useMaterial3: true,
      ),
      // ⚠️ จุดเริ่มต้นของแอป: ต้องบังคับให้มาหน้า Login ก่อนเสมอ
      home: const LoginScreen(), 
    );
  }
}