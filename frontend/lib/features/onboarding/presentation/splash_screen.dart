import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/theme/app_colors.dart';
import '../widgets/page_dots.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Entrance: fade + 8 px rise, 500 ms ease-out.
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  // Period pulse on the accent dot: scale 1.0 ↔ 1.15, 1.4 s ease-in-out loop.
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;

  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _rise = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
    );

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final bool rm = MediaQuery.of(context).disableAnimations;
    if (rm) {
      _entrance.value = 1.0;
    } else {
      _entrance.forward();
      _pulse.repeat(reverse: true);
    }

    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      // TODO Step 5: replace with context.go('/onboarding')
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Stack(
          children: [
            Center(child: _wordmarkBlock()),
            Positioned(
              bottom: 44,
              left: 0,
              right: 0,
              child: const Center(child: PageDots()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wordmarkBlock() {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(offset: Offset(0, _rise.value), child: child),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_wordmark(), const SizedBox(height: 12), _tagline()],
      ),
    );
  }

  // Unimart. — 44 / w700 / ls -1.5 with accent period pulsing.
  Widget _wordmark() {
    final TextStyle base = GoogleFonts.caveat(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.5,
      color: AppColors.surface,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('Unimart', style: base),
        AnimatedBuilder(
          animation: _pulseScale,
          builder: (_, child) => Transform.scale(
            scale: _pulseScale.value,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
          child: Text('.', style: base.copyWith(color: AppColors.accent)),
        ),
      ],
    );
  }

  // Tagline — mono, 9 px, ls 1.8, uppercase, half-opacity.
  Widget _tagline() {
    return Opacity(
      opacity: 0.5,
      child: Text(
        'BUY \u00B7 SELL \u00B7 RENT WITHIN YOUR CAMPUS',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.8,
          color: AppColors.surface,
        ),
      ),
    );
  }
}
