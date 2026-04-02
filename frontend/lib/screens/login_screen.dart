import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../pages/favourite_manager.dart';
import 'register_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isPasswordVisible = false;

  // Theme Colors (Orange/Pink Gradient)
  final Color _primaryColor = const Color(0xFFFF6F61); // Coral Orange
  final Color _secondaryColor = const Color(0xFFF7C59F); // Peach

  // Login Logic — verify via TU API, then handle action
  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('กรุณากรอกข้อมูลให้ครบ', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    // Call AuthService.verify (TU API)
    final result = await AuthService.verify(username, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final action = result['action'];

      if (action == 'GO_TO_REGISTER') {
        // Navigate to Register Screen with TU profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RegisterScreen(tuProfile: result['tuProfile']),
          ),
        );
      } else if (action == 'LOGIN_EXISTS') {
        // User already registered — ask for UniMart password
        _showUnimartPasswordDialog(username);
      }
    } else {
      // Error from verify (TU API failure, wrong credentials, 503, etc.)
      final message = result['message'] ?? 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
      _showSnackBar(message, Colors.red);
    }
  }

  /// Show dialog to enter UniMart password for existing users
  void _showUnimartPasswordDialog(String username) {
    final unimartPasswordController = TextEditingController();
    bool isDialogPasswordVisible = false;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'เข้าสู่ระบบ UniMart',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'กรุณากรอกรหัสผ่าน UniMart ของคุณ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: unimartPasswordController,
                      obscureText: !isDialogPasswordVisible,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.grey[500],
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isDialogPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey[400],
                          ),
                          onPressed: () {
                            setDialogState(() {
                              isDialogPasswordVisible =
                                  !isDialogPasswordVisible;
                            });
                          },
                        ),
                        hintText: 'รหัสผ่าน UniMart',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          final unimartPassword =
                              unimartPasswordController.text.trim();
                          if (unimartPassword.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('กรุณากรอกรหัสผ่าน'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isDialogLoading = true);

                          final loginResult = await AuthService.login(
                            username,
                            unimartPassword,
                          );

                          if (!mounted) return;
                          setDialogState(() => isDialogLoading = false);

                          if (loginResult['success'] == true) {
                            // Init FavouriteManager with logged-in user
                            await FavouriteManager.instance.init();
                            if (!mounted) return;
                            Navigator.pop(dialogContext); // Close dialog
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MainScreen(user: loginResult['user']),
                              ),
                            );
                          } else {
                            final msg = loginResult['message'] ??
                                'รหัสผ่านไม่ถูกต้อง';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: isDialogLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'เข้าสู่ระบบ',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Stack(
            children: [
              // Main Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Logo Section ---
                    Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.shopping_bag_outlined,
                            size: 100,
                            color: _primaryColor,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Tagline ---
                    const Text(
                      '"Buy • Sell • Trade within your campus"',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 50),

                    // --- Username Field ---
                    _buildCustomTextField(
                      controller: _usernameController,
                      icon: Icons.person_outline_rounded,
                      hintText: 'รหัสนักศึกษา',
                    ),
                    const SizedBox(height: 20),

                    // --- Password Field (TU reg.tu.ac.th password) ---
                    _buildCustomTextField(
                      controller: _passwordController,
                      icon: Icons.lock_outline_rounded,
                      hintText: 'รหัสผ่าน reg.tu.ac.th',
                      isPassword: true,
                    ),

                    const SizedBox(height: 10),

                    // --- Remember Me ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: _primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (value) =>
                                  setState(() => _rememberMe = value!),
                            ),
                            const Text(
                              'จดจำฉัน',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // --- Login Button (Gradient) ---
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_secondaryColor, _primaryColor],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'เข้าสู่ระบบ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widget for Custom Text Field ---
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[500]),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey[400],
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                )
              : null,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
      ),
    );
  }
}
