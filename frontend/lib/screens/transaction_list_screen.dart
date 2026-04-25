import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../shared/theme/app_colors.dart';
import 'transaction_detail_screen.dart';

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

// ── Step from status ──────────────────────────────────────────────────────────

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

// ── Mini stepper (inline in card) ────────────────────────────────────────────

class _MiniStepper extends StatelessWidget {
  final int step;
  final bool isRent;
  const _MiniStepper({required this.step, this.isRent = false});

  @override
  Widget build(BuildContext context) {
    final canceled = step == 0;
    final count = isRent ? 5 : 4;
    return Row(
      children: [
        for (int i = 0; i < count; i++) ...[
          _dot(i + 1, canceled),
          if (i < count - 1) _connector(i, canceled),
        ],
      ],
    );
  }

  Widget _dot(int n, bool canceled) {
    final done = step >= n && !canceled;
    final active = step == n && !canceled;
    return Container(
      width: 14,
      height: 14,
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
          fontSize: 7,
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

  Widget _connector(int i, bool canceled) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: canceled
            ? AppColors.divider
            : step > i + 1
                ? AppColors.ink
                : AppColors.divider,
      ),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TransactionListScreen extends StatefulWidget {
  final String userId;
  const TransactionListScreen({super.key, required this.userId});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  List<Transaction> _all = [];
  bool _isLoading = true;
  String? _error;
  bool _showBuying = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final grouped =
          await TransactionService.getUserTransactions(widget.userId);
      if (mounted) {
        setState(() {
          _all = [
            ...grouped['processing'] ?? [],
            ...grouped['shipping'] ?? [],
            ...grouped['history'] ?? [],
            ...grouped['canceled'] ?? [],
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load orders';
          _isLoading = false;
        });
      }
    }
  }

  List<Transaction> get _buying =>
      _all.where((tx) => tx.buyerId == widget.userId).toList();

  List<Transaction> get _selling =>
      _all.where((tx) => tx.sellerId == widget.userId).toList();

  List<Transaction> get _current => _showBuying ? _buying : _selling;

  String _partnerName(Transaction tx) {
    if (tx.buyerId == widget.userId) {
      return tx.seller?['displayNameTh'] ??
          tx.seller?['username'] ??
          'Seller';
    }
    return tx.buyer?['displayNameTh'] ??
        tx.buyer?['username'] ??
        'Buyer';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final buying = _buying;
    final selling = _selling;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
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
                  const SizedBox(width: 8),
                  Text(
                    'My Orders',
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

            // ── Buying / Selling tabs ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _tab('Buying (${buying.length})', isBuying: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _tab('Selling (${selling.length})', isBuying: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Content ──
            Expanded(
              child: _isLoading
                  ? _skeleton()
                  : _error != null
                      ? _errorState()
                      : _current.isEmpty
                          ? _emptyState()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.ink,
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                    16, 0, 16, 88 + bottomPad),
                                physics: const BouncingScrollPhysics(),
                                itemCount: _current.length,
                                itemBuilder: (_, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _txCard(_current[i]),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab pill ───────────────────────────────────────────────────────────────

  Widget _tab(String label, {required bool isBuying}) {
    final active = _showBuying == isBuying;
    return GestureDetector(
      onTap: () => setState(() => _showBuying = isBuying),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Text(
          label,
          style: _jak(
            size: 13,
            weight: FontWeight.w700,
            color: active ? AppColors.surface : AppColors.ink,
          ),
        ),
      ),
    );
  }

  // ── Thumbnail ──────────────────────────────────────────────────────────────

  Widget _buildThumbnail(Transaction tx, int step) {
    final images = tx.product?['images'];
    String? imageUrl;
    if (images is List && images.isNotEmpty) {
      final img = images.first.toString();
      imageUrl = img.startsWith('http') ? img : '${AppConfig.uploadsUrl}/$img';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      size: 22, color: AppColors.textHint),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      size: 22, color: AppColors.textHint),
                ),
              )
            : Center(
                child: Icon(
                  tx.type == 'RENT'
                      ? Icons.autorenew_rounded
                      : Icons.shopping_bag_outlined,
                  size: 24,
                  color: step == 4 ? AppColors.ink : AppColors.textHint,
                ),
              ),
      ),
    );
  }

  // ── Transaction card ───────────────────────────────────────────────────────

  Widget _txCard(Transaction tx) {
    final step = _statusStep(tx.status, type: tx.type);
    final productTitle =
        tx.product?['title'] as String? ?? 'Product';
    final partner = _partnerName(tx);
    final roleWord = _showBuying ? 'from' : 'to';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(
              transaction: tx,
              currentUserId: widget.userId,
            ),
          ),
        );
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──────────────────────────────────────────
            _buildThumbnail(tx, step),
            const SizedBox(width: 10),

            // ── Text + stepper ─────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          productTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _jak(
                              size: 13, weight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '฿${tx.price}',
                        style: _jak(
                            size: 13, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$roleWord @$partner',
                    style: _mono(
                        size: 9, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  _MiniStepper(step: step, isRent: tx.type == 'RENT'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────

  Widget _skeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail placeholder
              _shimmer(width: 60, height: 60, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _shimmer(width: double.infinity, height: 13, radius: 6)),
                        const SizedBox(width: 12),
                        _shimmer(width: 52, height: 13, radius: 6),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _shimmer(width: 100, height: 9, radius: 4),
                    const SizedBox(height: 12),
                    // Stepper placeholder
                    Row(
                      children: [
                        for (int i = 0; i < 4; i++) ...[
                          _shimmer(width: 14, height: 14, radius: 99),
                          if (i < 3)
                            Expanded(child: _shimmer(width: double.infinity, height: 2, radius: 1)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmer({required double width, required double height, required double radius}) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 52, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            'No orders yet',
            style: _sans(
                size: 16,
                weight: FontWeight.w600,
                color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            _showBuying
                ? 'Items you buy will appear here'
                : 'Items you sell will appear here',
            style: _mono(size: 10, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Could not load orders',
              style: _sans(size: 15, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _load,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Retry',
                  style: _sans(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.surface)),
            ),
          ),
        ],
      ),
    );
  }
}
