import 'package:flutter/material.dart';
import 'screens/my_shop_screen.dart'; // Import หน้าจอที่เราแยกไป

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MyShopScreen(),
  ));
}
