import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../shared/theme/app_colors.dart';
import 'review_screen.dart';

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

TextStyle _sans({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
}) =>
    GoogleFonts.sriracha(fontSize: size, fontWeight: weight, color: color);

// ── Step mapping ──────────────────────────────────────────────────────────────

int _statusStep(String status, {String type = 'SALE'}) {
  if (type == 'RENT') {
    switch (status) {
      case 'PENDING':    return 1;
      case 'PROCESSING': return 2;
      case 'SHIPPING':   return 3;
      case 'RETURNING':  return 4;
      case 'COMPLETED':  return 5;
      default:           return 0;
    }
  }
  switch (status) {
    case 'PENDING':    return 1;
    case 'PROCESSING': return 2;
    case 'SHIPPING':   return 3;
    case 'COMPLETED':  return 4;
    default:           return 0;
  }
}

// ── Full TxStepper (with labels) ─────────────────────────────────────────────

class _TxStepper extends StatelessWidget {
  final int step;
  final bool isRent;
  const _TxStepper({required this.step, this.isRent = false});

  static const _saleLabels   = ['Pending', 'Confirmed', 'Handed over', 'Done'];
  static const _rentLabels   = ['Pending', 'Confirmed', 'Renting', 'Returning', 'Done'];
  List<String> get _labels => isRent ? _rentLabels : _saleLabels;

