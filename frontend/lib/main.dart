import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/home_page.dart';
import 'pages/favourite_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ztebnnqowoemjlnzqsad.supabase.co',       
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0ZWJubnFvd29lbWpsbnpxc2FkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNDczNzksImV4cCI6MjA4NjcyMzM3OX0.Ug4uRNwULWfL9FvCQwvSy_g48P_OddjkS21V-IzziyE', 
  );

  await FavouriteManager.instance.init();

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniMart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}