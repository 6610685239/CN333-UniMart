import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/filter_service.dart';
import '../config.dart';
import 'package:dotted_border/dotted_border.dart';
import 'my_shop_screen.dart';
import 'package:image_cropper/image_cropper.dart';

class AddProductScreen extends StatefulWidget {
  final String userId;

  const AddProductScreen({super.key, required this.userId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _selectedType = 'SALE';

  // Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  String _selectedCondition = 'มือหนึ่ง';
  String? _selectedCategoryId;

  List<dynamic> _categories = [];
  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  // Meeting points
  List<Map<String, dynamic>> _meetingPoints = [];
  String? _selectedMeetingPointId;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchMeetingPoints();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/categories'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _categories = data;
          if (_categories.isNotEmpty) {
            _selectedCategoryId = _categories[0]['id'].toString();
          } else {
            _selectedCategoryId = null;
          }
        });
      }
    } catch (e) {
      print("Error loading categories: $e");
    }
  }

  Future<void> _fetchMeetingPoints() async {
    try {
      final points = await FilterService.getMeetingPoints();
      if (mounted) {
        setState(() {
          _meetingPoints = points;
        });
      }
    } catch (e) {
      print("Error loading meeting points: $e");
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();

      if (images.isNotEmpty) {
        for (var img in images) {
          if (_selectedImages.length >= 5) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("ใส่รูปได้สูงสุด 5 รูปเท่านั้นครับ")),
            );
            break;
          }

          // บน web ข้าม cropper เพราะ image_cropper ไม่รองรับ web
          if (kIsWeb) {
            setState(() => _selectedImages.add(img));
          } else {
            CroppedFile? croppedFile = await ImageCropper().cropImage(
              sourcePath: img.path,
              uiSettings: [
                AndroidUiSettings(
                  toolbarTitle: 'ปรับขนาดรูปภาพ',
                  toolbarColor: Colors.black,
                  toolbarWidgetColor: Colors.white,
                  initAspectRatio: CropAspectRatioPreset.square,
                  lockAspectRatio: false,
                  aspectRatioPresets: [
                    CropAspectRatioPreset.square,
                    CropAspectRatioPreset.ratio4x3,
                    CropAspectRatioPreset.original,
                  ],
                ),
                IOSUiSettings(
                  title: 'ปรับขนาดรูปภาพ',
                  cancelButtonTitle: 'ยกเลิก',
                  doneButtonTitle: 'เสร็จสิ้น',
                  aspectRatioPresets: [
                    CropAspectRatioPreset.square,
                    CropAspectRatioPreset.ratio4x3,
                    CropAspectRatioPreset.original,
                  ],
                ),
              ],
            );
            if (croppedFile != null) {
              setState(() => _selectedImages.add(XFile(croppedFile.path)));
            }
          }
        }
      }
    } catch (e) {
      print("Error picking/cropping images: $e");
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบถ้วน")),
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาใส่รูปอย่างน้อย 1 รูป")),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("กรุณาเลือกหมวดหมู่")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/products'),
      );

      request.fields['title'] = _titleCtrl.text;
      request.fields['description'] = _descCtrl.text;
      request.fields['type'] = _selectedType;
      if (_selectedType == 'SALE') {
        request.fields['price'] = _priceCtrl.text;
        // ไม่ต้องส่ง rentPrice
      } else {
        request.fields['price'] = '0'; // ถ้าเป็นของเช่า ให้ราคาขายหลักเป็น 0
        request.fields['rentPrice'] =
            _priceCtrl.text; // เอาตัวเลขไปใส่ช่องราคาเช่าแทน
      }
      // request.fields['price'] = _priceCtrl.text;
      request.fields['condition'] = _selectedCondition;
      request.fields['categoryId'] = _selectedCategoryId!;
      request.fields['location'] = _locationCtrl.text;
      request.fields['ownerId'] = widget.userId.toString();

      if (_selectedMeetingPointId != null) {
        request.fields['meetingPointId'] = _selectedMeetingPointId!;
      }

      for (var file in _selectedImages) {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('images', bytes, filename: file.name),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("ลงขายสำเร็จ!")));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MyShopScreen(currentUserId: widget.userId),
            ),
          );
        }
      } else {
        throw Exception("Server Error: ${response.body}");
      }
    } catch (e) {
      print("Submit Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ⭐ ฟังก์ชันช่วยสร้างกล่องครอบช่อง input แบบในภาพ ⭐
  Widget _buildFieldContainer({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white, // สีพื้นหลังเทาอ่อน
            border: Border.all(color: Colors.grey[400]!), // ขอบสีเทา
            borderRadius: BorderRadius.circular(4), // ขอบมน
          ),
          child: child,
        ),
      ],
    );
  }

  // ⭐ วิดเจ็ตสำหรับกล่องเลือกรูปภาพแบบใหม่ ⭐
  // ⭐ วิดเจ็ตสำหรับกล่องเลือกรูปภาพแบบใหม่ (ขอบเส้นประ) ⭐
  Widget _buildImagePickerBox() {
    return GestureDetector(
      onTap: _pickImages,
      child: DottedBorder(
        borderType: BorderType.RRect, // กำหนดให้เป็นสี่เหลี่ยมขอบมน
        radius: const Radius.circular(
          4,
        ), // ความโค้งของมุม (ให้เท่ากับ Container ด้านใน)
        padding: EdgeInsets.zero, // ลบ padding ของ DottedBorder ออก
        color: Colors.grey[400]!, // สีของเส้นประ (เข้มกว่าพื้นหลังนิดนึงจะสวย)
        strokeWidth: 2, // ความหนาของเส้น
        dashPattern: const [
          4,
          3,
        ], // รูปแบบเส้นประ: [ความยาวขีด, ความยาวช่องว่าง]
        child: Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white, // สีพื้นหลังเทาอ่อนมาก (อยู่ข้างในเส้นประ)
            borderRadius: BorderRadius.circular(4),
            // ❌ ไม่ต้องมี border ตรงนี้แล้ว เพราะ DottedBorder จัดการให้
          ),
          child: _selectedImages.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Colors.grey[600],
                    ), // เปลี่ยนไอคอนให้ดูทันสมัยขึ้น
                    const SizedBox(height: 8),
                    Text(
                      "Upload product photos",
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "(Up to 5 photos)",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  itemCount: _selectedImages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _selectedImages.length) {
                      // ปุ่มเพิ่มรูปต่อท้าย (ทำเป็นเส้นประเล็กๆ ด้วยก็ได้ถ้าชอบ)
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ), // อันเล็กใช้เส้นทึบบางๆ ก็พอ
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.grey,
                            size: 30,
                          ),
                        ),
                      );
                    }
                    // ... (ส่วนแสดงรูปภาพที่เลือกเหมือนเดิม) ...
                    final file = _selectedImages[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: FutureBuilder<Uint8List>(
                              future: file.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(
                                    snapshot.data!,
                                    width: 120,
                                    height: 160,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return Container(
                                  width: 120, height: 160,
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedImages.remove(file)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _selectedType == 'SALE' ? "Sell" : "Rent",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ช่องเลือกรูปภาพแบบใหม่
                    _buildImagePickerBox(),
                    const SizedBox(height: 30),

                    _buildFieldContainer(
                      label: "Listing Option",
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text(
                                "Sell",
                                style: TextStyle(fontSize: 14),
                              ),
                              value: 'SALE',
                              groupValue: _selectedType,
                              activeColor: Colors.black,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) =>
                                  setState(() => _selectedType = val!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text(
                                "Rent",
                                style: TextStyle(fontSize: 14),
                              ),
                              value: 'RENT',
                              groupValue: _selectedType,
                              activeColor: Colors.black,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) =>
                                  setState(() => _selectedType = val!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ชื่อสินค้า
                    _buildFieldContainer(
                      label: "Title",
                      child: TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'e.g. iPhone 17 Pro Max',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'กรุณากรอกชื่อสินค้า' : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // รายละเอียด
                    _buildFieldContainer(
                      label: "Description",
                      child: TextFormField(
                        controller: _descCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText:
                              'Details about the product, e.g. color, size, defects, reason for selling, etc.',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'กรุณากรอกรายละเอียด' : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // // ราคา
                    // _buildFieldContainer(
                    //   label: "Price",
                    //   child: TextFormField(
                    //     controller: _priceCtrl,
                    //     keyboardType: TextInputType.number,
                    //     decoration: const InputDecoration(
                    //       border: InputBorder.none,
                    //       hintText: 'Add your price in Baht',
                    //       hintStyle: TextStyle(
                    //         color: Colors.grey,
                    //         fontSize: 14,
                    //       ),
                    //     ),
                    //     validator: (v) => v!.isEmpty ? 'กรุณากรอกราคา' : null,
                    //   ),
                    // ),
                    // const SizedBox(height: 20),
                    // ราคา
                    _buildFieldContainer(
                      // ⭐ ถ้าเลือก RENT ให้เขียนว่า "ราคาเช่าต่อวัน", ถ้าไม่ใช่ เขียน "ราคาขาย"
                      label: _selectedType == 'RENT'
                          ? "Rent Price (Baht/day)"
                          : "Selling Price (Baht)",
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          // ⭐ เปลี่ยน hintText ให้สอดคล้องกัน
                          hintText: _selectedType == 'RENT'
                              ? 'e.g. 50'
                              : 'e.g. 15900',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        validator: (v) => v!.isEmpty ? 'กรุณากรอกราคา' : null,
                      ),
                    ),

                    // สถานที่ / จุดนัดพบ (พิมพ์เอง)
                    _buildFieldContainer(
                      label: "Meeting Point",
                      child: TextFormField(
                        controller: _locationCtrl,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(Icons.location_on_outlined, color: Colors.grey),
                          hintText: 'เช่น หน้าลิฟต์ รพ., ตรงข้ามเซเว่นอินเตอร์',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'กรุณากรอกสถานที่นัดพบ' : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // หมวดหมู่ และ สภาพสินค้า (อยู่ในแถวเดียวกัน)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // หมวดหมู่
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Category",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[400]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: _categories.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        child: Text(
                                          "กำลังโหลด...",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      )
                                    : DropdownButtonHideUnderline(
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedCategoryId,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                          ),
                                          isExpanded: true,
                                          icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                          ),
                                          items: _categories
                                              .map<DropdownMenuItem<String>>((
                                                item,
                                              ) {
                                                return DropdownMenuItem<String>(
                                                  value: item['id'].toString(),
                                                  child: Text(
                                                    item['name'],
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                );
                                              })
                                              .toList(),
                                          onChanged: (val) => setState(
                                            () => _selectedCategoryId = val,
                                          ),
                                          validator: (v) =>
                                              v == null ? 'กรุณาเลือก' : null,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // สภาพสินค้า
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Condition",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[400]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCondition,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                    isExpanded: true,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                    ),
                                    items:
                                        [
                                          'มือหนึ่ง',
                                          'มือสอง (สภาพดี)',
                                          'มือสอง (มีตำหนิ)',
                                        ].map((String val) {
                                          return DropdownMenuItem(
                                            value: val,
                                            child: Text(
                                              val,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (val) => setState(
                                      () => _selectedCondition = val!,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // ปุ่มลงขาย
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, // สีปุ่มดำ
                          foregroundColor: Colors.white, // ตัวหนังสือขาว
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          "Submit",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
