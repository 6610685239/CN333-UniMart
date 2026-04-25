import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import 'my_shop_screen.dart';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────

class AddProductScreen extends StatefulWidget {
  final String userId;

  const AddProductScreen({super.key, required this.userId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  // ── Step 0 = intro, 1 = form, 2 = preview ──
  int _step = 0;

  // ── Form state ──
  String _type = 'SALE';
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  String _selectedCondition = 'มือหนึ่ง';
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  final _meetingPointCtrl = TextEditingController();
  List<XFile> _images = [];

  // ── Remote data ──
  List<Map<String, dynamic>> _categories = [];

  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final List<String> _conditions = ['มือหนึ่ง', 'มือสอง (สภาพดี)', 'มือสอง (มีตำหนิ)'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _meetingPointCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.baseUrl}/categories'));
      if (res.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        if (mounted) {
          setState(() {
            _categories = list;
            if (list.isNotEmpty) {
              _selectedCategoryId = list[0]['id'].toString();
              _selectedCategoryName = list[0]['name'];
            }
          });
        }
      }
    } catch (_) {}
    await _loadDraft();
  }

  String get _draftKey => 'product_draft_${widget.userId}';

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'type': _type,
      'title': _titleCtrl.text,
      'desc': _descCtrl.text,
      'price': _priceCtrl.text,
      'quantity': _quantityCtrl.text,
      'condition': _selectedCondition,
      'categoryId': _selectedCategoryId ?? '',
      'categoryName': _selectedCategoryName ?? '',
      'meetingPoint': _meetingPointCtrl.text,
      if (!kIsWeb)
        'imagePaths': _images.map((f) => f.path).toList(),
    };
    await prefs.setString(_draftKey, jsonEncode(data));
    if (mounted) _snack('Draft saved');
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || !mounted) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _type = data['type'] ?? _type;
        _titleCtrl.text = data['title'] ?? '';
        _descCtrl.text = data['desc'] ?? '';
        _priceCtrl.text = data['price'] ?? '';
        _quantityCtrl.text = data['quantity'] ?? '1';
        _selectedCondition = data['condition'] ?? _selectedCondition;
        if ((data['categoryId'] as String).isNotEmpty) {
          _selectedCategoryId = data['categoryId'];
          _selectedCategoryName = data['categoryName'];
        }
        _meetingPointCtrl.text = data['meetingPoint'] ?? '';
        if (!kIsWeb && data['imagePaths'] != null) {
          final paths = List<String>.from(data['imagePaths'] as List);
          _images = paths
              .where((p) => File(p).existsSync())
              .map((p) => XFile(p))
              .toList();
        }
        // If a draft exists, skip the intro step
        if (_titleCtrl.text.isNotEmpty) _step = 1;
      });
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage();
      for (final img in picked) {
        if (_images.length >= 5) break;
        if (kIsWeb) {
          setState(() => _images.add(img));
        } else {
          try {
            final cropped = await ImageCropper().cropImage(
              sourcePath: img.path,
              uiSettings: [
                AndroidUiSettings(
                  toolbarTitle: 'Crop image',
                  toolbarColor: AppColors.ink,
                  toolbarWidgetColor: Colors.white,
                  initAspectRatio: CropAspectRatioPreset.square,
                  lockAspectRatio: false,
                ),
                IOSUiSettings(title: 'Crop image'),
              ],
            );
            setState(() => _images.add(
                  cropped != null ? XFile(cropped.path) : img,
                ));
          } catch (_) {
            setState(() => _images.add(img));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      _snack('Please add at least 1 photo');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('${AppConfig.baseUrl}/products'));

      req.fields['title'] = _titleCtrl.text.trim();
      req.fields['description'] = _descCtrl.text.trim();
      req.fields['type'] = _type;
      req.fields['condition'] = _selectedCondition;
      req.fields['categoryId'] = _selectedCategoryId!;
      req.fields['ownerId'] = widget.userId;
      req.fields['quantity'] = _quantityCtrl.text.trim();

      if (_type == 'SALE') {
        req.fields['price'] = _priceCtrl.text.trim();
      } else {
        req.fields['price'] = '0';
        req.fields['rentPrice'] = _priceCtrl.text.trim();
      }

      if (_meetingPointCtrl.text.trim().isNotEmpty) {
        req.fields['location'] = _meetingPointCtrl.text.trim();
      }

      for (final file in _images) {
        final bytes = await file.readAsBytes();
        final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
        final ext = name.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'png' : ext == 'gif' ? 'gif' : 'jpeg';
        req.files.add(http.MultipartFile.fromBytes('images', bytes,
            filename: name, contentType: MediaType('image', mime)));
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _clearDraft();
        _snack('Listed successfully!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => MyShopScreen(currentUserId: widget.userId)),
        );
      } else {
        _snack('Error: ${res.statusCode}');
      }
    } catch (e) {
      _snack('Something went wrong');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: switch (_step) {
        0 => _SellIntro(
            selectedType: _type,
            onSelect: (t) => setState(() {
              _type = t;
              _step = 1;
            }),
          ),
        1 => _SellForm(
            formKey: _formKey,
            type: _type,
            images: _images,
            onPickImages: _pickImages,
            onRemoveImage: (img) => setState(() => _images.remove(img)),
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            priceCtrl: _priceCtrl,
            quantityCtrl: _quantityCtrl,
            meetingPointCtrl: _meetingPointCtrl,
            conditions: _conditions,
            selectedCondition: _selectedCondition,
            onConditionChanged: (c) => setState(() => _selectedCondition = c),
            categories: _categories,
            selectedCategoryId: _selectedCategoryId,
            onCategoryChanged: (id, name) => setState(() {
              _selectedCategoryId = id;
              _selectedCategoryName = name;
            }),
            onSaveDraft: _saveDraft,
            onPreview: () {
              if (_formKey.currentState!.validate()) {
                setState(() => _step = 2);
              }
            },
          ),
        _ => _SellPreview(
            type: _type,
            title: _titleCtrl.text,
            price: _priceCtrl.text,
            quantity: _quantityCtrl.text,
            condition: _selectedCondition,
            categoryName: _selectedCategoryName ?? '',
            description: _descCtrl.text,
            meetingPoint: _meetingPointCtrl.text,
            images: _images,
            isSubmitting: _isSubmitting,
            onPublish: _submit,
          ),
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = ['List an item', 'Item details', 'Preview'];
    final subs = ['', 'Step 1 / 2', 'Step 2 / 2'];

    return AppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.ink),
        onPressed: () {
          if (_step == 0) {
            Navigator.pop(context);
          } else {
            setState(() => _step--);
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _step == 1
                ? '${_type == 'SALE' ? 'For sale' : 'For rent'} · ${subs[_step]}'
                : titles[_step],
            style: GoogleFonts.sriracha(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.1,
            ),
          ),
          if (subs[_step].isNotEmpty && _step != 1)
            Text(
              subs[_step],
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.divider),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Step 0 — Sell Intro
// ─────────────────────────────────────────────────────────────

class _SellIntro extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onSelect;

  const _SellIntro({required this.selectedType, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you listing?',
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),

          // For sale card
          _TypeCard(
            icon: '฿',
            title: 'For sale',
            subtitle: 'Sell once · buyer takes it home',
            accent: true,
            onTap: () => onSelect('SALE'),
          ),
          const SizedBox(height: 12),

          // For rent card
          _TypeCard(
            icon: '↻',
            title: 'For rent',
            subtitle: 'Daily/weekly rate · item comes back',
            accent: false,
            onTap: () => onSelect('RENT'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool accent;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent ? AppColors.accentSoft : AppColors.surface,
          border: Border.all(color: AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent ? AppColors.accent : AppColors.surface,
                border: Border.all(color: AppColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                icon,
                style: TextStyle(
                  fontSize: accent ? 22 : 18,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            Text('→',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Step 1 — Sell Form
// ─────────────────────────────────────────────────────────────

class _SellForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String type;
  final List<XFile> images;
  final VoidCallback onPickImages;
  final ValueChanged<XFile> onRemoveImage;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController quantityCtrl;
  final List<String> conditions;
  final String selectedCondition;
  final ValueChanged<String> onConditionChanged;
  final List<Map<String, dynamic>> categories;
  final String? selectedCategoryId;
  final void Function(String id, String name) onCategoryChanged;
  final TextEditingController meetingPointCtrl;
  final VoidCallback onSaveDraft;
  final VoidCallback onPreview;

  const _SellForm({
    required this.formKey,
    required this.type,
    required this.images,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.titleCtrl,
    required this.descCtrl,
    required this.priceCtrl,
    required this.quantityCtrl,
    required this.conditions,
    required this.selectedCondition,
    required this.onConditionChanged,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.meetingPointCtrl,
    required this.onSaveDraft,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                // ── Photos ──
                _sectionLabel('Photos (${images.length}/5)'),
                const SizedBox(height: 8),
                _buildPhotoRow(),
                const SizedBox(height: 18),

                // ── Title ──
                _sectionLabel('Title'),
                const SizedBox(height: 6),
                _buildInput(
                  controller: titleCtrl,
                  hint: 'e.g. Stewart Calculus 8e',
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
                          _sectionLabel(
                              type == 'RENT' ? 'Rent price (฿/day)' : 'Price (฿)'),
                          const SizedBox(height: 6),
                          _buildInput(
                            controller: priceCtrl,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (type == 'SALE')
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Qty / stock'),
                            const SizedBox(height: 6),
                            _QuantityStepper(controller: quantityCtrl),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Category ──
                _sectionLabel('Category'),
                const SizedBox(height: 8),
                _buildCategoryChips(),
                const SizedBox(height: 14),

                // ── Condition ──
                _sectionLabel('Condition'),
                const SizedBox(height: 8),
                _buildConditionChips(),
                const SizedBox(height: 14),

                // ── Description ──
                _sectionLabel('Description'),
                const SizedBox(height: 6),
                _buildInput(
                  controller: descCtrl,
                  hint: 'Used one semester. No highlights…',
                  maxLines: 4,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // ── Meeting point ──
                _sectionLabel('Meeting point'),
                const SizedBox(height: 6),
                _buildInput(
                  controller: meetingPointCtrl,
                  hint: 'e.g. SC Building Lobby, Dome Canteen',
                ),
              ],
            ),
          ),
        ),

        // ── Footer ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              // Save draft (outline)
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onSaveDraft,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: AppColors.border, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text('Save draft',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textMuted)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Preview → (filled)
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: onPreview,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text('Preview →',
                        style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Photos row ──

  Widget _buildPhotoRow() {
    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Filled images
          ...images.asMap().entries.map((e) => _PhotoThumb(
                file: e.value,
                isCover: e.key == 0,
                onRemove: () => onRemoveImage(e.value),
              )),
          // Empty slots
          ...List.generate(
            (5 - images.length).clamp(0, 5),
            (i) => GestureDetector(
              onTap: onPickImages,
              child: Container(
                width: 70,
                height: 70,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.border,
                      width: 1.5,
                      style: BorderStyle.none),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomPaint(
                  painter: _DashedBoxPainter(),
                  child: Center(
                    child: Text('+',
                        style: AppTextStyles.titleM
                            .copyWith(color: AppColors.textHint)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Category chips ──

  Widget _buildCategoryChips() {
    if (categories.isEmpty) {
      return Text('Loading…',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: categories.map((cat) {
        final id = cat['id'].toString();
        final name = cat['name'] as String;
        final selected = id == selectedCategoryId;
        return GestureDetector(
          onTap: () => onCategoryChanged(id, name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.transparent,
              border:
                  Border.all(color: selected ? AppColors.ink : AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              name,
              style: AppTextStyles.caption.copyWith(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Condition chips ──

  Widget _buildConditionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: conditions.map((c) {
        final selected = c == selectedCondition;
        return GestureDetector(
          onTap: () => onConditionChanged(c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.bg,
              border: Border.all(
                color: selected ? AppColors.ink : AppColors.ink,
                width: 1,
              ),
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

  // ── Generic input ──

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return _FieldBox(
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: AppTextStyles.bodyS.copyWith(color: AppColors.ink),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyS.copyWith(color: AppColors.textHint),
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
          color: AppColors.textMuted, fontWeight: FontWeight.w600),
    );
  }
}

// ── Quantity stepper ──

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
    final next = (_qty + delta).clamp(1, 99);
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
              child: Text('$_qty',
                  style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.ink)),
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

// ── Photo thumbnail ──

class _PhotoThumb extends StatelessWidget {
  final XFile file;
  final bool isCover;
  final VoidCallback onRemove;

  const _PhotoThumb(
      {required this.file, required this.isCover, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 70,
          height: 70,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isCover
                ? Border.all(color: AppColors.accent, width: 2)
                : Border.all(color: AppColors.border, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: kIsWeb
                ? FutureBuilder<Uint8List>(
                    future: file.readAsBytes(),
                    builder: (_, snap) => snap.hasData
                        ? Image.memory(snap.data!, fit: BoxFit.cover)
                        : const SizedBox(),
                  )
                : Image.file(File(file.path), fit: BoxFit.cover),
          ),
        ),
        if (isCover)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('cover',
                  style: AppTextStyles.tagline
                      .copyWith(color: AppColors.ink, fontSize: 9)),
            ),
          ),
        Positioned(
          top: 3,
          right: 9,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: AppColors.ink, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Consistent field box — single source of border truth ──
// Using Container+BoxDecoration instead of OutlineInputBorder avoids
// the 1px rendering glitch where Flutter draws sides at different sub-pixel
// thicknesses depending on widget state.

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

// ── Dashed box painter for empty photo slots ──

class _DashedBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 5.0;
    const gap = 3.0;
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(8));
    final path = Path()..addRRect(r);
    _drawDashedPath(canvas, path, paint, dash, gap);
  }

  void _drawDashedPath(
      Canvas canvas, Path path, Paint paint, double dash, double gap) {
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double dist = 0;
      while (dist < m.length) {
        final end = (dist + dash).clamp(0.0, m.length);
        canvas.drawPath(m.extractPath(dist, end), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBoxPainter old) => false;
}

// ─────────────────────────────────────────────────────────────
// Step 2 — Sell Preview
// ─────────────────────────────────────────────────────────────

class _SellPreview extends StatelessWidget {
  final String type;
  final String title;
  final String price;
  final String quantity;
  final String condition;
  final String categoryName;
  final String description;
  final String meetingPoint;
  final List<XFile> images;
  final bool isSubmitting;
  final VoidCallback onPublish;

  const _SellPreview({
    required this.type,
    required this.title,
    required this.price,
    required this.quantity,
    required this.condition,
    required this.categoryName,
    required this.description,
    required this.meetingPoint,
    required this.images,
    required this.isSubmitting,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final checks = [
      _Check('✓', 'At least 1 photo', images.isNotEmpty),
      _Check('✓', 'Title + price',
          title.isNotEmpty && price.isNotEmpty),
      _Check('✓', 'Category + condition',
          categoryName.isNotEmpty && condition.isNotEmpty),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            children: [
              // ── Preview card — same structure as home page card, bigger ──
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image area with badges
                    SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: AppColors.bg,
                            child: images.isNotEmpty
                                ? _previewImage()
                                : const Center(
                                    child: Icon(Icons.image_outlined,
                                        size: 56, color: AppColors.textHint),
                                  ),
                          ),
                          // Category badge — top-left
                          if (categoryName.isNotEmpty)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: _OverlayBadge(
                                label: categoryName,
                                textColor: AppColors.ink,
                              ),
                            ),
                          // Type badge — top-right
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _OverlayBadge(
                              label: type == 'SALE' ? 'SALE' : 'RENT',
                              textColor: type == 'SALE'
                                  ? const Color(0xFF22C55E)
                                  : AppColors.accent,
                            ),
                          ),
                          // Condition badge — bottom-left
                          if (condition.isNotEmpty)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: _OverlayBadgeDark(
                                label: _shortCondition(condition),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Info section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? 'Untitled' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily:
                                  GoogleFonts.plusJakartaSans().fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description.isEmpty ? 'No description' : description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily:
                                  GoogleFonts.plusJakartaSans().fontFamily,
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '฿$price',
                                style: TextStyle(
                                  fontFamily:
                                      GoogleFonts.plusJakartaSans().fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              Row(children: [
                                const Icon(Icons.favorite_border_rounded,
                                    size: 14, color: AppColors.textHint),
                                const SizedBox(width: 2),
                                Text(
                                  '0',
                                  style: TextStyle(
                                    fontFamily:
                                        GoogleFonts.jetBrainsMono().fontFamily,
                                    fontSize: 9,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Checklist ──
              Text('Checklist',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...checks.map((c) => _buildCheckRow(c)),

              const SizedBox(height: 16),

              // ── Note ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.accent.withOpacity(0.4)),
                ),
                child: Text(
                  '🔔 You\'ll get a notification every time a buyer messages you.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),

        // ── Footer ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: GestureDetector(
              onTap: isSubmitting ? null : onPublish,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Publish listing · go live now',
                        style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewImage() {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: images.first.readAsBytes(),
        builder: (_, snap) => snap.hasData
            ? Image.memory(snap.data!,
                width: double.infinity, fit: BoxFit.contain)
            : const SizedBox.expand(),
      );
    }
    return Image.file(File(images.first.path),
        width: double.infinity, fit: BoxFit.contain);
  }

  String _shortCondition(String c) {
    final upper = c.toUpperCase();
    if (upper.contains('หนึ่ง') || upper.contains('NEW') ||
        upper.contains('LIKE')) return 'มือ 1';
    return 'มือ 2';
  }

  Widget _buildCheckRow(_Check c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: c.pass ? AppColors.ink : AppColors.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              c.mark,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.pass ? Colors.white : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            c.label,
            style: AppTextStyles.bodyS.copyWith(
              color: c.pass ? AppColors.ink : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Check {
  final String mark;
  final String label;
  final bool pass;
  const _Check(this.mark, this.label, this.pass);
}

// ── Overlay badges (homepage card style) ──

class _OverlayBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  const _OverlayBadge({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _OverlayBadgeDark extends StatelessWidget {
  final String label;
  const _OverlayBadgeDark({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

