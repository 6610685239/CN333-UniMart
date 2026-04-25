import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../widgets/page_dots.dart';
import '../widgets/illustration_card.dart';
import '../widgets/illustration_shield.dart';
import '../widgets/illustration_chat.dart';
import '../../../screens/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  static const _pages = [
    _PageData(
      title: 'Browse the campus market',
      subtitle:
          'Find books, bikes, and everything in between all from verified TU students.',
    ),
    _PageData(
      title: 'Safe. Verified. TU only.',
      subtitle:
          'Every account is checked against a TU email. No strangers, no scams just your campus community.',
    ),
    _PageData(
      title: 'Chat. Meet. Done.',
      subtitle:
          'Message sellers in-app and meet up anywhere on campus no phone numbers needed.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onScroll);
  }

  void _onScroll() {
    final int p = (_pageController.page ?? 0).round();
    if (p != _currentPage) setState(() => _currentPage = p);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    _pageController.animateToPage(
      _currentPage + 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _goToLogin() {
    // TODO Step 5: replace with context.go('/auth/login')
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _skipRow(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                children: [
                  _PageContent(
                    illustration: const IllustrationCard(),
                    data: _pages[0],
                  ),
                  _PageContent(
                    illustration: const IllustrationShield(),
                    data: _pages[1],
                  ),
                  _PageContent(
                    illustration: const IllustrationChat(),
                    data: _pages[2],
                  ),
                ],
              ),
            ),
            _bottomRow(),
          ],
        ),
      ),
    );
  }

  Widget _skipRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 24, bottom: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Semantics(
          label: 'Skip onboarding',
          button: true,
          child: GestureDetector(
            onTap: _goToLogin,
            child: Text(
              'Skip',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: Row(
        children: [
          PageDots(pageController: _pageController),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _currentPage < 2 ? _nextFab() : _getStartedPill(),
          ),
        ],
      ),
    );
  }

  Widget _nextFab() {
    return Semantics(
      label: 'Next',
      button: true,
      child: GestureDetector(
        key: const ValueKey('fab'),
        onTap: _next,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_forward,
              color: AppColors.surface, size: 20),
        ),
      ),
    );
  }

  Widget _getStartedPill() {
    return Semantics(
      label: 'Get started',
      button: true,
      child: GestureDetector(
        key: const ValueKey('pill'),
        onTap: _goToLogin,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            'Get started',
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared page layout ────────────────────────────────────────────────────────

class _PageData {
  final String title;
  final String subtitle;
  const _PageData({required this.title, required this.subtitle});
}

class _PageContent extends StatelessWidget {
  final Widget illustration;
  final _PageData data;

  const _PageContent({required this.illustration, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(child: Center(child: illustration)),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.caveat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              height: 1.15,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
