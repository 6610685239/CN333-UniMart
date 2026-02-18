import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart'; // เรียกใช้ baseUrl จากที่นี่
import 'package:image_cropper/image_cropper.dart';

class AddProductScreen extends StatefulWidget {
  final int userId;
  const AddProductScreen({super.key, required this.userId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  // ข้อมูลสำหรับ Dropdown
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  String _selectedCondition = 'มือหนึ่ง';
  final List<String> _conditions = [
    'มือหนึ่ง',
    'มือสอง (สภาพดี)',
    'มือสอง (มีตำหนิ)',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

Future<File?> _cropImage(XFile imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      // กำหนดขนาดสูงสุด
      maxWidth: 1080,
      maxHeight: 1080,
      // ย้ายการตั้งค่าเข้าไปใน uiSettings
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'จัดระเบียบรูปภาพ',
          toolbarColor: Colors.white,
          toolbarWidgetColor: Colors.black,
          activeControlsWidgetColor: Colors.black,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          // ⭐ ย้าย aspectRatioPresets มาไว้ตรงนี้ (สำหรับ Android)
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'จัดระเบียบรูปภาพ',
          // ⭐ และไว้ตรงนี้ (สำหรับ iOS)
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }

  // 3. แก้ไขฟังก์ชันเลือกรูป ให้เรียกใช้การ Crop
  Future<void> _pickImages() async {
    // เลือกหลายรูปมาก่อน
    final List<XFile> images = await _picker.pickMultiImage();

    if (images.isNotEmpty) {
      List<File> croppedImages = [];

      // วนลูปเอารูปไปเข้าเครื่อง Crop ทีละรูป
      for (var image in images) {
        File? cropped = await _cropImage(image);
        if (cropped != null) {
          croppedImages.add(cropped);
        }
      }

      // ถ้าได้รูปที่ Crop แล้ว ค่อยเอามาใส่ใน List หลัก
      if (croppedImages.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(croppedImages);
        });
      }
    }
  }

  Future<void> _fetchCategories() async {
    try {
      // ใช้ baseUrl จาก ApiService ได้เลย
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/categories'),
      );
      if (response.statusCode == 200) {
        // ตรงนี้ถ้าขยันควรสร้าง Model Category นะ แต่ใช้ Map ไปก่อนได้
        final List<dynamic> data = jsonDecode(response.body);
        // *หมายเหตุ: ถ้าโค้ดเดิมใช้ jsonDecode จาก convert ต้อง import 'dart:convert'; ด้วย
        // หรือใช้แบบง่ายๆ คือดึง jsonDecode มา

        setState(() {
          _categories = data;
          if (_categories.isNotEmpty) {
            _selectedCategoryId = _categories[0]['id'].toString();
          }
        });
      }
    } catch (e) {
      print("Error loading categories: $e");
    }
  }

  // Future<void> _pickImages() async {
  //   final List<XFile> images = await _picker.pickMultiImage();
  //   if (images.isNotEmpty) {
  //     setState(() {
  //       _selectedImages.addAll(images.map((x) => File(x.path)));
  //     });
  //   }
  // }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/products'),
    );

    request.fields['title'] = _titleCtrl.text;
    request.fields['description'] = _descCtrl.text;
    request.fields['price'] = _priceCtrl.text;
    request.fields['condition'] = _selectedCondition;
    request.fields['categoryId'] = _selectedCategoryId!;
    request.fields['ownerId'] = widget.userId.toString();

    for (var file in _selectedImages) {
      request.files.add(await http.MultipartFile.fromPath('images', file.path));
    }

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("ลงสินค้าไม่สำเร็จ")));
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ต้อง import 'dart:convert' เพื่อใช้ jsonDecode ข้างบน หรือถ้าใช้ http.get แล้ว response.body เป็น string
    // เพื่อความชัวร์ในส่วน import:
    // อย่าลืมเพิ่ม: import 'dart:convert'; ข้างบนสุดด้วยนะครับ

    return Scaffold(
      appBar: AppBar(title: const Text("ลงขายสินค้า")),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ส่วนเลือกรูป
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.add_a_photo),
                      ),
                    ),
                    ..._selectedImages.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Image.file(
                          f,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: "ชื่อสินค้า"),
                validator: (v) => v!.isEmpty ? 'ระบุชื่อ' : null,
              ),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: "รายละเอียด"),
                maxLines: 3,
              ),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(labelText: "ราคา"),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCondition,
                      items: _conditions
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCondition = v!),
                      decoration: const InputDecoration(labelText: "สภาพ"),
                    ),
                  ),
                ],
              ),

              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                hint: const Text("เลือกหมวดหมู่"),
                items: _categories.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['id'].toString(),
                    child: Text(item['name']),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
                decoration: const InputDecoration(labelText: "หมวดหมู่"),
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("ลงขายทันที"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
