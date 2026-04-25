import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../pages/favourite_manager.dart';
import '../shared/theme/app_colors.dart';
import 'main_screen.dart';

// ── Typography ─────────────────────────────────────────────────────────────────
// Plus Jakarta Sans — body labels, inputs, trust banner (sub for Inter)
// JetBrains Mono   — field eyebrow labels
// Kalam            — wordmark (sketchy drop-cap display)

TextStyle _jak({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double letterSpacing = 0,
  double? height,
}) =>
    TextStyle(
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      fontFamilyFallback: const ['NotoSansThai'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

TextStyle _mono({
  double size = 11,
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.ink,
  double letterSpacing = 0.3,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

// ── Screen ─────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('กรุณากรอกข้อมูลให้ครบ', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService.login(username, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      await FavouriteManager.instance.init();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(user: result['user']),
        ),
      );
    } else {
      final message = result['message'] ?? 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
      _showSnackBar(message, Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: _jak(size: 13, color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Decorative circles — top-right, behind content
          _buildCircles(),
          // Main content
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                _buildWordmark(),
                const Spacer(flex: 3),
                _buildForm(),
                const Spacer(flex: 3),
                _buildBottom(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Zone 3 · Decorative circles ─────────────────────────────────────────────

  Widget _buildCircles() {
    return Stack(
      children: [
        // Outer: 300×300
        Positioned(
          top: -60,
          right: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentSoft,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
          ),
        ),
        // Inner: 130×130
        Positioned(
          top: 20,
          right: -6,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.13),
            ),
          ),
        ),
      ],
    );
  }

  // ── Zone 2 · Wordmark ───────────────────────────────────────────────────────

  Widget _buildWordmark() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 32, 26, 0),
      child: RichText(
        text: TextSpan(
          children: [
            // Drop-cap U — 80px
            TextSpan(
              text: 'U',
              style: GoogleFonts.caveat(
                fontSize: 80,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -1.5,
                height: 1,
              ),
            ),
            // nimart — 54px
            TextSpan(
              text: 'nimart',
              style: GoogleFonts.caveat(
                fontSize: 54,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -1.5,
                height: 1,
              ),
            ),
            // . — 54px accent
            TextSpan(
              text: '.',
              style: GoogleFonts.caveat(
                fontSize: 54,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: -1.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Zone 4 · Form ───────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Eyebrow
          Text(
            'Sign in to your account',
            style: _jak(size: 15, color: AppColors.textMuted, letterSpacing: 0.2),
          ),
          const SizedBox(height: 28),

          // Student ID field
          _fieldLabel('STUDENT ID'),
          const SizedBox(height: 9),
          _inputCard(
            controller: _usernameController,
            icon: '🎓',
            hint: 'e.g. 6612345678',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),

          // Password field
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _fieldLabel('PASSWORD'),
              const Spacer(),
              Text(
                'reg.tu.ac.th password',
                style: _mono(size: 10, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _inputCard(
            controller: _passwordController,
            icon: '🔒',
            hint: '••••••••',
            obscure: !_isPasswordVisible,
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
              child: Icon(
                _isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Remember me
          GestureDetector(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            child: Row(
              children: [
                _toggle(_rememberMe),
                const SizedBox(width: 10),
                Text('Remember me',
                    style: _jak(size: 14, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 26),

          // TU trust banner
          _buildTrustBanner(),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(label, style: _mono(size: 13, weight: FontWeight.w700));
  }

  Widget _inputCard({
    required TextEditingController controller,
    required String icon,
    required String hint,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon square
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.33),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: _jak(size: 16),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: _jak(size: 16, color: AppColors.textHint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 8),
            suffix,
          ],
        ],
      ),
    );
  }

  Widget _toggle(bool on) {
    return Container(
      width: 46,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: on ? AppColors.accent : AppColors.border,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ink,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.33),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Check badge
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ink,
            ),
            alignment: Alignment.center,
            child: Text(
              '✓',
              style: _jak(size: 15, weight: FontWeight.w700, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: _jak(size: 13, height: 1.4),
                children: const [
                  TextSpan(text: 'Verified through '),
                  TextSpan(
                    text: 'Thammasat University',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' — TU students only'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Zone 5 · Button + footer ────────────────────────────────────────────────

  Widget _buildBottom() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(26, 0, 26, 32 + bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Log in button
          GestureDetector(
            onTap: _isLoading ? null : _handleLogin,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: _isLoading ? AppColors.textHint : AppColors.ink,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      'Log in',
                      style: _jak(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Footer
          Center(
            child: Text(
              'CN333 · Thammasat University',
              style: _jak(size: 10, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }
}
