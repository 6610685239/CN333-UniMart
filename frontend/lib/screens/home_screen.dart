import 'package:flutter/material.dart';
import '../pages/home_page.dart';

class HomeScreen extends StatelessWidget {
  final String currentUserId;
  const HomeScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return HomePage(currentUserId: currentUserId);
  }
}