  @override
  Widget build(BuildContext context) {
    final canceled = step == 0;
    return Row(
      children: [
        for (int i = 0; i < _labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                _dot(i + 1, canceled),
                const SizedBox(height: 4),
                Text(
                  _labels[i],
                  style: _mono(
                    size: 8,
                    color: (!canceled && step == i + 1)
                        ? AppColors.ink
                        : AppColors.textHint,
                    weight: (!canceled && step == i + 1)
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (i < _labels.length - 1)
            Container(
              width: isRent ? 16 : 24,
              height: 2,
              margin: const EdgeInsets.only(bottom: 20),
              color: canceled
                  ? AppColors.divider
                  : step > i + 1
                      ? AppColors.ink
                      : AppColors.divider,
            ),
        ],
      ],
    );
  }

  Widget _dot(int n, bool canceled) {
    final done = step >= n && !canceled;
    final active = step == n && !canceled;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: canceled
            ? Colors.transparent
            : active
                ? AppColors.accent
                : done
                    ? AppColors.ink
                    : Colors.transparent,
        border: Border.all(
          color: canceled
              ? AppColors.border
              : done || active
                  ? AppColors.ink
                  : AppColors.border,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        done && !active ? '✓' : '$n',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: canceled
              ? AppColors.textHint
              : active
                  ? AppColors.ink
                  : done
                      ? Colors.white
                      : AppColors.textHint,
          fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
        ),
      ),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

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
  late Transaction _tx;
  bool _isActioning = false;
  late bool _hasReviewed;

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
    _hasReviewed = _tx.hasReviewed;
  }

  bool get isBuyer => _tx.buyerId == widget.currentUserId;
  bool get isSeller => _tx.sellerId == widget.currentUserId;

  String get partnerName {
    if (isBuyer) {
      return _tx.seller?['displayNameTh'] ??
          _tx.seller?['username'] ??
          'Seller';
    } else {
      return _tx.buyer?['displayNameTh'] ??
          _tx.buyer?['username'] ??
          'Buyer';
    }
  }

  String get productName => _tx.product?['title'] as String? ?? 'Product';

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Waiting for seller to confirm';
      case 'PROCESSING':
        return 'Seller confirmed — arrange meeting';
      case 'SHIPPING':
        return _tx.type == 'RENT' ? 'Item rented out — awaiting return' : 'Ready to hand over';
      case 'RETURNING':
        return 'Renter is returning the item';
      case 'COMPLETED':
        return 'Deal complete';
      case 'CANCELED':
        return 'Order canceled';
      default:
        return status;
    }
  }

  Future<void> _performAction(
      Future<Map<String, dynamic>> Function() action,
      String successMsg) async {
    setState(() => _isActioning = true);
    try {
      final result = await action();
      if (!mounted) return;
      if (result['success'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Error'),
          backgroundColor: Colors.red,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(successMsg),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _confirmTransaction() async {
    await _performAction(
        () => TransactionService.confirmTransaction(_tx.id), 'Order confirmed');
  }

  Future<void> _shipTransaction() async {
    await _performAction(
        () => TransactionService.shipTransaction(_tx.id), 'Handover confirmed');
  }

  Future<void> _returnTransaction() async {
    await _performAction(
        () => TransactionService.returnTransaction(_tx.id), 'Item return confirmed');
  }

  Future<void> _completeTransaction() async {
    await _performAction(
        () => TransactionService.completeTransaction(_tx.id), 'Deal complete!');
  }

  Future<void> _cancelTransaction() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel order', style: _jak(size: 16, weight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'Reason for canceling…',
            hintStyle: _mono(size: 11, color: AppColors.textHint),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          maxLines: 3,
          style: _jak(size: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Back', style: _mono(size: 10, color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text('Confirm cancel',
                style: _mono(size: 10, color: Colors.red, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (reason == null) return;
    await _performAction(
        () => TransactionService.cancelTransaction(
            _tx.id, widget.currentUserId, reason),
        'Order canceled');
  }

  void _navigateToReview() async {
    final revieweeId = isBuyer ? _tx.sellerId : _tx.buyerId;
    final revieweeData = isBuyer ? _tx.seller : _tx.buyer;
    final revieweeName = revieweeData?['displayNameTh'] ??
        revieweeData?['username'] ??
        (isBuyer ? 'Seller' : 'Buyer');
    final revieweeAvatar = revieweeData?['avatar'] as String?;
    final price = (_tx.product?['price'] as num?)?.toDouble() ?? 0.0;
    final rentPrice = (_tx.product?['rentPrice'] as num?)?.toDouble() ?? 0.0;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          transactionId: _tx.id,
          reviewerId: widget.currentUserId,
          revieweeId: revieweeId,
          revieweeName: revieweeName,
          revieweeAvatar: revieweeAvatar,
          productTitle: productName,
          productPrice: _tx.type == 'RENT' && rentPrice > 0 ? rentPrice : price,
          productType: _tx.type,
        ),
      ),
    );
    if (result == true && mounted) setState(() => _hasReviewed = true);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRent = _tx.type == 'RENT';
    final step = _statusStep(_tx.status, type: _tx.type);
    final isActive =
        _tx.status != 'COMPLETED' && _tx.status != 'CANCELED';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stepper ──
                    _TxStepper(step: step, isRent: isRent),
                    const SizedBox(height: 16),

                    // ── Status card ──
                    _buildStatusCard(isActive),
                    const SizedBox(height: 12),

                    // ── Item ──
                    _buildSectionLabel('Item'),
                    const SizedBox(height: 6),
                    _buildItemCard(),
                    const SizedBox(height: 12),

                    // ── Meeting ──
                    if (_tx.meetingPoint != null) ...[
                      _buildSectionLabel('Meeting point'),
                      const SizedBox(height: 6),
                      _buildMeetingCard(),
                      const SizedBox(height: 12),
                    ],

                    // ── Timeline ──
                    _buildSectionLabel('Timeline'),
                    const SizedBox(height: 8),
                    _buildTimeline(),

                    // Space for action bar
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBar(),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
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
          const SizedBox(width: 12),
          Text(
            'Order #${_tx.id.toString().padLeft(5, '0')}',
            style: _jak(size: 16, weight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            _tx.type == 'RENT' ? 'RENT' : 'SALE',
            style: _mono(
              size: 9,
              color: _tx.type == 'RENT'
                  ? AppColors.accent
                  : const Color(0xFF22C55E),
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Status card ───────────────────────────────────────────────────────────

  Widget _buildStatusCard(bool isActive) {
    final canceled = _tx.status == 'CANCELED';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: canceled
            ? AppColors.bg
            : isActive
                ? AppColors.accentSoft
                : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canceled
              ? AppColors.border
              : isActive
                  ? AppColors.accent
                  : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('current status',
              style: _mono(size: 9, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            _statusLabel(_tx.status),
            style: _jak(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Updated ${_tx.updatedAt.day}/${_tx.updatedAt.month}/${_tx.updatedAt.year}',
            style: _mono(size: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: _mono(
            size: 9,
            color: AppColors.textMuted,
            weight: FontWeight.w700));
  }

  // ── Item card ─────────────────────────────────────────────────────────────

  Widget _buildItemCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.shopping_bag_outlined,
                size: 24, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName,
                    style: _jak(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'qty 1 · ${_tx.type == 'RENT' ? 'for rent' : 'for sale'}',
                  style: _mono(size: 9, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text('฿${_tx.price}',
              style: _jak(size: 14, weight: FontWeight.w800)),
        ],
      ),
    );
  }

  // ── Meeting card (dashed border) ──────────────────────────────────────────

  Widget _buildMeetingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border,
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: _DashedBorderBox(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _tx.meetingPoint!,
                  style: _jak(size: 13, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Timeline ──────────────────────────────────────────────────────────────

  Widget _buildTimeline() {
    final events = _buildTimelineEvents();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++)
            _TimelineRow(
              label: events[i].$1,
              time: events[i].$2,
              isLast: i == events.length - 1,
              isActive: i == events.length - 1 && _tx.status != 'COMPLETED' && _tx.status != 'CANCELED',
            ),
        ],
      ),
    );
  }

  List<(String, String)> _buildTimelineEvents() {
    final events = <(String, String)>[];
    final created = _tx.createdAt;
    final d = created;
    final fmt = '${_dayName(d.weekday)} ${d.day}/${d.month}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    events.add(('Order placed', fmt));
    if (_tx.status != 'PENDING') {
      events.add(('Seller confirmed', _formatDate(_tx.updatedAt)));
    }
    if (_tx.status == 'SHIPPING' || _tx.status == 'COMPLETED') {
      events.add(('Ready to meet', _formatDate(_tx.updatedAt)));
    }
    if (_tx.status == 'COMPLETED') {
      events.add(('Deal complete', _formatDate(_tx.updatedAt)));
    }
    if (_tx.status == 'CANCELED') {
      events.add(('Order canceled', _formatDate(_tx.updatedAt)));
    }
    return events;
  }

  String _dayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1).clamp(0, 6)];
  }

  String _formatDate(DateTime d) {
    return '${_dayName(d.weekday)} ${d.day}/${d.month}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  // ── Action bar ────────────────────────────────────────────────────────────

  Widget? _buildActionBar() {
    final buttons = <Widget>[];

    if (isSeller && _tx.status == 'PENDING') {
      buttons.addAll([
        Expanded(child: _outlineBtn('Cancel', onTap: _cancelTransaction, danger: true)),
        const SizedBox(width: 10),
        Expanded(child: _primaryBtn('Confirm order', onTap: _confirmTransaction)),
      ]);
    }
    if (isSeller && _tx.status == 'PROCESSING') {
      buttons.addAll([
        Expanded(child: _outlineBtn('Cancel', onTap: _cancelTransaction, danger: true)),
        const SizedBox(width: 10),
        Expanded(child: _primaryBtn('Handed over', onTap: _shipTransaction)),
      ]);
    }
    if (isBuyer && _tx.status == 'SHIPPING' && _tx.type == 'SALE') {
      buttons.add(
        Expanded(child: _primaryBtn('I received it ✓', onTap: _completeTransaction, accent: true)),
      );
    }
    if (isBuyer && _tx.status == 'SHIPPING' && _tx.type == 'RENT') {
      buttons.add(
        Expanded(child: _primaryBtn('Return item ↩', onTap: _returnTransaction, accent: true)),
      );
    }
    if (isSeller && _tx.status == 'RETURNING') {
      buttons.add(
        Expanded(child: _primaryBtn('Got it back ✓', onTap: _completeTransaction, accent: true)),
      );
    }
    if (isBuyer && (_tx.status == 'PENDING' || _tx.status == 'PROCESSING')) {
      buttons.add(
        Expanded(child: _outlineBtn('Cancel order', onTap: _cancelTransaction, danger: true)),
      );
    }
    if (_tx.status == 'COMPLETED' && !_hasReviewed) {
      buttons.add(
        Expanded(child: _primaryBtn('★ Leave a review', onTap: _navigateToReview, accent: true)),
      );
    }

    if (buttons.isEmpty) return null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: _isActioning
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Row(children: buttons),
      ),
    );
  }

  Widget _primaryBtn(String label,
      {required VoidCallback onTap, bool accent = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent ? AppColors.accent : AppColors.ink,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: _sans(
            size: 15,
            weight: FontWeight.w700,
            color: accent ? AppColors.ink : AppColors.surface,
          ),
        ),
      ),
    );
  }

  Widget _outlineBtn(String label,
      {required VoidCallback onTap, bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: danger ? Colors.red.shade300 : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: _sans(
            size: 15,
            weight: FontWeight.w600,
            color: danger ? Colors.red : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

// ── Timeline row ──────────────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  final String label;
  final String time;
  final bool isLast;
  final bool isActive;
  const _TimelineRow({
    required this.label,
    required this.time,
    required this.isLast,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dot + line ──
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? AppColors.accent : AppColors.ink,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: AppColors.divider,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── Label + time ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: _jak(size: 12, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(time,
                      style: _mono(size: 9, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashed border box helper ──────────────────────────────────────────────────

class _DashedBorderBox extends StatelessWidget {
  final Widget child;
  const _DashedBorderBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashW = 6.0;
    const dashG = 4.0;
    const r = 10.0;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(r)));
    final pathMetric = path.computeMetrics().first;
    var d = 0.0;
    while (d < pathMetric.length) {
      canvas.drawPath(
        pathMetric.extractPath(d, d + dashW),
        paint,
      );
      d += dashW + dashG;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
