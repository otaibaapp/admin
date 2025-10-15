import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'merchant_dashboard.dart';

class AdminStoreEditor extends StatefulWidget {
  const AdminStoreEditor({super.key});

  @override
  State<AdminStoreEditor> createState() => _AdminStoreEditorState();
}

class _AdminStoreEditorState extends State<AdminStoreEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _deliveryTimeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discountController = TextEditingController();
  final _orderController = TextEditingController();

  String _deliveryMethod = "عبر التطبيق";
  String _category = "مطاعم";
  bool _isVerified = false;

  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  File? _imageFile;
  String? _existingStoreId;
  String? _storeImageUrl;


  final picker = ImagePicker();
  final _databaseRef =
  FirebaseDatabase.instance.ref("otaibah_navigators_taps/shopping/categories");

  final Color gold = const Color(0xFF988561);
  final Color gray = Colors.white;

  List<String> _categories = ["مطاعم", "حلويات", "خضار", "كهربائيات"];

  bool _loading = true;


  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadCategories(); // ننتظر التصنيفات أولاً
    await _loadMyStore();    // بعدين نجيب بيانات المتجر
    setState(() => _loading = false);
  }


  Future<void> _loadCategories() async {
    try {
      final snap = await _databaseRef.get();
      final names = <String>[];
      if (snap.exists && snap.value is Map) {
        final map = snap.value as Map;
        for (final k in map.keys) {
          names.add(k.toString());
        }
      }
      names.sort();
      setState(() {
        if (names.isNotEmpty) _categories = names;
      });
    } catch (_) {}
  }

  Future<void> _loadMyStore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userSnap =
    await FirebaseDatabase.instance.ref("otaibah_users/${user.uid}").get();
    if (!userSnap.exists) return;

    final userData = Map<String, dynamic>.from(userSnap.value as Map);
    if (userData["shopId"] != null) {
      final storeId = userData["shopId"];
      for (final cat in _categories) {
        final storeSnap = await _databaseRef.child(cat).child(storeId).get();
        if (storeSnap.exists) {
          final store = Map<String, dynamic>.from(storeSnap.value as Map);
          setState(() {
            _existingStoreId = storeId;
            _category = cat;
            _nameController.text = store["name"] ?? "";
            _deliveryTimeController.text = store["deliveryTime"] ?? "";
            _descriptionController.text = store["description"] ?? "";
            _discountController.text = store["discountText"] ?? "";
            _orderController.text = store["order"]?.toString() ?? "";
            _deliveryMethod = store["deliveryMethod"] ?? "عبر التطبيق";
            _isVerified = store["isVerified"] == true;
            _storeImageUrl = store["imageUrl"];

            if (store["openTime"] != null && store["openTime"].contains(":")) {
              final parts = store["openTime"].split(":");
              _openTime = TimeOfDay(
                  hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            }
            if (store["closeTime"] != null && store["closeTime"].contains(":")) {
              final parts = store["closeTime"].split(":");
              _closeTime = TimeOfDay(
                  hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            }
          });
          break;
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final original = File(picked.path);

    try {
      final targetPath = p.join(
        p.dirname(original.path),
        "${DateTime.now().millisecondsSinceEpoch}_compressed.jpg",
      );

      final compressed = await FlutterImageCompress.compressAndGetFile(
        original.path,
        targetPath,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      setState(() => _imageFile = compressed != null ? File(compressed.path) : original);
    } catch (_) {
      setState(() => _imageFile = original);
    }
  }

  Future<String> _uploadImage(String storeId) async {
    if (_imageFile == null) return "";
    final ref =
    FirebaseStorage.instance.ref().child("otaibah_stores_images/$storeId.jpg");
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _saveToFirebase() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final order = int.tryParse(_orderController.text.trim()) ?? 9999;

    if (_existingStoreId != null) {
      final imageUrl = await _uploadImage(_existingStoreId!);
      await _databaseRef.child(_category).child(_existingStoreId!).update({
        "name": _nameController.text.trim(),
        if (imageUrl.isNotEmpty) "imageUrl": imageUrl,
        "deliveryTime": _deliveryTimeController.text.trim(),
        "deliveryMethod": _deliveryMethod,
        "openTime": _openTime?.format(context) ?? "",
        "closeTime": _closeTime?.format(context) ?? "",
        "description": _descriptionController.text.trim(),
        "discountText": _discountController.text.trim(),
        "category": _category,
        "order": order,
        "isVerified": _isVerified,
      });
    } else {
      final newRef = _databaseRef.child(_category).push();
      final id = newRef.key!;
      final imageUrl = await _uploadImage(id);

      await newRef.set({
        "name": _nameController.text.trim(),
        "imageUrl": imageUrl,
        "deliveryTime": _deliveryTimeController.text.trim(),
        "deliveryMethod": _deliveryMethod,
        "openTime": _openTime?.format(context) ?? "",
        "closeTime": _closeTime?.format(context) ?? "",
        "description": _descriptionController.text.trim(),
        "discountText": _discountController.text.trim(),
        "category": _category,
        "createdAt": DateTime.now().toIso8601String(),
        "order": order,
        "ownerId": user.uid,
        "isVerified": _isVerified,
      });

      await FirebaseDatabase.instance
          .ref("otaibah_users/${user.uid}")
          .update({"shopId": id});

      setState(() => _existingStoreId = id);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم حفظ بيانات المتجر بنجاح")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantDashboard(shopId: _existingStoreId ?? ""),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? value, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value != null ? value.format(context) : label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(Icons.access_time, color: Colors.black54, size: 20),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.black,
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            "بيانات المتجر",
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ بانر الصورة العلوي
                Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _pickImage,
                    child: _imageFile != null
                        ? Image.file(_imageFile!,
                        width: double.infinity, fit: BoxFit.cover)
                        : (_storeImageUrl != null &&
                        _storeImageUrl!.isNotEmpty)
                        ? Image.network(_storeImageUrl!,
                        width: double.infinity, fit: BoxFit.cover)
                        : const Center(
                      child: Icon(Icons.camera_alt,
                          color: Colors.black45, size: 38),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ✅ حقول البيانات بنفس تصميم الطلبات
                _buildTextField(_nameController, "اسم المتجر", validator: true),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: _dropdownDecoration("فئة المتجر"),
                  items: _categories
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: _deliveryMethod,
                  decoration: _dropdownDecoration("طريقة التوصيل"),
                  items: const [
                    DropdownMenuItem(
                        value: "عبر التطبيق", child: Text("عبر التطبيق")),
                    DropdownMenuItem(
                        value: "عبر المتجر ذاته", child: Text("عبر المتجر ذاته")),
                  ],
                  onChanged: (v) => setState(() => _deliveryMethod = v!),
                ),
                const SizedBox(height: 14),

                _buildTextField(
                    _deliveryTimeController, "مدة التوصيل (مثلاً 30 دقيقة)"),
                const SizedBox(height: 14),

                Row(
                  children: [
                    _timeField("وقت الفتح", _openTime, () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime:
                        _openTime ?? const TimeOfDay(hour: 9, minute: 0),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Colors.black,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                                secondary: Color(0xFFafafaf),
                              ),
                              timePickerTheme: const TimePickerThemeData(
                                backgroundColor: Colors.white,
                                helpTextStyle: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                                hourMinuteTextColor: Colors.black,
                                hourMinuteShape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                                  side: BorderSide(color: Colors.black12),
                                ),
                                hourMinuteColor: Color(0xFFF5F5F5),
                                hourMinuteTextStyle: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                dialBackgroundColor: Color(0xFFF8F8F8),
                                dialHandColor: Color(0xFFafafaf),
                                dialTextColor: Colors.black87,
                                dayPeriodTextColor: Colors.black87,
                                dayPeriodColor: Color(0xFFEAF1F8),
                                dayPeriodShape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                                  side: BorderSide(color: Colors.black12),
                                ),
                                entryModeIconColor: Colors.black54,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: ButtonStyle(
                                  foregroundColor:
                                  MaterialStatePropertyAll(Colors.black),
                                  textStyle: MaterialStatePropertyAll(TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) setState(() => _openTime = time);
                    }),
                    _timeField("وقت الإغلاق", _closeTime, () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime:
                        _openTime ?? const TimeOfDay(hour: 9, minute: 0),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Colors.black,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                                secondary: Color(0xFFafafaf),
                              ),
                              timePickerTheme: const TimePickerThemeData(
                                backgroundColor: Colors.white,
                                helpTextStyle: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                                hourMinuteTextColor: Colors.black,
                                hourMinuteShape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                                  side: BorderSide(color: Colors.black12),
                                ),
                                hourMinuteColor: Color(0xFFF5F5F5),
                                hourMinuteTextStyle: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                dialBackgroundColor: Color(0xFFF8F8F8),
                                dialHandColor: Color(0xFFafafaf),
                                dialTextColor: Colors.black87,
                                dayPeriodTextColor: Colors.black87,
                                dayPeriodColor: Color(0xFFEAF1F8),
                                dayPeriodShape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                                  side: BorderSide(color: Colors.black12),
                                ),
                                entryModeIconColor: Colors.black54,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: ButtonStyle(
                                  foregroundColor:
                                  MaterialStatePropertyAll(Colors.black),
                                  textStyle: MaterialStatePropertyAll(TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) setState(() => _closeTime = time);
                    }),
                  ],
                ),
                const SizedBox(height: 14),

                _buildTextField(_discountController, "نص الخصم (اختياري)"),
                const SizedBox(height: 14),

                _buildTextField(_orderController, "رقم الترتيب (اختياري)",
                    keyboardType: TextInputType.number),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: "الوصف",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _saveToFirebase,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      "نشر المتجر",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 40), // ✅ مسافة إضافية من الأسفل
              ],
            ),
          ),
        ),
      ),
    );
  }


  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool validator = false, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator
          ? (v) => v == null || v.isEmpty ? "أدخل $label" : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}
