import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config.dart';
import '../services/review_service.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';

// ── Typography helpers ─────────────────────────────────────────────────────────

TextStyle _sans({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double? height,
}) =>
    GoogleFonts.sriracha(
        fontSize: size, fontWeight: weight, color: color, height: height);

TextStyle _mono({
  double size = 9,
  Color color = AppColors.textMuted,
  FontWeight weight = FontWeight.w500,
}) =>
    GoogleFonts.jetBrainsMono(
        fontSize: size, letterSpacing: 0.4, color: color, fontWeight: weight);

// ── Star labels ───────────────────────────────────────────────────────────────

const _starLabels = [
  '',
  '1 star · not great',
  '2 stars · could be better',
  '3 stars · decent',
  '4 stars · nice',
  '5 stars · amazing!',
];

const _tags = ['On time', 'Fair price', 'As described', 'Friendly', 'Would deal again'];

// ── Screen ────────────────────────────────────────────────────────────────────

class ReviewScreen extends StatefulWidget {
  final int transactionId;
  final String reviewerId;
  final String revieweeId;
  final String revieweeName;
  final String? revieweeAvatar;
  final String productTitle;
  final double productPrice;
  final String productType; // 'SALE' or 'RENT'

  const ReviewScreen({
    super.key,
    required this.transactionId,
    required this.reviewerId,
    required this.revieweeId,
    required this.revieweeName,
    this.revieweeAvatar,
    required this.productTitle,
    required this.productPrice,
    this.productType = 'SALE',
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final Set<String> _selectedTags = {};
  final _noteCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _showRatingError = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _showRatingError = true);
      return;
    }
    setState(() { _isSubmitting = true; _showRatingError = false; });

    // Combine tags + note into a single comment string
    final parts = <String>[];
    if (_selectedTags.isNotEmpty) parts.add(_selectedTags.join(' · '));
    if (_noteCtrl.text.trim().isNotEmpty) parts.add(_noteCtrl.text.trim());
    final comment = parts.isEmpty ? null : parts.join('\n\n');

    try {
      final result = await ReviewService.createReview(
        widget.transactionId,
        widget.reviewerId,
        widget.revieweeId,
        _rating,
        comment,
      );
      if (!mounted) return;
      if (result['success'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Something went wrong')),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit review')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPersonCard(),
                  const SizedBox(height: 24),
                  _buildStarSection(),
                  const SizedBox(height: 22),
                  _buildTagSection(),
                  const SizedBox(height: 22),
                  _buildNoteSection(),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 14, color: AppColors.ink),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Rate this deal',
        style: _sans(size: 20, weight: FontWeight.w700),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.divider),
      ),
    );
  }

  // ── Person + product card ──────────────────────────────────────────────────

  Widget _buildPersonCard() {
    final initial = widget.revieweeName.isNotEmpty
        ? widget.revieweeName[0].toUpperCase()
        : '?';
    final priceLabel = widget.productType == 'RENT'
        ? 'Rent ฿${_fmt(widget.productPrice)}/day'
        : '฿${_fmt(widget.productPrice)}';

    return Center(
      child: Column(
        children: [
          // Avatar
          _buildAvatar(initial),
          const SizedBox(height: 10),
          Text(
            widget.revieweeName,
            style: _sans(size: 17, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.productTitle} · $priceLabel',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    final avatar = widget.revieweeAvatar;
    if (avatar != null && avatar.isNotEmpty) {
      final url = avatar.startsWith('http')
          ? avatar
          : '${AppConfig.uploadsUrl}/$avatar';
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: kIsWeb
            ? Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(initial))
            : Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(initial)),
      );
    }
    return _avatarFallback(initial);
  }

  Widget _avatarFallback(String initial) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(initial, style: _sans(size: 28, weight: FontWeight.w700)),
    );
  }

  // ── Star rating ────────────────────────────────────────────────────────────

  Widget _buildStarSection() {
    return Column(
      children: [
        Center(
          child: Text('How was it?',
              style: _sans(size: 15, weight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        // Stars
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: () => setState(() {
                  _rating = i + 1;
                  _showRatingError = false;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '★',
                    style: TextStyle(
                      fontSize: 36,
                      color: filled ? AppColors.accent : AppColors.border,
                      shadows: [
                        Shadow(
                          color: AppColors.ink.withValues(alpha: filled ? 0.5 : 0.2),
                          blurRadius: 0,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        // Label or error
        Center(
          child: _showRatingError
              ? Text('Please select a star rating',
                  style: _mono(size: 10, color: Colors.red,
                      weight: FontWeight.w700))
              : Text(
                  _starLabels[_rating],
                  style: _mono(
                      size: 10,
                      color: _rating > 0
                          ? AppColors.ink
                          : AppColors.textHint,
                      weight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  // ── Tag chips ──────────────────────────────────────────────────────────────

  Widget _buildTagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tag the vibe',
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((tag) {
            final selected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _selectedTags.remove(tag);
                } else {
                  _selectedTags.add(tag);
                }
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accentSoft : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.ink : AppColors.border,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  selected ? '✓  $tag' : tag,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.ink,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Note input ─────────────────────────────────────────────────────────────

  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave a note (optional)',
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            border: Border.all(color: AppColors.ink, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextFormField(
            controller: _noteCtrl,
            maxLines: 4,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'Item was as described, met on time…',
              hintStyle:
                  AppTextStyles.bodyS.copyWith(color: AppColors.textHint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  // ── Footer button ──────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: GestureDetector(
          onTap: _isSubmitting ? null : _submit,
          child: Container(
            decoration: BoxDecoration(
              color: _rating > 0 ? AppColors.ink : AppColors.border,
              borderRadius: BorderRadius.circular(12),
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
                    'Submit review',
                    style: AppTextStyles.body.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(double price) {
    final s = price.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
