import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'my_shop_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // 0 = หน้าแรก, 1 = ร้านค้าของฉัน
  
  // จำลอง ID ของเรา (ในอนาคตค่านี้จะมาจากการ Login)
  final int currentUserId = 2; 

  // รายชื่อหน้าจอที่จะสลับไปมา
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(currentUserId: currentUserId), // หน้า 0: ตลาด (ส่ง ID ไปเพื่อกรองของตัวเองออก)
      const MyShopScreen(),                     // หน้า 1: ร้านค้าของฉัน
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ส่วนเนื้อหา (Body) จะเปลี่ยนไปตาม _selectedIndex
      body: _pages[_selectedIndex],
      
      // แถบเมนูด้านล่าง
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black, // สี icon เวลาเลือก
        unselectedItemColor: Colors.grey, // สี icon เวลาไม่ได้เลือก
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home), // เปลี่ยนรูปตอนกดเลือก
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