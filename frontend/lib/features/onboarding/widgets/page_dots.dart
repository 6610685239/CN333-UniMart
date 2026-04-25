import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';

/// Unified page-indicator shared across Splash and Onboarding.
///
/// • [pageController] == null → splash mode: three white 6 px circles with a
///   breathing opacity loop (0.25 ↔ 0.50, 1.6 s ease-in-out).
/// • [pageController] != null → onboarding mode: an 18×6 ink pill tracks the
///   fractional scroll position. On first mount the pill expands from 6 px to
///   18 px over 300 ms (splash → onb1 entry transition).
///
/// Respects [MediaQueryData.disableAnimations].
class PageDots extends StatefulWidget {
  final PageController? pageController;
  const PageDots({super.key, this.pageController});

  @override
  State<PageDots> createState() => _PageDotsState();
}

class _PageDotsState extends State<PageDots> with TickerProviderStateMixin {
  // ── constants ──────────────────────────────────────────────────────────────
  static const double _dotD   = 6.0;
  static const double _dotGap = 6.0;  // matches wireframe gap: 6
  static const double _step   = _dotD + _dotGap; // 12 px centre-to-centre
  static const double _pillW  = 18.0;
  static const double _pillH  = 6.0;
  static const double _pillR  = 4.0;
  static const int    _count  = 3;
  static const double _pad    = (_pillW - _dotD) / 2; // 6 px overflow padding

  // ── controllers ────────────────────────────────────────────────────────────
  late final AnimationController _breathe;
  late final Animation<double>   _breatheOpacity;

  late final AnimationController _expand;
  late final Animation<double>   _pillWidth;

  @override
  void initState() {
    super.initState();

    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _breatheOpacity = Tween<double>(begin: 0.25, end: 0.50).animate(
      CurvedAnimation(parent: _breathe, curve: Curves.easeInOut),
    );

    _expand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pillWidth = Tween<double>(begin: _dotD, end: _pillW).animate(
      CurvedAnimation(parent: _expand, curve: Curves.easeOutCubic),
    );
    // NOTE: _syncAnimations() is NOT called here — MediaQuery requires context,
    // which is unavailable during initState. Called in didChangeDependencies.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(PageDots old) {
    super.didUpdateWidget(old);
    final bool wasOnb = old.pageController != null;
    final bool isOnb  = widget.pageController != null;

    if (!wasOnb && isOnb) {
      _breathe.stop();
      _expand.forward(from: 0);
    } else if (wasOnb && !isOnb) {
      _expand.reverse();
      _syncAnimations();
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    _expand.dispose();
    super.dispose();
  }

  void _syncAnimations() {
    final bool rm      = MediaQuery.of(context).disableAnimations;
    final bool isSplash = widget.pageController == null;

    if (isSplash) {
      if (rm) {
        _breathe.stop();
      } else if (!_breathe.isAnimating) {
        _breathe.repeat(reverse: true);
      }
    } else {
      _breathe.stop();
      if (rm) {
        _expand.value = 1.0;
      } else if (!_expand.isAnimating && !_expand.isCompleted) {
        _expand.forward();
      }
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool rm = MediaQuery.of(context).disableAnimations;
    return widget.pageController == null
        ? _buildSplash(rm)
        : _buildOnboarding(rm);
  }

  // Splash: three white circles, breathing opacity.
  Widget _buildSplash(bool rm) {
    if (rm) return _staticRow(opacity: 0.35);
    return AnimatedBuilder(
      animation: _breatheOpacity,
      builder: (_, __) => _staticRow(opacity: _breatheOpacity.value),
    );
  }

  Widget _staticRow({required double opacity}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_count, (i) => Padding(
        padding: EdgeInsets.only(right: i < _count - 1 ? _dotGap : 0),
        child: Opacity(
          opacity: opacity,
          child: _circle(_dotD, AppColors.surface),
        ),
      )),
    );
  }

  // Onboarding: ink pill tracks PageController.page (fractional).
  Widget _buildOnboarding(bool rm) {
    const double rowW  = (_count - 1) * _step + _dotD; // 30 px
    const double totalW = rowW + _pad * 2;              // 42 px

    return AnimatedBuilder(
      animation: Listenable.merge([widget.pageController!, _expand]),
      builder: (_, __) {
        final double page = widget.pageController!.hasClients
            ? (widget.pageController!.page ?? 0.0)
            : 0.0;

        final double curPillW   = rm ? _pillW : _pillWidth.value;
        final double dotCentreX = _pad + page * _step + _dotD / 2;
        final double pillLeft   = dotCentreX - curPillW / 2;

        return SizedBox(
          width: totalW,
          height: _pillH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Inactive dots
              Positioned(
                left: _pad,
                top: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_count, (i) => Padding(
                    padding: EdgeInsets.only(right: i < _count - 1 ? _dotGap : 0),
                    child: _circle(_dotD, AppColors.border),
                  )),
                ),
              ),
              // Active pill — position driven by fractional scroll.
              Positioned(
                left: pillLeft,
                top: 0,
                child: Container(
                  width: curPillW,
                  height: _pillH,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(_pillR),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
