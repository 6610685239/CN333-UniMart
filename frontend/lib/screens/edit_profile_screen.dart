import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  String? _selectedDormitoryZone;

  bool _isLoading = false;

  final Color _primaryColor = const Color(0xFFFF6F61);
  final Color _secondaryColor = const Color(0xFFF7C59F);

  final List<String> _dormitoryZones = ['เชียงราก', 'อินเตอร์โซน', 'ในมหาวิทยาลัย'];

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.user['phone_number'] ?? '');
    _emailController = TextEditingController(text: widget.user['personal_email'] ?? '');
    _selectedDormitoryZone = widget.user['dormitory_zone'];
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar('กรุณากรอกเบอร์โทรศัพท์', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/auth/${widget.user['id']}/profile');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phone,
          'personal_email': _emailController.text.trim(),
          'dormitory_zone': _selectedDormitoryZone,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (data['success'] == true) {
        // Update local user data
        final updatedUser = Map<String, dynamic>.from(widget.user);
        updatedUser['phone_number'] = phone;
        updatedUser['personal_email'] = _emailController.text.trim();
        updatedUser['dormitory_zone'] = _selectedDormitoryZone;
        await AuthService.saveUser(updatedUser);

        _showSnackBar('อัปเดตข้อมูลสำเร็จ', Colors.green);
        if (mounted) Navigator.pop(context, updatedUser);
      } else {
        _showSnackBar(data['message'] ?? 'เกิดข้อผิดพลาด', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('เชื่อมต่อ Server ไม่ได้', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('แก้ไขโปรไฟล์',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Read-only TU info
            const Text('ข้อมูลจาก TU (แก้ไขไม่ได้)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            _buildReadOnly(Icons.badge_outlined, 'รหัสนักศึกษา', widget.user['username']),
            const SizedBox(height: 10),
            _buildReadOnly(Icons.person_outline, 'ชื่อ-นามสกุล',
                widget.user['display_name_th'] ?? widget.user['display_name_en']),
            const SizedBox(height: 10),
            _buildReadOnly(Icons.school_outlined, 'คณะ', widget.user['faculty']),

            const SizedBox(height: 28),

            // Editable info
            const Text('ข้อมูลที่แก้ไขได้',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _phoneController,
              icon: Icons.phone_iphone_rounded,
              hint: 'เบอร์โทรศัพท์ (จำเป็น)',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _emailController,
              icon: Icons.email_outlined,
              hint: 'อีเมลส่วนตัว (ไม่จำเป็น)',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedDormitoryZone,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                hint: Text('เลือกโซนหอพัก', style: TextStyle(color: Colors.grey[400])),
                isExpanded: true,
                items: _dormitoryZones
                    .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedDormitoryZone = v),
              ),
            ),

            const SizedBox(height: 36),

            // Save button
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
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'บันทึก',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
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
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildReadOnly(IconData icon, String label, String? value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text(value ?? '-',
                    style: const TextStyle(fontSize: 15, color: Colors.black87)),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}

