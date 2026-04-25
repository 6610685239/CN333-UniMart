import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../shared/theme/app_colors.dart';

TextStyle _jak({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
}) =>
    TextStyle(
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      fontFamilyFallback: const ['NotoSansThai'],
      fontSize: size,
      fontWeight: weight,
      color: color,
    );

TextStyle _mono({
  double size = 10,
  Color color = AppColors.textMuted,
  FontWeight weight = FontWeight.w500,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      letterSpacing: 0.4,
      color: color,
      fontWeight: weight,
    );

class ChangePasswordScreen extends StatefulWidget {
  final String userId;
  const ChangePasswordScreen({super.key, required this.userId});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await AuthService.changePassword(
        widget.userId, _currentCtrl.text, _newCtrl.text);
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('เปลี่ยนรหัสผ่านสำเร็จ', style: _jak(size: 13, color: AppColors.surface)),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'เกิดข้อผิดพลาด',
            style: _jak(size: 13, color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, topPad + 70, 16, 32 + bottomPad),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Password',
                    style: GoogleFonts.sriracha(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter your current password to set a new one.',
                    style: _jak(size: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 28),

                  _passwordField(
                    label: 'CURRENT PASSWORD',
                    ctrl: _currentCtrl,
                    show: _showCurrent,
                    onToggle: (v) => setState(() => _showCurrent = v),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่านปัจจุบัน' : null,
                  ),
                  const SizedBox(height: 12),
                  _passwordField(
                    label: 'NEW PASSWORD',
                    ctrl: _newCtrl,
                    show: _showNew,
                    onToggle: (v) => setState(() => _showNew = v),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่านใหม่';
                      if (v.length < 6) return 'ต้องมีอย่างน้อย 6 ตัวอักษร';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _passwordField(
                    label: 'CONFIRM NEW PASSWORD',
                    ctrl: _confirmCtrl,
                    show: _showConfirm,
                    onToggle: (v) => setState(() => _showConfirm = v),
                    validator: (v) =>
                        v != _newCtrl.text ? 'รหัสผ่านไม่ตรงกัน' : null,
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  GestureDetector(
                    onTap: _isLoading ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _isLoading
                            ? AppColors.textHint
                            : AppColors.ink,
                        borderRadius: BorderRadius.circular(14),
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
                              'Save Password',
                              style: _jak(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: AppColors.surface),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Back button
          Positioned(
            top: topPad + 12,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController ctrl,
    required bool show,
    required void Function(bool) onToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _mono(size: 10, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: TextFormField(
            controller: ctrl,
            obscureText: !show,
            validator: validator,
            style: _jak(size: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              suffixIcon: GestureDetector(
                onTap: () => onToggle(!show),
                child: Icon(
                  show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
