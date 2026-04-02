import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import 'review_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;
  final String currentUserId;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.currentUserId,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final Color _primaryColor = const Color(0xFFFF6F61);

  late Transaction _tx;
  bool _isActioning = false;
  bool _hasReviewed = false;

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
  }

  bool get isBuyer => _tx.buyerId == widget.currentUserId;
  bool get isSeller => _tx.sellerId == widget.currentUserId;

  String get partnerName {
    if (isBuyer) {
      return _tx.seller?['displayNameTh'] ??
          _tx.seller?['username'] ??
          'ผู้ขาย';
    } else {
      return _tx.buyer?['displayNameTh'] ??
          _tx.buyer?['username'] ??
          'ผู้ซื้อ';
    }
  }

  String get productName => _tx.product?['title'] ?? 'สินค้า';

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'รอยืนยัน';
      case 'PROCESSING':
        return 'กำลังดำเนินการ';
      case 'SHIPPING':
        return 'รอรับสินค้า';
      case 'COMPLETED':
        return 'เสร็จสิ้น';
      case 'CANCELED':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'PROCESSING':
        return Colors.blue;
      case 'SHIPPING':
        return Colors.purple;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _performAction(
      Future<Map<String, dynamic>> Function() action, String successMsg) async {
    setState(() => _isActioning = true);
    try {
      final result = await action();
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
          SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
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
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _confirmTransaction() async {
    await _performAction(
      () => TransactionService.confirmTransaction(_tx.id),
      'ยืนยันธุรกรรมแล้ว',
    );
  }

  Future<void> _shipTransaction() async {
    await _performAction(
      () => TransactionService.shipTransaction(_tx.id),
      'ยืนยันส่งมอบสินค้าแล้ว',
    );
  }

  Future<void> _completeTransaction() async {
    await _performAction(
      () => TransactionService.completeTransaction(_tx.id),
      'ยืนยันรับสินค้าแล้ว',
    );
  }

  Future<void> _cancelTransaction() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกธุรกรรม'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'ระบุเหตุผลในการยกเลิก',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );

    if (reason == null) return;

    await _performAction(
      () => TransactionService.cancelTransaction(
          _tx.id, widget.currentUserId, reason),
      'ยกเลิกธุรกรรมแล้ว',
    );
  }

  void _navigateToReview() async {
    final revieweeId = isBuyer ? _tx.sellerId : _tx.buyerId;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewScreen(
          transactionId: _tx.id,
          reviewerId: widget.currentUserId,
          revieweeId: revieweeId,
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() => _hasReviewed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('รายละเอียดธุรกรรม',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      bottomNavigationBar: _buildActionButtons(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildProductCard(),
            const SizedBox(height: 16),
            _buildPartnerCard(),
            const SizedBox(height: 16),
            _buildDetailsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getStatusColor(_tx.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _getStatusColor(_tx.status).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            _getStatusIcon(_tx.status),
            size: 48,
            color: _getStatusColor(_tx.status),
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusText(_tx.status),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(_tx.status),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tx.type == 'RENT' ? 'เช่าสินค้า' : 'ซื้อสินค้า',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'PROCESSING':
        return Icons.sync;
      case 'SHIPPING':
        return Icons.local_shipping;
      case 'COMPLETED':
        return Icons.check_circle;
      case 'CANCELED':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Widget _buildProductCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สินค้า',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.shopping_bag,
                    color: _primaryColor, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '฿${_tx.price}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isBuyer ? 'ผู้ขาย' : 'ผู้ซื้อ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _primaryColor.withOpacity(0.1),
                child: Text(
                  partnerName.isNotEmpty
                      ? partnerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                partnerName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('รายละเอียด',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          _buildDetailRow('ประเภท', _tx.type == 'RENT' ? 'เช่า' : 'ซื้อขาย'),
          _buildDetailRow(
              'จุดนัดพบ', _tx.meetingPoint ?? 'ไม่ระบุ'),
          _buildDetailRow(
              'วันที่สร้าง',
              '${_tx.createdAt.day}/${_tx.createdAt.month}/${_tx.createdAt.year}'),
          _buildDetailRow(
              'อัปเดตล่าสุด',
              '${_tx.updatedAt.day}/${_tx.updatedAt.month}/${_tx.updatedAt.year}'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget? _buildActionButtons() {
    final List<Widget> buttons = [];

    // Seller + PENDING → ยืนยัน / ยกเลิก
    if (isSeller && _tx.status == 'PENDING') {
      buttons.addAll([
        Expanded(
          child: OutlinedButton(
            onPressed: _isActioning ? null : _cancelTransaction,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ยกเลิก',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isActioning ? null : _confirmTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ยืนยัน',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]);
    }

    // Seller + PROCESSING → ส่งมอบแล้ว / ยกเลิก
    if (isSeller && _tx.status == 'PROCESSING') {
      buttons.addAll([
        Expanded(
          child: OutlinedButton(
            onPressed: _isActioning ? null : _cancelTransaction,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ยกเลิก',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isActioning ? null : _shipTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ส่งมอบแล้ว',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]);
    }

    // Buyer + SHIPPING → ได้รับสินค้าแล้ว
    if (isBuyer && _tx.status == 'SHIPPING') {
      buttons.add(
        Expanded(
          child: ElevatedButton(
            onPressed: _isActioning ? null : _completeTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ได้รับสินค้าแล้ว',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    // Buyer + PENDING → ยกเลิก
    if (isBuyer && _tx.status == 'PENDING') {
      buttons.add(
        Expanded(
          child: OutlinedButton(
            onPressed: _isActioning ? null : _cancelTransaction,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ยกเลิก',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    // Buyer + PROCESSING → ยกเลิก
    if (isBuyer && _tx.status == 'PROCESSING') {
      buttons.add(
        Expanded(
          child: OutlinedButton(
            onPressed: _isActioning ? null : _cancelTransaction,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ยกเลิก',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    // COMPLETED → เขียนรีวิว (ถ้ายังไม่ได้รีวิว)
    if (_tx.status == 'COMPLETED' && !_hasReviewed) {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _navigateToReview,
            icon: const Icon(Icons.star),
            label: const Text('เขียนรีวิว',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: _isActioning
            ? const Center(child: CircularProgressIndicator())
            : Row(children: buttons),
      ),
    );
  }
}
