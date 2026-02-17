import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  final Map<String, dynamic> tuProfile;

  const RegisterScreen({super.key, required this.tuProfile});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  // State
  bool _isLoading = false;

  // Theme Colors (Match with Login Screen)
  final Color _primaryColor = const Color(0xFFFF6F61); // Coral Orange
  final Color _secondaryColor = const Color(0xFFF7C59F); // Peach

  // Register Logic
  void _handleRegister() async {
    if (_phoneController.text.isEmpty) {
      _showSnackBar('Please enter your phone number', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    // Prepare Data
    final userData = {
      'phone_number': _phoneController.text.trim(),
      'personal_email': _emailController.text.trim(),
      'username': widget.tuProfile['username'],
      'tu_email': widget.tuProfile['email'],
      'display_name_th': widget.tuProfile['display_name_th'],
      'display_name_en': widget.tuProfile['display_name_en'],
      'faculty': widget.tuProfile['faculty'],
      'department': widget.tuProfile['department'],
      'user_type': widget.tuProfile['type'],
    };

    // Call API
    final result = await ApiService.registerUser(userData);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Handle Result
    if (result['success'] == true) {
      _showSuccessDialog();
    } else {
      _showSnackBar(result['message'] ?? 'Registration failed', Colors.red);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 10),
            const Text('Success!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Your account has been successfully created.\nPlease login again to continue.',
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Back to Login Screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ดึงชื่อภาษาอังกฤษมาแสดง (ถ้าไม่มีใช้ "User")
    final displayName = widget.tuProfile['display_name_en'] ?? 'User';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Activate Account', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome,', style: TextStyle(color: Colors.grey, fontSize: 16)),
            Text(
              displayName,
              style: TextStyle(
                color: _primaryColor, 
                fontSize: 22, 
                fontWeight: FontWeight.bold,
                height: 1.2
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Please confirm your details and provide contact info.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 30),

            // --- Read-Only Section (TU Data) ---
            const Text('Student/Staff Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            _buildReadOnlyField(Icons.badge_outlined, 'Student ID', widget.tuProfile['username']),
            const SizedBox(height: 15),
            _buildReadOnlyField(Icons.school_outlined, 'Faculty', widget.tuProfile['faculty']),
            
            const SizedBox(height: 30),

            // --- Input Section (Contact Info) ---
            const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),

            _buildCustomTextField(
              controller: _phoneController,
              icon: Icons.phone_iphone_rounded,
              hintText: 'Phone Number (Required)',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 15),
            
            _buildCustomTextField(
              controller: _emailController,
              icon: Icons.email_outlined,
              hintText: 'Personal Email (Optional)',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 40),

            // --- Confirm Button (Gradient) ---
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
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'CONFIRM REGISTRATION',
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget: ช่องกรอกข้อมูล (เหมือนหน้า Login)
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[500]),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  // Widget: ช่องแสดงข้อมูล (แก้ไขไม่ได้)
  Widget _buildReadOnlyField(IconData icon, String label, String? value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400]),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                Text(
                  value ?? '-', 
                  style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
        ],
      ),
    );
  }
}