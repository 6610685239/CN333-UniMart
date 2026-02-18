import 'package:flutter/material.dart';
import 'screens/main_screen.dart'; // <--- อย่าลืม import ไฟล์ใหม่

void main() {
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
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Prompt', // (ถ้าคุณใช้ฟอนต์ไทย)
      ),
      // ⭐ เปลี่ยนตรงนี้ครับ ⭐
      home: const MainScreen(), 
    );
  }
}