import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';
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

  // Login Logic
  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    // Call API
    final result = await ApiService.verifyUser(username, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Handle Result
    if (result['success'] == true) {
      final action = result['action'];

      if (action == 'GO_TO_REGISTER') {
        // Navigate to Register Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RegisterScreen(tuProfile: result['tuProfile']),
          ),
        );
      } else if (action == 'LOGIN_SUCCESS') {
        // Login Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login Successful!'),
            backgroundColor: Colors.green,
          ),
        );

        // String safeUserId = result['user']['id'].toString();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MainScreen(user: result['user']),
          ),
        );
      }
    } else {
      // Error
      _showSnackBar(result['message'] ?? 'An error occurred', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
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
                        'assets/images/logo.png', // ✅ Load logo.png
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback icon if image is missing
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
                      hintText: 'Username',
                    ),
                    const SizedBox(height: 20),

                    // --- Password Field ---
                    _buildCustomTextField(
                      controller: _passwordController,
                      icon: Icons.lock_outline_rounded,
                      hintText: 'Password',
                      isPassword: true,
                    ),

                    const SizedBox(height: 10),

                    // --- Remember Me & Forgot Password ---
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
                              'Remember Me',
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
                                'LOGIN',
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
