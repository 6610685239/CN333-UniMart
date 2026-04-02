import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'my_shop_screen.dart';
import 'chat_list_screen.dart';
import 'notification_screen.dart';
import 'transaction_list_screen.dart';
import 'add_product_screen.dart';
import 'user_profile_screen.dart';
import 'login_screen.dart';
import '../pages/favourited_page.dart';
import '../services/notification_service.dart';

class MainScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const Color _primaryColor = Color(0xFFFF6F61);

  int _selectedIndex = 0;
  late final String currentUserId;
  late final List<Widget> _pages;
  int _unreadNotificationCount = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    currentUserId = widget.user['id'].toString();

    _pages = [
      HomeScreen(currentUserId: currentUserId),
      ChatListScreen(userId: currentUserId),
      const SizedBox(), // placeholder for Sell (handled via navigation)
      const FavouritedPage(),
      UserProfileScreen(
        userId: currentUserId,
        displayName: widget.user['display_name_th'] ?? widget.user['username'] ?? '',
        faculty: widget.user['faculty'] ?? '',
        tuStatus: widget.user['tu_status'] ?? '',
      ),
    ];

    _fetchUnreadCount();
    // Poll unread count every 30 seconds
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchUnreadCount(),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final count = await NotificationService.getUnreadCount(currentUserId);
      if (mounted) {
        setState(() => _unreadNotificationCount = count);
      }
    } catch (_) {
      // Silently fail — badge just won't update
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      // Sell — navigate to AddProductScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddProductScreen(userId: currentUserId),
        ),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _handleLogout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationScreen(userId: currentUserId),
      ),
    );
    _fetchUnreadCount();
  }

  void _openTransactions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionListScreen(userId: currentUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UniMart', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Notification icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black),
                onPressed: _openNotifications,
                tooltip: 'แจ้งเตือน',
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _unreadNotificationCount > 99
                          ? '99+'
                          : '$_unreadNotificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Logout button
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
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline, size: 32),
            activeIcon: Icon(Icons.add_circle, size: 32),
            label: 'Sell',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Favourites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
