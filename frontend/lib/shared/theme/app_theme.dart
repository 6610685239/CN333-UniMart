import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.ink,
          surface: AppColors.surface,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      );
}
