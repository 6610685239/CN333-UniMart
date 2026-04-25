import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Bottom navigation bar with 5 tabs: Home · Chat · Sell · Saved · Me.
///
/// The Sell button (index 2) is an accent-yellow 52×52 circle FAB that sits
/// half-overlapping above the bar. Wire via [currentIndex] + [onTap].
///
/// Usage in Scaffold:
///   bottomNavigationBar: BottomNav(currentIndex: _tab, onTap: _onTab),
///   extendBody: true,   // so content scrolls under the translucent bar
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const double _barHeight = 62;
  static const double _fabSize   = 52;
  static const double _fabOverlap = _fabSize / 2; // how far FAB extends above bar

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _barHeight + bottomPad + _fabOverlap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // ── Bar ────────────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: _barHeight + bottomPad,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.divider, width: 1),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPad),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Home',
                      active: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                    _NavItem(
                      icon: Icons.chat_bubble_outline,
                      activeIcon: Icons.chat_bubble,
                      label: 'Chat',
                      active: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                    // Centre placeholder — the FAB occupies this space.
                    const Expanded(child: SizedBox.shrink()),
                    _NavItem(
                      icon: Icons.favorite_border,
                      activeIcon: Icons.favorite,
                      label: 'Favourite',
                      active: currentIndex == 3,
                      onTap: () => onTap(3),
                    ),
                    _NavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Me',
                      active: currentIndex == 4,
                      onTap: () => onTap(4),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Sell FAB + label ───────────────────────────────────────────
          Positioned(
            top: 0,
            child: Semantics(
              label: 'Sell',
              button: true,
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _fabSize,
                      height: _fabSize,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: AppColors.ink, size: 24),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sell',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = active ? AppColors.ink : AppColors.textHint;

    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: active,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? activeIcon : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
