import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../models/product.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';

// ── Typography ────────────────────────────────────────────────────────────────

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
  FontWeight weight = FontWeight.w600,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      letterSpacing: 0.3,
      color: color,
      fontWeight: weight,
    );

// ── Screen ────────────────────────────────────────────────────────────────────

class EditProductScreen extends StatefulWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _locationCtrl;
  late String _selectedCondition;
  bool _isSubmitting = false;

  static const _conditions = ['มือหนึ่ง', 'มือสอง (สภาพดี)', 'มือสอง (มีตำหนิ)'];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.product.title);
    _descCtrl = TextEditingController(text: widget.product.description);
    _priceCtrl = TextEditingController(
      text: widget.product.type == 'RENT'
          ? widget.product.rentPrice.toStringAsFixed(0)
          : widget.product.price.toStringAsFixed(0),
    );
    _quantityCtrl =
        TextEditingController(text: widget.product.quantity.toString());
    _locationCtrl = TextEditingController(text: widget.product.location);
    _selectedCondition = widget.product.condition;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final url =
          Uri.parse('${ApiService.baseUrl}/products/${widget.product.id}');
      final Map<String, dynamic> body = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'condition': _selectedCondition,
        'location': _locationCtrl.text.trim(),
      };
      if (widget.product.type == 'SALE') {
        body['price'] = _priceCtrl.text.trim();
        body['quantity'] = _quantityCtrl.text.trim();
      } else {
        body['rentPrice'] = _priceCtrl.text.trim();
      }
      final res = await http.patch(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body));
      if (!mounted) return;
      if (res.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        _snack('Could not save changes');
      }
    } catch (_) {
      _snack('Something went wrong');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                children: [
                  // ── Title ──
                  _label('Title'),
                  const SizedBox(height: 6),
                  _input(
                    ctrl: _titleCtrl,
                    hint: 'Product title',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Price + Qty ──
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(widget.product.type == 'RENT'
                                ? 'Rent price (฿/day)'
                                : 'Price (฿)'),
                            const SizedBox(height: 6),
                            _input(
                              ctrl: _priceCtrl,
                              hint: '0',
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                          ],
                        ),
                      ),
                      if (widget.product.type == 'SALE') ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Qty / stock'),
                              const SizedBox(height: 6),
                              _QuantityStepper(controller: _quantityCtrl),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Condition ──
                  _label('Condition'),
                  const SizedBox(height: 8),
                  _buildConditionChips(),
                  const SizedBox(height: 14),

                  // ── Description ──
                  _label('Description'),
                  const SizedBox(height: 6),
                  _input(
                    ctrl: _descCtrl,
                    hint: 'Describe your item…',
                    maxLines: 4,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Meeting point ──
                  _label('Meeting point'),
                  const SizedBox(height: 6),
                  _input(
                    ctrl: _locationCtrl,
                    hint: 'e.g. SC Building Lobby, Dome Canteen',
                  ),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 56,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit listing',
            style: GoogleFonts.sriracha(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.1,
            ),
          ),
          Text(
            widget.product.type == 'SALE' ? 'For sale' : 'For rent',
            style: _mono(size: 10, color: AppColors.textMuted),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.divider),
      ),
    );
  }

  // ── Condition chips ───────────────────────────────────────────────────────

  Widget _buildConditionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _conditions.map((c) {
        final sel = c == _selectedCondition;
        return GestureDetector(
          onTap: () => setState(() => _selectedCondition = c),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.accent : AppColors.bg,
              border: Border.all(color: AppColors.ink, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              c,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: GestureDetector(
          onTap: _isSubmitting ? null : _save,
          child: Container(
            decoration: BoxDecoration(
              color: _isSubmitting ? AppColors.textHint : AppColors.ink,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Save changes',
                    style: AppTextStyles.body.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
        text,
        style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted, fontWeight: FontWeight.w600),
      );

  Widget _input({
    required TextEditingController ctrl,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return _FieldBox(
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: AppTextStyles.bodyS.copyWith(color: AppColors.ink),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppTextStyles.bodyS.copyWith(color: AppColors.textHint),
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

// ── Quantity stepper ──────────────────────────────────────────────────────────

class _QuantityStepper extends StatefulWidget {
  final TextEditingController controller;
  const _QuantityStepper({required this.controller});

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _qty = int.tryParse(widget.controller.text) ?? 1;
  }

  void _change(int delta) {
    final next = (_qty + delta).clamp(0, 999);
    setState(() => _qty = next);
    widget.controller.text = '$next';
  }

  @override
  Widget build(BuildContext context) {
    return _FieldBox(
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            _StepBtn(icon: '−', onTap: () => _change(-1)),
            Expanded(
              child: Center(
                child: Text(
                  '$_qty',
                  style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
            ),
            _StepBtn(icon: '+', onTap: () => _change(1)),
          ],
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: double.infinity,
        child: Center(
          child: Text(icon,
              style: AppTextStyles.titleS.copyWith(color: AppColors.ink)),
        ),
      ),
    );
  }
}

// ── Field box ─────────────────────────────────────────────────────────────────

class _FieldBox extends StatelessWidget {
  final Widget child;
  const _FieldBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.ink, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
