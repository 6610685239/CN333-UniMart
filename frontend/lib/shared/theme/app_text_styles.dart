import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Base font: Plus Jakarta Sans (Latin) + NotoSansThai fallback — matches
/// the product-name typography used across the home page.
TextStyle _jak({
  required double size,
  FontWeight weight = FontWeight.w400,
  double letterSpacing = 0,
}) =>
    TextStyle(
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      fontFamilyFallback: const ['NotoSansThai'],
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );

class AppTextStyles {
  /// 34 / w500 / ls -1.5 — splash wordmark
  static TextStyle get display =>
      _jak(size: 34, weight: FontWeight.w500, letterSpacing: -1.5);

  /// 24 / w700 / ls -0.3 — onboarding + section titles
  static TextStyle get titleL =>
      _jak(size: 24, weight: FontWeight.w700, letterSpacing: -0.3);

  /// 20 / w700 / ls -0.2 — screen headings
  static TextStyle get titleM =>
      _jak(size: 20, weight: FontWeight.w700, letterSpacing: -0.2);

  /// 16 / w700 / ls 0 — card titles, sub-headings
  static TextStyle get titleS =>
      _jak(size: 16, weight: FontWeight.w700);

  /// 14 / w400 / ls 0 — standard body copy
  static TextStyle get body => _jak(size: 14);

  /// 13 / w400 / ls 0 — onboarding subtitle, secondary body
  static TextStyle get bodyS => _jak(size: 13);

  /// 12 / w400 / ls 0 — captions, timestamps, meta labels
  static TextStyle get caption => _jak(size: 12);

  /// 11 / w500 / ls 0.8 — tagline, apply .toUpperCase() at call site
  static TextStyle get tagline =>
      _jak(size: 11, weight: FontWeight.w500, letterSpacing: 0.8);

  /// 10 / w500 / ls 0.5 — mono micro labels (IDs, codes)
  static TextStyle get microMono =>
      _jak(size: 10, weight: FontWeight.w500, letterSpacing: 0.5);
}
