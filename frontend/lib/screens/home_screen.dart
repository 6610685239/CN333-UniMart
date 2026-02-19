import 'package:flutter/material.dart';
import '../pages/home_page.dart';

// home_screen.dart ทำหน้าที่เป็น bridge ไปหน้า HomePage ของเรา
// login_screen.dart ยังคง import 'home_screen.dart' เหมือนเดิม ไม่ต้องแก้อะไร

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect ไป HomePage ทันทีโดยไม่มี animation กระตุก
    return const HomePage();
  }
}