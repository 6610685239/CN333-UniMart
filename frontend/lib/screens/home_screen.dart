import 'package:flutter/material.dart';
import 'login_screen.dart'; // เตรียมไว้สำหรับทำปุ่ม Logout

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UniMart'), // หัวข้อแอป
        actions: [
          // ปุ่ม Logout (เผื่อเพื่อนอยากใช้)
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Home',
          style: TextStyle(
            fontSize: 40, 
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}