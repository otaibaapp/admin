import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
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
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  File? _imageFile;

  String? _existingStoreId;

  // مسار الفئات
  final _databaseRef =
  FirebaseDatabase.instance.ref("otaibah_navigators_taps/shopping/categories");
  final picker = ImagePicker();

  // قائمة فئات افتراضية — تتحدث من فيربيز
  List<String> _categories = ["مطاعم", "حلويات", "لحوم", "خضار", "كهربائيات"];

  // ألوان وهوية
  final Color gold = const Color(0xFF988561);
  final Color gray = Colors.grey.shade100;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadMyStore();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deliveryTimeController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    _orderController.dispose();
    super.dispose();
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
        if (!_categories.contains(_category)) {
          _category = _categories.first;
        }
      });
    } catch (_) {}
  }

  // تحميل بيانات متجر المستخدم إن وُجد
  Future<void> _loadMyStore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userSnap =
    await FirebaseDatabase.instance.ref("otaibah_users/${user.uid}").get();
    if (userSnap.exists) {
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

              if ((store["openTime"] ?? "").toString().contains(":")) {
                final parts = store["openTime"].split(":");
                _openTime = TimeOfDay(
                    hour: int.parse(parts[0]), minute: int.parse(parts[1]));
              }
              if ((store["closeTime"] ?? "").toString().contains(":")) {
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
  }

  // اختيار صورة + ضغطها قبل الحفظ
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
    } catch (e) {
      debugPrint("❌ خطأ أثناء ضغط الصورة: $e");
      setState(() => _imageFile = original);
    }

  }

  Future<String> _uploadImage(String storeId) async {
    if (_imageFile == null) return "";
    final ref = FirebaseStorage.instance
        .ref()
        .child("otaibah_stores_images/$storeId.jpg");
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _saveToFirebase() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ يجب تسجيل الدخول أولاً")),
      );
      return;
    }

    final int order = int.tryParse(_orderController.text.trim()) ?? 9999;

    if (_existingStoreId != null) {
      // تحديث متجر موجود
      final imageUrl = await _uploadImage(_existingStoreId!);
      await _databaseRef.child(_category).child(_existingStoreId!).update({
        "name": _nameController.text.trim(),
        if (imageUrl.isNotEmpty) "imageUrl": imageUrl,
        "deliveryTime": _deliveryTimeController.text.trim(),
        "deliveryMethod": _deliveryMethod,
        "openTime": _openTime != null ? _openTime!.format(context) : "",
        "closeTime": _closeTime != null ? _closeTime!.format(context) : "",
        "description": _descriptionController.text.trim(),
        "discountText": _discountController.text.trim(),
        "category": _category,
        "order": order,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم تحديث بيانات المتجر")),
      );
    } else {
      // إنشاء متجر جديد
      final newStoreRef = _databaseRef.child(_category).push();
      final storeId = newStoreRef.key!;
      final imageUrl = await _uploadImage(storeId);

      await newStoreRef.set({
        "name": _nameController.text.trim(),
        "imageUrl": imageUrl,
        "deliveryTime": _deliveryTimeController.text.trim(),
        "deliveryMethod": _deliveryMethod,
        "openTime": _openTime != null ? _openTime!.format(context) : "",
        "closeTime": _closeTime != null ? _closeTime!.format(context) : "",
        "description": _descriptionController.text.trim(),
        "discountText": _discountController.text.trim(),
        "category": _category,
        "createdAt": DateTime.now().toIso8601String(),
        "order": order,
        "products": {},
        "categories": {},
        "ownerId": user.uid,
      });

      await FirebaseDatabase.instance
          .ref("otaibah_users/${user.uid}")
          .update({"shopId": storeId});

      setState(() => _existingStoreId = storeId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم إنشاء المتجر بنجاح")),
      );
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => MerchantDashboard(shopId: _existingStoreId ?? "")),
      );
    }
  }

  // اختيار ساعات العمل (بداية ثم نهاية)
  Future<void> _pickTimeRange() async {
    final open = await showTimePicker(
      context: context,
      initialTime: _openTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (open == null) return;

    final close = await showTimePicker(
      context: context,
      initialTime: _closeTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (close == null) return;

    setState(() {
      _openTime = open;
      _closeTime = close;
    });
  }

  // ستايل الحقول: بدون إطار خارجي، خط سفلي فقط
  InputDecoration _inputStyle(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: gold, fontWeight: FontWeight.w600),
    border: InputBorder.none,
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: gold.withOpacity(0.5), width: 1),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: gold, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: gray,
        appBar: AppBar(
          title: const Text("إضافة / تعديل متجر"),
          backgroundColor: gold,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // صورة المتجر
                  GestureDetector(
                    onTap: _pickImage,
                    child: _imageFile != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        _imageFile!,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.camera_alt,
                          color: gold.withOpacity(0.7), size: 40),
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _nameController,
                    decoration: _inputStyle("اسم المتجر"),
                    validator: (v) =>
                    v == null || v.isEmpty ? "يرجى إدخال اسم المتجر" : null,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _deliveryMethod,
                    decoration: _inputStyle("طريقة التوصيل"),
                    items: const [
                      DropdownMenuItem(
                          value: "عبر التطبيق", child: Text("عبر التطبيق")),
                      DropdownMenuItem(
                          value: "عبر المتجر ذاته", child: Text("عبر المتجر ذاته")),
                    ],
                    onChanged: (val) => setState(() => _deliveryMethod = val!),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _deliveryTimeController,
                    decoration: _inputStyle("مدة التوصيل (مثلاً 25 دقيقة)"),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _categories.contains(_category)
                        ? _category
                        : (_categories.isNotEmpty ? _categories.first : "مطاعم"),
                    decoration: _inputStyle("فئة المتجر"),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) => setState(() => _category = val!),
                  ),
                  const SizedBox(height: 16),

                  TextButton.icon(
                    onPressed: _pickTimeRange,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _openTime != null && _closeTime != null
                          ? "ساعات العمل: ${_openTime!.format(context)} - ${_closeTime!.format(context)}"
                          : "اختر ساعات العمل",
                      style: TextStyle(color: gold, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _discountController,
                    decoration: _inputStyle("نص الخصم (اختياري)"),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _orderController,
                    keyboardType: TextInputType.number,
                    decoration:
                    _inputStyle("رقم الترتيب (اختياري - الأصغر يظهر أولاً)"),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return int.tryParse(v.trim()) == null
                          ? "أدخل رقم فقط"
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: _inputStyle("الوصف"),
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    ),
                    onPressed: _saveToFirebase,
                    icon: const Icon(Icons.save),
                    label: const Text("حفظ المتجر"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
