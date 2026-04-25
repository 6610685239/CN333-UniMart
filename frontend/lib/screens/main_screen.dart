import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'chat_list_screen.dart';
import 'notification_screen.dart';
import 'add_product_screen.dart';
import 'user_profile_screen.dart';
import 'login_screen.dart';
import '../pages/favourited_page.dart';
import '../services/notification_service.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/bottom_nav.dart';

class MainScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final String _userId;
  int _unreadNotificationCount = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _userId = widget.user['id'].toString();
    _fetchUnreadCount();
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
      final count = await NotificationService.getUnreadCount(_userId);
      if (mounted) setState(() => _unreadNotificationCount = count);
    } catch (_) {}
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddProductScreen(userId: _userId),
        ),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationScreen(userId: _userId),
      ),
    );
    _fetchUnreadCount();
  }

  void _handleLogout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          currentUserId: _userId,
          unreadNotificationCount: _unreadNotificationCount,
          onNotificationTap: _openNotifications,
        );
      case 1:
        return ChatListScreen(userId: _userId);
      case 3:
        return FavouritedPage(
          currentUserId: _userId,
          onExplore: () => _onItemTapped(0),
        );
      case 4:
        return UserProfileScreen(
          userId: _userId,
          displayName: widget.user['display_name_th'] ??
              widget.user['username'] ??
              '',
          faculty: widget.user['faculty'] ?? '',
          tuStatus: widget.user['tu_status'] ?? '',
          unreadNotificationCount: _unreadNotificationCount,
          joinedAt: widget.user['created_at']?.toString(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a minimal AppBar only for non-home tabs (chat, saved, profile)
    // Home tab has its own header with the wordmark + notification bell.
    // Chat tab (1) has its own "Chats" header — don't stack UniMart bar on top
    final showAppBar = _selectedIndex != 0 && _selectedIndex != 1 && _selectedIndex != 3 && _selectedIndex != 4;

    return Theme(
      data: AppTheme.theme,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        extendBody: true,
        appBar: showAppBar
            ? AppBar(
                backgroundColor: AppColors.surface,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'U',
                      style: GoogleFonts.sriracha(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'nimart',
                      style: GoogleFonts.sriracha(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      '.',
                      style: GoogleFonts.sriracha(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                actions: const [],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(
                      height: 1, color: AppColors.divider),
                ),
              )
            : null,
        body: _buildPage(_selectedIndex),
        bottomNavigationBar: BottomNav(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
