import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final _orderController = TextEditingController(); // رقم الترتيب

  String _deliveryMethod = "عبر التطبيق";
  String _category = "مطاعم";
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  File? _imageFile;
  bool _verified = false;

  // 🔹 مسار الفئات
  final _databaseRef =
  FirebaseDatabase.instance.ref("otaibah_navigators_taps/shopping/categories");
  final picker = ImagePicker();

  // 🔹 قائمة الفئات (تبدأ بقيم افتراضية — تتبدل بعد التحميل من Firebase)
  List<String> _categories = ["مطاعم", "حلويات", "لحوم", "خضار", "كهربائيات"];

  @override
  void initState() {
    super.initState();
    _loadCategories(); // حمّل الفئات ديناميكياً
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
      names.sort(); // ترتيب أبجدي
      setState(() {
        if (names.isNotEmpty) {
          _categories = names;
        }
        if (!_categories.contains(_category)) {
          _category = _categories.first;
        }
      });
    } catch (_) {
      // تجاهل بهدوء (ممكن تضيف Snackbar لو حاب)
    }
  }

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String> _uploadImage(String storeId) async {
    if (_imageFile == null) return "";
    final ref = FirebaseStorage.instance
        .ref()
        .child("otaibah_stores_images")
        .child("$storeId.jpg");
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  // ✅ حفظ المتجر في Firebase
  Future<void> _saveToFirebase() async {
    if (!_formKey.currentState!.validate()) return;

    final newStoreRef = _databaseRef.child(_category).push();
    final storeId = newStoreRef.key!;
    final imageUrl = await _uploadImage(storeId);

    final int order =
        int.tryParse(_orderController.text.trim()) ?? 9999; // ترتيب افتراضي آخر القائمة

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
      "verified": _verified,
      "order": order, // 🔹 الترتيب
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم حفظ المتجر بنجاح")),
      );
      Navigator.pop(context);
    }
  }

  // ✅ إضافة فئة جديدة (category)
  Future<void> _addNewCategory() async {
    String newCategory = "";
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إضافة فئة جديدة"),
        content: TextField(
          onChanged: (v) => newCategory = v.trim(),
          decoration: const InputDecoration(hintText: "مثلاً: ألبسة"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newCategory.isEmpty) return;

              // لو الفئة موجودة مسبقاً ما نعيد كتابتها
              final catRef = _databaseRef.child(newCategory);
              final exists = await catRef.get();
              if (!exists.exists) {
                await catRef.set({"_init": true});
              }

              if (mounted) {
                Navigator.pop(ctx);
                await _loadCategories(); // 👈 حدّث قائمة الفئات فوراً
                setState(() => _category = newCategory);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("✅ تمت إضافة الفئة: $newCategory")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF988561)),
            child: const Text("إضافة"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isOpen) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إضافة / تعديل متجر"),
        backgroundColor: const Color(0xFF988561),
        actions: [
          IconButton(
            tooltip: "إضافة فئة جديدة",
            onPressed: _addNewCategory,
            icon: const Icon(Icons.add_box_outlined),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: _imageFile != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.grey, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // اسم المتجر
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "اسم المتجر"),
                  validator: (v) =>
                  v == null || v.isEmpty ? "يرجى إدخال اسم المتجر" : null,
                ),
                const SizedBox(height: 10),

                // طريقة التوصيل
                DropdownButtonFormField<String>(
                  value: _deliveryMethod,
                  decoration: const InputDecoration(labelText: "طريقة التوصيل"),
                  items: const [
                    DropdownMenuItem(value: "عبر التطبيق", child: Text("عبر التطبيق")),
                    DropdownMenuItem(value: "عبر المتجر ذاته", child: Text("عبر المتجر ذاته")),
                  ],
                  onChanged: (val) => setState(() => _deliveryMethod = val!),
                ),
                const SizedBox(height: 10),

                // وقت التوصيل
                TextFormField(
                  controller: _deliveryTimeController,
                  decoration: const InputDecoration(
                      labelText: "مدة التوصيل (مثلاً 25 دقيقة)"),
                ),
                const SizedBox(height: 10),

                // الفئة (ديناميكي)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _categories.contains(_category) ? _category : (_categories.isNotEmpty ? _categories.first : "مطاعم"),
                        decoration: const InputDecoration(labelText: "فئة المتجر"),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) => setState(() => _category = val!),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: "إضافة فئة جديدة",
                      onPressed: _addNewCategory,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // وقت الفتح / الإغلاق
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _pickTime(true),
                        icon: const Icon(Icons.access_time),
                        label: Text(_openTime != null
                            ? "يفتح ${_openTime!.format(context)}"
                            : "اختر وقت الفتح"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _pickTime(false),
                        icon: const Icon(Icons.lock_clock),
                        label: Text(_closeTime != null
                            ? "يغلق ${_closeTime!.format(context)}"
                            : "اختر وقت الإغلاق"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // الخصم
                TextFormField(
                  controller: _discountController,
                  decoration: const InputDecoration(labelText: "نص الخصم (اختياري)"),
                ),
                const SizedBox(height: 10),

                // الترتيب
                TextFormField(
                  controller: _orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "رقم الترتيب (اختياري - الأصغر يظهر أولاً)",
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return int.tryParse(v.trim()) == null ? "أدخل رقم فقط" : null;
                  },
                ),
                const SizedBox(height: 10),

                // موثّق
                SwitchListTile(
                  title: const Text("موثّق"),
                  value: _verified,
                  onChanged: (v) => setState(() => _verified = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),

                // الوصف
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "الوصف"),
                ),
                const SizedBox(height: 20),

                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF988561),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                    ),
                    onPressed: _saveToFirebase,
                    icon: const Icon(Icons.save),
                    label: const Text("حفظ المتجر"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
