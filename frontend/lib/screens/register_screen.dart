import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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
  final _appPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Dormitory zone
  String? _selectedDormitoryZone;
  final List<String> _dormitoryZones = [
    'เชียงราก',
    'อินเตอร์โซน',
    'ในมหาวิทยาลัย',
  ];

  // State
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Theme Colors (Match with Login Screen)
  final Color _primaryColor = const Color(0xFFFF6F61); // Coral Orange
  final Color _secondaryColor = const Color(0xFFF7C59F); // Peach

  // Register Logic
  void _handleRegister() async {
    if (_phoneController.text.isEmpty) {
      _showSnackBar('กรุณากรอกเบอร์โทรศัพท์', Colors.orange);
      return;
    }

    if (_appPasswordController.text.isEmpty) {
      _showSnackBar('กรุณากรอกรหัสผ่าน UniMart', Colors.orange);
      return;
    }

    if (_appPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('รหัสผ่านไม่ตรงกัน กรุณากรอกใหม่', Colors.orange);
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
      'tu_status': widget.tuProfile['tu_status'],
      'dormitory_zone': _selectedDormitoryZone,
    };

    // Call AuthService.register with app password
    final result = await AuthService.register(
      userData,
      _appPasswordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Handle Result
    if (result['success'] == true) {
      _showSuccessDialog();
    } else {
      _showSnackBar(
        result['message'] ?? 'การลงทะเบียนล้มเหลว',
        Colors.red,
      );
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
            const Text('ลงทะเบียนสำเร็จ!',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'บัญชีของคุณถูกสร้างเรียบร้อยแล้ว\nกรุณาเข้าสู่ระบบอีกครั้ง',
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              ),
              child:
                  const Text('ตกลง', style: TextStyle(color: Colors.white)),
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
    final displayName = widget.tuProfile['display_name_en'] ?? 'User';
    final tuStatus = widget.tuProfile['tu_status'];
    final showStatusWarning = tuStatus != null && tuStatus != 'ปกติ';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ลงทะเบียน',
            style:
                TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ยินดีต้อนรับ,',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            Text(
              displayName,
              style: TextStyle(
                color: _primaryColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'กรุณายืนยันข้อมูลและกรอกข้อมูลเพิ่มเติม',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // --- TU Status Warning ---
            if (showStatusWarning)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange[700]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'สถานะปัจจุบัน: $tuStatus\nคุณยังสามารถลงทะเบียนได้',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // --- Read-Only Section (TU Data) ---
            const Text('ข้อมูลนักศึกษา/บุคลากร',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            _buildReadOnlyField(Icons.badge_outlined, 'รหัสนักศึกษา',
                widget.tuProfile['username']),
            const SizedBox(height: 15),
            _buildReadOnlyField(Icons.school_outlined, 'คณะ',
                widget.tuProfile['faculty']),
            const SizedBox(height: 15),
            _buildReadOnlyField(Icons.apartment_outlined, 'ภาควิชา',
                widget.tuProfile['department']),
            if (tuStatus != null) ...[
              const SizedBox(height: 15),
              _buildReadOnlyField(
                  Icons.info_outline, 'สถานะ TU', tuStatus),
            ],

            const SizedBox(height: 30),

            // --- UniMart Password Section ---
            const Text('ตั้งรหัสผ่าน UniMart',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 5),
            const Text(
              'รหัสผ่านนี้ใช้สำหรับเข้าสู่ระบบ UniMart (แยกจากรหัส reg.tu.ac.th)',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 15),

            _buildPasswordField(
              controller: _appPasswordController,
              hintText: 'รหัสผ่าน UniMart',
              isVisible: _isPasswordVisible,
              onToggle: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            const SizedBox(height: 15),

            _buildPasswordField(
              controller: _confirmPasswordController,
              hintText: 'ยืนยันรหัสผ่าน UniMart',
              isVisible: _isConfirmPasswordVisible,
              onToggle: () => setState(
                  () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
            ),

            const SizedBox(height: 30),

            // --- Contact Info Section ---
            const Text('ข้อมูลติดต่อ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),

            _buildCustomTextField(
              controller: _phoneController,
              icon: Icons.phone_iphone_rounded,
              hintText: 'เบอร์โทรศัพท์ (จำเป็น)',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 15),

            _buildCustomTextField(
              controller: _emailController,
              icon: Icons.email_outlined,
              hintText: 'อีเมลส่วนตัว (ไม่จำเป็น)',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 30),

            // --- Dormitory Zone Section ---
            const Text('โซนหอพัก',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedDormitoryZone,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 15),
                ),
                hint: Text('เลือกโซนหอพัก',
                    style: TextStyle(color: Colors.grey[400])),
                isExpanded: true,
                items: _dormitoryZones
                    .map((zone) => DropdownMenuItem(
                          value: zone,
                          child: Text(zone),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedDormitoryZone = value);
                },
              ),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'ยืนยันการลงทะเบียน',
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

  // Widget: Password field with visibility toggle
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        decoration: InputDecoration(
          prefixIcon:
              Icon(Icons.lock_outline_rounded, color: Colors.grey[500]),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey[400],
            ),
            onPressed: onToggle,
          ),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  // Widget: Custom text field (same style as Login)
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  // Widget: Read-only field (TU data)
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
                Text(label,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500])),
                Text(
                  value ?? '-',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
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
