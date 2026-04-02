import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import 'transaction_detail_screen.dart';

class TransactionListScreen extends StatefulWidget {
  final String userId;

  const TransactionListScreen({super.key, required this.userId});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen>
    with SingleTickerProviderStateMixin {
  final Color _primaryColor = const Color(0xFFFF6F61);

  late TabController _tabController;
  Map<String, List<Transaction>> _groupedTransactions = {
    'processing': [],
    'shipping': [],
    'history': [],
    'canceled': [],
  };
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final grouped =
          await TransactionService.getUserTransactions(widget.userId);
      if (mounted) {
        setState(() {
          _groupedTransactions = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'โหลดรายการธุรกรรมไม่สำเร็จ';
          _isLoading = false;
        });
      }
    }
  }

  List<Transaction> _getProcessing() =>
      _groupedTransactions['processing'] ?? [];

  List<Transaction> _getShipping() =>
      _groupedTransactions['shipping'] ?? [];

  List<Transaction> _getHistory() =>
      _groupedTransactions['history'] ?? [];

  List<Transaction> _getCanceled() =>
      _groupedTransactions['canceled'] ?? [];

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

  String _getPartnerName(Transaction tx) {
    if (tx.buyerId == widget.userId) {
      // ผู้ใช้เป็น Buyer → แสดงชื่อ Seller
      return tx.seller?['displayNameTh'] ??
          tx.seller?['username'] ??
          'ผู้ขาย';
    } else {
      // ผู้ใช้เป็น Seller → แสดงชื่อ Buyer
      return tx.buyer?['displayNameTh'] ??
          tx.buyer?['username'] ??
          'ผู้ซื้อ';
    }
  }

  String _getRoleLabel(Transaction tx) {
    return tx.buyerId == widget.userId ? 'ผู้ซื้อ' : 'ผู้ขาย';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ธุรกรรม',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primaryColor,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'กำลังดำเนินการ'),
            Tab(text: 'รอรับสินค้า'),
            Tab(text: 'ประวัติ'),
            Tab(text: 'ยกเลิก'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadTransactions,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor),
                        child: const Text('ลองใหม่',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTransactionList(_getProcessing()),
                    _buildTransactionList(_getShipping()),
                    _buildTransactionList(_getHistory()),
                    _buildTransactionList(_getCanceled()),
                  ],
                ),
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('ไม่มีรายการ',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      color: _primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildTransactionItem(transactions[index]),
      ),
    );
  }

  Widget _buildTransactionItem(Transaction tx) {
    final productName = tx.product?['title'] ?? 'สินค้า';
    final partnerName = _getPartnerName(tx);
    final roleLabel = _getRoleLabel(tx);

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(
              transaction: tx,
              currentUserId: widget.userId,
            ),
          ),
        );
        _loadTransactions();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product image or icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                tx.type == 'RENT' ? Icons.access_time : Icons.shopping_bag,
                color: _primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'คู่ค้า ($roleLabel): $partnerName',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '฿${tx.price}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _primaryColor,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              _getStatusColor(tx.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusText(tx.status),
                          style: TextStyle(
                            color: _getStatusColor(tx.status),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
