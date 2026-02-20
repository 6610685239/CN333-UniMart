import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../pages/favourite_manager.dart'; // 
class MainScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const MainScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final currentUserId = user['id'].toString();

    // ✅ Init FavouriteManager ด้วย userId จริงจาก login
    FavouriteManager.instance.init(currentUserId);

    return HomeScreen(currentUserId: currentUserId);
  }
}