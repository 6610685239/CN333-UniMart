import 'dart:math';
import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';

/// Onboarding page 2 — shield crest illustration.
///
/// Elements:
///   • Ink-tinted halo (200 px diameter, 4 % opacity).
///   • White heater-shield: top corners 12 px, bottom corners elliptical
///     (horizontal 55 px, vertical 65 px) — approximated with BorderRadius.
///   • "✓" checkmark (w900) fades + scales in (200 ms delay, 400 ms).
///   • Shield scales 0.92 → 1.0 over 500 ms ease-out.
///   • 3 accent orbital dots at offsets [70,-30] [90,20] [-60,40] from centre,
///     bobbing ±3 px vertically — staggered 0/400/800 ms via single
///     controller + sine-wave phase shift.
class IllustrationShield extends StatefulWidget {
  const IllustrationShield({super.key});

  @override
  State<IllustrationShield> createState() => _IllustrationShieldState();
}

class _IllustrationShieldState extends State<IllustrationShield>
    with TickerProviderStateMixin {
  // ── entry: 800 ms ──────────────────────────────────────────────────────────
  late final AnimationController _enter;
  late final Animation<double> _shieldScale;
  late final Animation<double> _checkFade;  // fade for "✓" character
  late final Animation<double> _checkScale; // scale for "✓" character

  // ── orbital bob: single 3 s looping controller ─────────────────────────────
  late final AnimationController _dotCtrl;

  bool _started = false;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _shieldScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.0, 500 / 800, curve: Curves.easeOut),
      ),
    );

    final checkCurve = CurvedAnimation(
      parent: _enter,
      curve: const Interval(200 / 800, 700 / 800, curve: Curves.easeOut),
    );
    _checkFade  = Tween<double>(begin: 0.0, end: 1.0).animate(checkCurve);
    _checkScale = Tween<double>(begin: 0.6, end: 1.0).animate(checkCurve);

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
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
      _dotCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool rm = MediaQuery.of(context).disableAnimations;

    // Centre of the 240×240 SizedBox = (120, 120).
    const double cx = 120;
    const double cy = 120;

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        children: [
          // Halo — ink at 4 %.
          Positioned.fill(
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Shield + checkmark (scale-in).
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _enter,
              builder: (_, __) => Transform.scale(
                scale: rm ? 1.0 : _shieldScale.value,
                child: Center(
                  child: Container(
                    width: 110,
                    height: 130,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.ink, width: 1.5),
                      borderRadius: const BorderRadius.only(
                        topLeft:     Radius.circular(12),
                        topRight:    Radius.circular(12),
                        bottomLeft:  Radius.elliptical(55, 65),
                        bottomRight: Radius.elliptical(55, 65),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: rm ? 1.0 : _checkFade.value,
                      child: Transform.scale(
                        scale: rm ? 1.0 : _checkScale.value,
                        child: const Text(
                          '✓',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Orbital dots — sine-wave bob, staggered by phase.
          AnimatedBuilder(
            animation: _dotCtrl,
            builder: (_, __) {
              final double t = _dotCtrl.value * 2 * pi;
              final List<_DotSpec> specs = [
                _DotSpec(cx + 70, cy - 30, 0),
                _DotSpec(cx + 90, cy + 20, 400 / 3000),
                _DotSpec(cx - 60, cy + 40, 800 / 3000),
              ];
              return Stack(
                children: specs.map((s) {
                  final double dy = rm ? 0 : -3 * sin(t + s.phase * 2 * pi);
                  return Positioned(
                    left: s.x - 5,
                    top: s.y - 5 + dy,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 1.5),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DotSpec {
  final double x;
  final double y;
  final double phase; // fraction of 3 s period
  const _DotSpec(this.x, this.y, this.phase);
}
