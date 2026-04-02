import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/review_service.dart';
import '../config.dart';
import 'my_shop_screen.dart';
import 'transaction_list_screen.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? displayName;
  final String? faculty;
  final String? tuStatus;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.displayName,
    this.faculty,
    this.tuStatus,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const Color _coral = Color(0xFFFF6F61);
  static const Color _textDark = Color(0xFF1A1F36);
  static const Color _textMid = Color(0xFF8A94A6);

  double _creditScore = 0.0;
  int _totalReviews = 0;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadCredit();
    _loadAvatar();
  }

  Future<void> _loadCredit() async {
    try {
      final data = await ReviewService.getCreditScore(widget.userId);
      if (mounted) {
        setState(() {
          _creditScore = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
          _totalReviews = data['totalReviews'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAvatar() async {
    final user = await AuthService.getUser();
    if (user != null && user['avatar'] != null && mounted) {
      setState(() => _avatarUrl = '${AppConfig.uploadsUrl}/${user['avatar']}');
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final request = http.MultipartRequest(
      'POST', Uri.parse('${AppConfig.baseUrl}/auth/${widget.userId}/avatar'));
    request.files.add(http.MultipartFile.fromBytes('avatar', bytes, filename: picked.name));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newAvatar = data['avatar'];
      // Update local storage
      final user = await AuthService.getUser();
      if (user != null) {
        user['avatar'] = newAvatar;
        await AuthService.saveUser(user);
      }
      if (mounted) {
        setState(() => _avatarUrl = '${AppConfig.uploadsUrl}/$newAvatar');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตรูปโปรไฟล์แล้ว'), backgroundColor: Colors.green));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName ?? 'ไม่ระบุชื่อ';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // ── Avatar + Name ──
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: _coral.withOpacity(0.12),
                    backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null
                      ? Text(initial, style: TextStyle(
                          fontSize: 38, fontWeight: FontWeight.bold, color: _coral))
                      : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: _coral, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: _textDark)),
            if (widget.faculty != null && widget.faculty!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.faculty!, style: TextStyle(fontSize: 13, color: _textMid)),
              ),
            if (widget.tuStatus != null && widget.tuStatus!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.tuStatus == 'ปกติ' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('สถานะ: ${widget.tuStatus}', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: widget.tuStatus == 'ปกติ' ? Colors.green : Colors.orange)),
                ),
              ),

            const SizedBox(height: 20),
            // ── Credit Score Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 36),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _creditScore > 0 ? _creditScore.toStringAsFixed(1) : '-',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                          color: _creditScore > 0 ? Colors.amber[800] : _textMid),
                      ),
                      Text('Credit Score จาก $_totalReviews รีวิว',
                        style: TextStyle(fontSize: 12, color: _textMid)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Menu Items ──
            _tile(Icons.storefront_outlined, 'ร้านของฉัน', 'ดูสินค้าที่ลงขาย/ให้เช่า', () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MyShopScreen(currentUserId: widget.userId)));
            }),
            _tile(Icons.receipt_long_outlined, 'ธุรกรรม', 'ประวัติการซื้อขายทั้งหมด', () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => TransactionListScreen(userId: widget.userId)));
            }),
            _tile(Icons.notifications_outlined, 'การแจ้งเตือน', 'ตั้งค่าการแจ้งเตือน', null),
            _tile(Icons.lock_outline, 'เปลี่ยนรหัสผ่าน', 'รหัสผ่าน UniMart', () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChangePasswordScreen(userId: widget.userId)));
            }),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ── Log out ──
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  await AuthService.logout();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false);
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('ออกจากระบบ', style: TextStyle(
                  color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback? onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: _coral.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _coral, size: 22),
      ),
      title: Text(title, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, color: _textDark)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: _textMid)),
      trailing: const Icon(Icons.chevron_right, color: _textMid),
      onTap: onTap,
    );
  }
}
