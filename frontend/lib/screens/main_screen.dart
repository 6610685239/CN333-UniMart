import 'package:flutter/material.dart';
import 'home_screen.dart'; // ของเพื่อน
import 'my_shop_screen.dart'; // ของเพื่อน
import 'login_screen.dart'; // ของเรา (สำหรับทำ Logout)

class MainScreen extends StatefulWidget {
  final Map<String, dynamic> user; // ✅ รับข้อมูล User ที่ Login สำเร็จมา

  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; 
  late final String currentUserId; 
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // ✅ ดึง ID จริงๆ จากข้อมูล User ที่ส่งมา
    currentUserId = widget.user['id'].toString(); 

    _pages = [
      HomeScreen(currentUserId: currentUserId), 
      MyShopScreen(currentUserId: currentUserId), // ส่ง ID ตัวเองไปด้วย
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ✅ ฟังก์ชัน Logout ของเรา
  void _handleLogout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UniMart', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ✅ เอาปุ่ม Logout ของเรามาใส่ตรงนี้
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: _handleLogout,
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFFF6F61), // ใช้สีธีมของเรา
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'หน้าหลัก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'ร้านของฉัน',
          ),
        ],
      ),
    );
  }
}