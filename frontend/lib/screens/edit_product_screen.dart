import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../models/product.dart'; // เรียกใช้ Model

class EditProductScreen extends StatefulWidget {
  final Product product; // รับเป็น Product Object

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late String _selectedCondition;
  late TextEditingController _locationCtrl;

  @override
  void initState() {
    super.initState();
    // ดึงค่าจาก Model มาใส่
    _titleCtrl = TextEditingController(text: widget.product.title);
    _descCtrl = TextEditingController(text: widget.product.description);
    _priceCtrl = TextEditingController(text: widget.product.price.toString());
    _selectedCondition = widget.product.condition;
    _locationCtrl = TextEditingController(text: widget.product.location);
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final url = Uri.parse('${ApiService.baseUrl}/products/${widget.product.id}');
    try {
      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "title": _titleCtrl.text,
          "description": _descCtrl.text,
          "price": _priceCtrl.text,
          "condition": _selectedCondition,
          "location": _locationCtrl.text,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("แก้ไขไม่สำเร็จ")));
      }
    } catch (e) {
      print("Error updating: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("แก้ไขสินค้า")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: "ชื่อสินค้า")),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: "รายละเอียด"), maxLines: 3),
            TextFormField(controller: _priceCtrl, decoration: const InputDecoration(labelText: "ราคา"), keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: _selectedCondition,
              items: ['มือหนึ่ง', 'มือสอง (สภาพดี)', 'มือสอง (มีตำหนิ)']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCondition = v!),
              decoration: const InputDecoration(labelText: "สภาพ"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _updateProduct, child: const Text("บันทึกการแก้ไข")),
          ],
        ),
      ),
    );
  }
}