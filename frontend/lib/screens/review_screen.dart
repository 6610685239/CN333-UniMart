import 'package:flutter/material.dart';
import '../services/review_service.dart';

class ReviewScreen extends StatefulWidget {
  final int transactionId;
  final String reviewerId;
  final String revieweeId;

  const ReviewScreen({
    super.key,
    required this.transactionId,
    required this.reviewerId,
    required this.revieweeId,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final Color _primaryColor = const Color(0xFFFF6F61);

  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _ratingError;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    // Validate rating
    if (_selectedRating == 0) {
      setState(() => _ratingError = 'กรุณาเลือกคะแนนดาว');
      return;
    }
    setState(() => _ratingError = null);

    setState(() => _isSubmitting = true);
    try {
      final result = await ReviewService.createReview(
        widget.transactionId,
        widget.reviewerId,
        widget.revieweeId,
        _selectedRating,
        _commentController.text.isNotEmpty ? _commentController.text : null,
      );

      if (!mounted) return;

      if (result['success'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'เกิดข้อผิดพลาด'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งรีวิวสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('เขียนรีวิว',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            // Star icon
            Icon(Icons.rate_review, size: 64, color: _primaryColor),
            const SizedBox(height: 16),
            const Text(
              'ให้คะแนนคู่ค้าของคุณ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'เลือกคะแนนดาวและเขียนรีวิว',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = starNumber;
                      _ratingError = null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      starNumber <= _selectedRating
                          ? Icons.star
                          : Icons.star_border,
                      size: 48,
                      color: starNumber <= _selectedRating
                          ? Colors.amber
                          : Colors.grey[300],
                    ),
                  ),
                );
              }),
            ),
            if (_ratingError != null) ...[
              const SizedBox(height: 8),
              Text(
                _ratingError!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            if (_selectedRating > 0) ...[
              const SizedBox(height: 8),
              Text(
                _getRatingLabel(_selectedRating),
                style: TextStyle(
                  color: Colors.amber[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Comment field
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ข้อความรีวิว (ไม่บังคับ)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'เขียนรีวิวของคุณที่นี่...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'ส่งรีวิว',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'แย่มาก';
      case 2:
        return 'แย่';
      case 3:
        return 'ปานกลาง';
      case 4:
        return 'ดี';
      case 5:
        return 'ดีมาก';
      default:
        return '';
    }
  }
}
