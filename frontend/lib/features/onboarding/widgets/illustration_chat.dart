import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/theme/app_colors.dart';

/// Onboarding page 3 — two overlapping chat bubbles.
///
/// Left bubble  (white, ink outline): borderRadius 14/14/14/2 (bottom-left
///   corner square = outgoing style). Contains text bars + typing dots.
/// Right bubble (ink fill): borderRadius 14/14/2/14 (bottom-right corner
///   square = incoming style). Contains text bars + accent price chip.
///
/// Animations:
///   • Right bubble: slides in from 16 px below + fades, 450 ms ease-out,
///     250 ms delay.
///   • Accent price chip: scale 0.9 → 1.0 with elastic overshoot, 300 ms,
///     250 ms delay.
///   • Typing dots: 3 circles cycling opacity 0.3 → 1.0, 400 ms/dot, loop.
///   • Decorative yellow dot: top-left, static.
class IllustrationChat extends StatefulWidget {
  const IllustrationChat({super.key});

  @override
  State<IllustrationChat> createState() => _IllustrationChatState();
}

class _IllustrationChatState extends State<IllustrationChat>
    with TickerProviderStateMixin {
  // Right bubble + chip enter: 700 ms controller.
  late final AnimationController _enter;
  late final Animation<double> _bubbleRise;
  late final Animation<double> _bubbleFade;
  late final Animation<double> _chipScale;

  // Typing dots: 1 200 ms loop (400 ms × 3 dots).
  late final AnimationController _typing;

  bool _started = false;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    final bubbleCurve = CurvedAnimation(
      parent: _enter,
      curve: const Interval(250 / 700, 1.0, curve: Curves.easeOut),
    );
    _bubbleRise = Tween<double>(begin: 16, end: 0).animate(bubbleCurve);
    _bubbleFade = Tween<double>(begin: 0, end: 1).animate(bubbleCurve);

    _chipScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(250 / 700, 550 / 700, curve: Curves.elasticOut),
      ),
    );

    _typing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
      _typing.repeat();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _typing.dispose();
    super.dispose();
  }

  // Typing dot opacity — each dot lights up for its 400 ms window.
  double _dotOpacity(double t, int index) {
    final double start = index / 3.0;
    final double end   = (index + 1) / 3.0;
    if (t < start || t >= end) return 0.3;
    final double p = (t - start) * 3;
    return p < 0.5
        ? 0.3 + 0.7 * (p / 0.5)
        : 1.0 - 0.7 * ((p - 0.5) / 0.5);
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool rm = MediaQuery.of(context).disableAnimations;

    return SizedBox(
      width: 260,
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative yellow dot — top-left.
          Positioned(
            left: 30,
            top: 30,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
            ),
          ),

          // Left bubble (outgoing, white) — static.
          Positioned(
            left: 20,
            top: 50,
            child: _leftBubble(rm),
          ),

          // Right bubble (incoming, ink) — slides in.
          Positioned(
            right: 10,
            bottom: 40,
            child: AnimatedBuilder(
              animation: _enter,
              builder: (_, child) => Opacity(
                opacity: rm ? 1.0 : _bubbleFade.value,
                child: Transform.translate(
                  offset: Offset(0, rm ? 0 : _bubbleRise.value),
                  child: child,
                ),
              ),
              child: _rightBubble(rm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leftBubble(bool rm) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.ink, width: 1.5),
        // Outgoing: bottom-left = 2 px (sharp), others 14 px.
        borderRadius: const BorderRadius.only(
          topLeft:     Radius.circular(14),
          topRight:    Radius.circular(14),
          bottomRight: Radius.circular(14),
          bottomLeft:  Radius.circular(2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _bar(double.infinity, AppColors.ink.withValues(alpha: 0.15)),
          const SizedBox(height: 6),
          _bar(105, AppColors.ink.withValues(alpha: 0.12)),
          const SizedBox(height: 8),
          // Typing dots
          rm
              ? _staticTypingDots()
              : AnimatedBuilder(
                  animation: _typing,
                  builder: (_, __) => _animatedTypingDots(_typing.value),
                ),
        ],
      ),
    );
  }

  Widget _rightBubble(bool rm) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        // Incoming: bottom-right = 2 px (sharp), others 14 px.
        borderRadius: BorderRadius.only(
          topLeft:     Radius.circular(14),
          topRight:    Radius.circular(14),
          bottomLeft:  Radius.circular(14),
          bottomRight: Radius.circular(2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _bar(double.infinity, AppColors.surface.withValues(alpha: 0.40)),
          const SizedBox(height: 6),
          _bar(100, AppColors.surface.withValues(alpha: 0.25)),
          const SizedBox(height: 8),
          // Price chip with elastic enter.
          AnimatedBuilder(
            animation: _enter,
            builder: (_, child) => Transform.scale(
              scale: rm ? 1.0 : _chipScale.value,
              alignment: Alignment.centerLeft,
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '฿450',
                style: GoogleFonts.caveat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _staticTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(right: 3),
        child: _dot(opacity: 0.3 + i * 0.2),
      )),
    );
  }

  Widget _animatedTypingDots(double t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(right: 3),
        child: _dot(opacity: _dotOpacity(t, i)),
      )),
    );
  }

  Widget _dot({required double opacity}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: AppColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _bar(double width, Color color) {
    return Container(
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
