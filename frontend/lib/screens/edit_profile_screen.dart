import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/auth_service.dart';
import '../shared/theme/app_colors.dart';

// ── Typography ────────────────────────────────────────────────────────────────

TextStyle _jak({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double? height,
}) =>
    TextStyle(
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      fontFamilyFallback: const ['NotoSansThai'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

TextStyle _mono({
  double size = 9,
  Color color = AppColors.textMuted,
  FontWeight weight = FontWeight.w500,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      letterSpacing: 0.4,
      color: color,
      fontWeight: weight,
    );

// ── Screen ────────────────────────────────────────────────────────────────────

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

  static const _dormZones = ['เชียงราก', 'อินเตอร์โซน', 'ในมหาวิทยาลัย'];

  @override
  void initState() {
    super.initState();
    _phoneController =
        TextEditingController(text: widget.user['phone_number'] ?? '');
    _emailController =
        TextEditingController(text: widget.user['personal_email'] ?? '');
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
      _snack('กรุณากรอกเบอร์โทรศัพท์');
      return;
    }

    final userId = widget.user['id'];
    if (userId == null) {
      _snack('ไม่พบข้อมูลผู้ใช้ กรุณา login ใหม่');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();
      final url =
          Uri.parse('${AppConfig.baseUrl}/auth/$userId/profile');
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'phone_number': phone,
          'personal_email': _emailController.text.trim(),
          'dormitory_zone': _selectedDormitoryZone,
        }),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode != 200) {
        _snack('HTTP ${response.statusCode}: ${response.body}');
        return;
      }
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final updated = Map<String, dynamic>.from(widget.user)
          ..['phone_number'] = phone
          ..['personal_email'] = _emailController.text.trim()
          ..['dormitory_zone'] = _selectedDormitoryZone;
        await AuthService.saveUser(updated);
        if (mounted) Navigator.pop(context, updated);
      } else {
        _snack(data['message'] ?? 'เกิดข้อผิดพลาด');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Error: $e');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: _jak(size: 13, color: Colors.white)),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.border, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Profile',
                    style: GoogleFonts.sriracha(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── TU Info (read-only) ──────────────────────────────
                    _sectionLabel('TU Information', locked: true),
                    const SizedBox(height: 10),
                    _readOnlyCard([
                      _ReadOnlyRow(
                        icon: Icons.badge_outlined,
                        label: 'Student ID',
                        value: widget.user['username'] ?? '-',
                      ),
                      _ReadOnlyRow(
                        icon: Icons.person_outline,
                        label: 'Name',
                        value: widget.user['display_name_th'] ??
                            widget.user['display_name_en'] ??
                            '-',
                      ),
                      _ReadOnlyRow(
                        icon: Icons.school_outlined,
                        label: 'Faculty',
                        value: widget.user['faculty'] ?? '-',
                        last: true,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Editable ─────────────────────────────────────────
                    _sectionLabel('Your Details'),
                    const SizedBox(height: 10),

                    _inputField(
                      controller: _phoneController,
                      icon: Icons.phone_iphone_rounded,
                      label: 'Phone number',
                      hint: '08x-xxx-xxxx',
                      keyboard: TextInputType.phone,
                      required: true,
                    ),
                    const SizedBox(height: 10),

                    _inputField(
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      label: 'Personal email',
                      hint: 'Optional',
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),

                    // Dormitory zone picker
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(14, 10, 14, 4),
                            child: Text('Dormitory zone',
                                style: _mono(
                                    size: 10,
                                    color: AppColors.textMuted,
                                    weight: FontWeight.w600)),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(10, 0, 10, 4),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedDormitoryZone,
                                isExpanded: true,
                                hint: Text('Select zone',
                                    style: _jak(
                                        size: 14,
                                        color: AppColors.textHint)),
                                style: _jak(size: 14, color: AppColors.ink),
                                dropdownColor: AppColors.surface,
                                icon: const Icon(Icons.keyboard_arrow_down,
                                    size: 20, color: AppColors.textMuted),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text('— ไม่ระบุ —',
                                        style: _jak(
                                            size: 14,
                                            color: AppColors.textHint)),
                                  ),
                                  ..._dormZones.map(
                                    (z) => DropdownMenuItem(
                                      value: z,
                                      child: Text(z),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedDormitoryZone = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Save button ───────────────────────────────────────
                    GestureDetector(
                      onTap: _isLoading ? null : _handleSave,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _isLoading
                              ? AppColors.border
                              : AppColors.ink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save changes',
                                style: _jak(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: AppColors.surface,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, {bool locked = false}) {
    return Row(
      children: [
        Text(text,
            style: _jak(size: 13, weight: FontWeight.w700,
                color: AppColors.ink)),
        if (locked) ...[
          const SizedBox(width: 6),
          const Icon(Icons.lock_outline, size: 13, color: AppColors.textMuted),
        ],
      ],
    );
  }

  // ── Read-only card ─────────────────────────────────────────────────────────

  Widget _readOnlyCard(List<_ReadOnlyRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: rows.map((r) {
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(r.icon, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.label,
                              style: _mono(
                                  size: 9,
                                  color: AppColors.textMuted,
                                  weight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(r.value,
                              style: _jak(
                                  size: 14,
                                  weight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!r.last)
                Divider(height: 1, color: AppColors.divider,
                    indent: 44, endIndent: 0),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Input field ────────────────────────────────────────────────────────────

  Widget _inputField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    bool required = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Text(label,
                    style: _mono(
                        size: 10,
                        color: AppColors.textMuted,
                        weight: FontWeight.w600)),
                if (required)
                  Text(' *',
                      style: _mono(
                          size: 10,
                          color: AppColors.accent,
                          weight: FontWeight.w700)),
              ],
            ),
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(icon, size: 18, color: AppColors.textMuted),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboard,
                  style: _jak(size: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle:
                        _jak(size: 14, color: AppColors.textHint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(10, 6, 14, 12),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Read-only row data ─────────────────────────────────────────────────────────

class _ReadOnlyRow {
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });
}
