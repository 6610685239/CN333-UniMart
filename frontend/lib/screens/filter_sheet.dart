import 'package:flutter/material.dart';
import '../services/filter_service.dart';
import '../models/product.dart';

class FilterSheet extends StatefulWidget {
  final Function(List<Product>? products, int totalCount)? onFilterApplied;

  const FilterSheet({super.key, this.onFilterApplied});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  static const Color _primaryColor = Color(0xFFFF6F61);

  // Filter values
  String? _selectedFaculty;
  String? _selectedDormitoryZone;
  String? _selectedMeetingPoint;
  double _minCredit = 0;

  // Data from API
  List<Map<String, dynamic>> _meetingPoints = [];
  List<String> _dormitoryZones = [];
  bool _isLoadingData = true;
  bool _isFiltering = false;
  int? _matchCount;

  // Faculty list (common TU faculties)
  final List<String> _faculties = [
    'วิศวกรรมศาสตร์',
    'วิทยาศาสตร์และเทคโนโลยี',
    'นิติศาสตร์',
    'พาณิชยศาสตร์และการบัญชี',
    'รัฐศาสตร์',
    'เศรษฐศาสตร์',
    'สังคมสงเคราะห์ศาสตร์',
    'ศิลปศาสตร์',
    'วารสารศาสตร์และสื่อสารมวลชน',
    'สังคมวิทยาและมานุษยวิทยา',
    'สถาปัตยกรรมศาสตร์และการผังเมือง',
    'แพทยศาสตร์',
    'สหเวชศาสตร์',
    'ทันตแพทยศาสตร์',
    'พยาบาลศาสตร์',
    'สาธารณสุขศาสตร์',
    'เภสัชศาสตร์',
    'ศิลปกรรมศาสตร์',
    'วิทยาลัยนวัตกรรม',
    'วิทยาลัยสหวิทยาการ',
    'วิทยาลัยนานาชาติปรีดี พนมยงค์',
  ];

  @override
  void initState() {
    super.initState();
    _loadFilterData();
  }

  Future<void> _loadFilterData() async {
    try {
      final results = await Future.wait([
        FilterService.getMeetingPoints(),
        FilterService.getDormitoryZones(),
      ]);
      if (mounted) {
        setState(() {
          _meetingPoints = results[0] as List<Map<String, dynamic>>;
          _dormitoryZones = results[1] as List<String>;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  Future<void> _applyFilter() async {
    setState(() => _isFiltering = true);
    try {
      final result = await FilterService.filterProducts(
        faculty: _selectedFaculty,
        dormitoryZone: _selectedDormitoryZone,
        meetingPoint: _selectedMeetingPoint,
        minCredit: _minCredit > 0 ? _minCredit : null,
      );

      final productsJson = result['products'] as List<dynamic>? ?? [];
      final products = productsJson
          .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
          .toList();
      final totalCount = result['totalCount'] as int? ?? products.length;

      if (mounted) {
        setState(() {
          _matchCount = totalCount;
          _isFiltering = false;
        });
        widget.onFilterApplied?.call(products, totalCount);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFiltering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('กรองสินค้าไม่สำเร็จ: $e')),
        );
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedFaculty = null;
      _selectedDormitoryZone = null;
      _selectedMeetingPoint = null;
      _minCredit = 0;
      _matchCount = null;
    });
    widget.onFilterApplied?.call(null, 0);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: _isLoadingData
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  const Text(
                    'กรองสินค้า',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Faculty dropdown
                  _buildDropdown(
                    label: 'คณะ',
                    value: _selectedFaculty,
                    items: _faculties,
                    onChanged: (val) => setState(() => _selectedFaculty = val),
                  ),
                  const SizedBox(height: 16),
                  // Dormitory zone dropdown
                  _buildDropdown(
                    label: 'โซนหอพัก',
                    value: _selectedDormitoryZone,
                    items: _dormitoryZones,
                    onChanged: (val) =>
                        setState(() => _selectedDormitoryZone = val),
                  ),
                  const SizedBox(height: 16),
                  // Meeting point dropdown
                  _buildDropdown(
                    label: 'จุดนัดพบ',
                    value: _selectedMeetingPoint,
                    items: _meetingPoints.map((mp) => mp['name'] as String).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedMeetingPoint = val),
                  ),
                  const SizedBox(height: 16),
                  // Min credit slider
                  _buildCreditSlider(),
                  const SizedBox(height: 24),
                  // Match count
                  if (_matchCount != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: Text(
                          'พบสินค้า $_matchCount รายการ',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetFilters,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('ล้างตัวกรอง'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isFiltering ? null : _applyFilter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isFiltering
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('ค้นหา'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text('เลือก$label', style: TextStyle(color: Colors.grey[500])),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: items.map((item) {
                return DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 14)));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreditSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'คะแนนเครดิตขั้นต่ำ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              _minCredit > 0 ? _minCredit.toStringAsFixed(1) : 'ไม่จำกัด',
              style: TextStyle(
                color: _minCredit > 0 ? _primaryColor : Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: _minCredit,
          min: 0,
          max: 5,
          divisions: 10,
          activeColor: _primaryColor,
          label: _minCredit > 0 ? _minCredit.toStringAsFixed(1) : 'ไม่จำกัด',
          onChanged: (val) => setState(() => _minCredit = val),
        ),
      ],
    );
  }
}
