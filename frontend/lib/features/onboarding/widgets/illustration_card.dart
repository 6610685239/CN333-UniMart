import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/theme/app_colors.dart';

/// Onboarding page 1 — product-card mockup (portrait, 170×200).
///
/// Layers (back → front):
///   1. Accent-yellow backdrop (20% opacity), offset +10 +12, rotated -3°.
///   2. White foreground card (ink outline): striped image, text bars, price.
///   3. 32 px ink badge with accent "✓" top-right of illustration.
///
/// Entry: card fades + rises 6 px (450 ms); backdrop follows 100 ms later.
/// Loop:  badge pulses scale 1.0 ↔ 1.08, 2 s ease-in-out.
class IllustrationCard extends StatefulWidget {
  const IllustrationCard({super.key});

  @override
  State<IllustrationCard> createState() => _IllustrationCardState();
}

class _IllustrationCardState extends State<IllustrationCard>
    with TickerProviderStateMixin {
  // ── dimensions ─────────────────────────────────────────────────────────────
  static const double _cW = 170;
  static const double _cH = 200;
  static const double _oX = 10; // backdrop offset right
  static const double _oY = 12; // backdrop offset down

  // ── entry: 550 ms (card 0–450 ms, backdrop 100–550 ms) ────────────────────
  late final AnimationController _enter;
  late final Animation<double> _cardFade;
  late final Animation<double> _cardRise;
  late final Animation<double> _bdFade;
  late final Animation<double> _bdRise;

  // ── badge loop ─────────────────────────────────────────────────────────────
  late final AnimationController _badgeCtrl;
  late final Animation<double>   _badgeScale;

  bool _started = false;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    final cardCurve = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 450 / 550, curve: Curves.easeOut),
    );
    final bdCurve = CurvedAnimation(
      parent: _enter,
      curve: const Interval(100 / 550, 1.0, curve: Curves.easeOut),
    );
    _cardFade = Tween<double>(begin: 0, end: 1).animate(cardCurve);
    _cardRise = Tween<double>(begin: 6, end: 0).animate(cardCurve);
    _bdFade   = Tween<double>(begin: 0, end: 1).animate(bdCurve);
    _bdRise   = Tween<double>(begin: 6, end: 0).animate(bdCurve);

    _badgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _badgeScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _badgeCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final bool rm = MediaQuery.of(context).disableAnimations;
    if (rm) {
      _enter.value = 1.0;
    } else {
      _enter.forward();
      _badgeCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _badgeCtrl.dispose();
    super.dispose();
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Container: card size + backdrop offsets + badge overflow.
    const double totalW = _cW + _oX + 16; // extra for badge overflow right
    const double totalH = _cH + _oY;

    return SizedBox(
      width: totalW,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Backdrop — rotated -3° then offset.
          Positioned(
            left: _oX,
            top: _oY,
            child: AnimatedBuilder(
              animation: _enter,
              builder: (_, child) => Opacity(
                opacity: _bdFade.value,
                child: Transform.translate(
                  offset: Offset(0, _bdRise.value),
                  child: child,
                ),
              ),
              child: Transform.rotate(
                angle: -3 * pi / 180,
                child: Container(
                  width: _cW,
                  height: _cH,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // 2. White foreground card.
          Positioned(
            left: 0,
            top: 0,
            child: AnimatedBuilder(
              animation: _enter,
              builder: (_, child) => Opacity(
                opacity: _cardFade.value,
                child: Transform.translate(
                  offset: Offset(0, _cardRise.value),
                  child: child,
                ),
              ),
              child: _card(),
            ),
          ),

          // 3. Badge — top-right of the illustration area.
          Positioned(
            right: 0,
            top: 0,
            child: AnimatedBuilder(
              animation: _badgeScale,
              builder: (_, child) =>
                  Transform.scale(scale: _badgeScale.value, child: child),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '✓',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
      width: _cW,
      height: _cH,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent image placeholder (striped approximated with solid accentSoft).
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.50),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                color: AppColors.accent.withValues(alpha: 0.60),
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Title bar
          _bar('80%'),
          const SizedBox(height: 8),
          // Sub bar
          _bar('55%'),
          const Spacer(),
          // Price + heart row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '฿450',
                style: GoogleFonts.caveat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                '♡',
                style: GoogleFonts.caveat(
                  fontSize: 14,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(String widthPct) {
    return FractionallySizedBox(
      widthFactor: double.parse(widthPct.replaceAll('%', '')) / 100,
      child: Container(
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
