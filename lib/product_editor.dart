import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart'; // 👈 ضيف هذا import بالأعلى

class ProductEditor extends StatefulWidget {
  final String shopId;
  final String category;
  const ProductEditor({super.key, required this.shopId, required this.category});

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController(); // 👈 جديد: خصم

  File? _imageFile;
  final picker = ImagePicker();

  List<Map<String, dynamic>> _products = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = false;

  final Color gold = const Color(0xFF988561);
  final Color gray = Colors.grey.shade100;

  DatabaseReference get _productsRef => FirebaseDatabase.instance.ref(
      "otaibah_navigators_taps/shopping/categories/${widget.category}/${widget.shopId}/products");

  DatabaseReference get _categoriesRef => FirebaseDatabase.instance.ref(
      "otaibah_navigators_taps/shopping/categories/${widget.category}/${widget.shopId}/categories");

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final snap = await _categoriesRef.get();
    if (snap.exists) {
      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      setState(() {
        _categories = map.keys.map((e) => e.toString()).toList();
        if (_categories.isNotEmpty) _selectedCategory = _categories.first;
      });
    }
  }

  Future<void> _loadProducts() async {
    final snap = await _productsRef.get();
    if (snap.exists) {
      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      final list = map.entries.map((e) {
        final p = Map<String, dynamic>.from(e.value);
        p["id"] = e.key;
        return p;
      }).toList();

      list.sort((a, b) => (a["order"] ?? 0).compareTo(b["order"] ?? 0));

      setState(() => _products = list);
    } else {
      setState(() => _products = []);
    }
  }

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<String> _uploadImage(String productId) async {
    if (_imageFile == null) return "";
    final ref = FirebaseStorage.instance
        .ref()
        .child("otaibah_products/${widget.shopId}_$productId.jpg");
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _addOrUpdateProduct({String? productId}) async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) return;
    setState(() => _loading = true);

    final isNew = productId == null;
    final ref = isNew ? _productsRef.push() : _productsRef.child(productId!);
    final id = isNew ? ref.key! : productId!;

    String imageUrl = "";
    if (_imageFile != null) {
      imageUrl = await _uploadImage(id);
    } else if (!isNew) {
      final snap = await ref.get();
      if (snap.exists) {
        final old = Map<String, dynamic>.from(snap.value as Map);
        imageUrl = old["imageUrl"] ?? "";
      }
    }

    final order = isNew
        ? _products.length
        : _products.firstWhere((p) => p["id"] == id)["order"] ?? 0;

    // 👇 إعداد البيانات
    final productData = {
      "id": id,
      "name": _nameController.text.trim(),
      "description": _descriptionController.text.trim(),
      "price": _priceController.text.trim(),
      "category": _selectedCategory ?? "",
      "imageUrl": imageUrl,
      "createdAt": DateTime.now().toIso8601String(),
      "ownerId": FirebaseAuth.instance.currentUser!.uid,
      "order": order,
    };

    if (_discountController.text.trim().isNotEmpty) {
      productData["discountPrice"] = _discountController.text.trim();
      productData["saving"] = true;
    } else {
      productData["discountPrice"] = "";
      productData["saving"] = false;
    }

    await ref.set(productData);

    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _discountController.clear();
    _imageFile = null;

    setState(() => _loading = false);
    await _loadProducts();
  }

  Future<void> _deleteProduct(String id) async {
    await _productsRef.child(id).remove();
    await _loadProducts();
  }

  void _editProduct(Map<String, dynamic> p) {
    _nameController.text = p["name"] ?? "";
    _descriptionController.text = p["description"] ?? "";
    _priceController.text = p["price"] ?? "";
    _discountController.text = p["discountPrice"]?.toString() ?? "";
    _selectedCategory = p["category"];
    _imageFile = null;
    _showProductDialog(editId: p["id"], oldImageUrl: p["imageUrl"]);
  }

  // ✅ Dialog تصميم مرتب RTL
  void _showProductDialog({String? editId, String? oldImageUrl}) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(editId == null ? "إضافة منتج" : "تعديل المنتج",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Container(
            padding: const EdgeInsets.all(8),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: _imageFile != null
                          ? Image.file(_imageFile!, height: 100, fit: BoxFit.cover)
                          : (oldImageUrl != null && oldImageUrl.isNotEmpty)
                          ? Image.network(oldImageUrl,
                          height: 100, fit: BoxFit.cover)
                          : Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_a_photo,
                            size: 40, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(_nameController, "اسم المنتج", validator: true),
                    const SizedBox(height: 10),
                    _buildTextField(_descriptionController, "الوصف"),
                    const SizedBox(height: 10),
                    _buildTextField(_priceController, "السعر", isNumber: true),
                    const SizedBox(height: 10),
                    _buildTextField(_discountController, "السعر بعد الخصم",
                        isNumber: true), // 👈 جديد
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _categories.contains(_selectedCategory)
                          ? _selectedCategory
                          : null,
                      items: _categories
                          .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                      decoration: InputDecoration(
                        labelText: "التصنيف",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: gold, width: 1),
                        ),
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: gold),
              onPressed: () async {
                await _addOrUpdateProduct(productId: editId);
                if (mounted) Navigator.pop(context);
              },
              child: const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Helper لمربعات النصوص
  Widget _buildTextField(TextEditingController controller, String label,
      {bool validator = false, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: validator
          ? (v) => v == null || v.isEmpty ? "أدخل $label" : null
          : null,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: gold, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: Colors.transparent,
      ),
    );
  }

  Future<void> _updateOrder() async {
    for (int i = 0; i < _products.length; i++) {
      final id = _products[i]["id"];
      _products[i]["order"] = i;
      await _productsRef.child(id).update({"order": i});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: gray,
        appBar: AppBar(
          title: const Text("إدارة المنتجات"),
          backgroundColor: gold,
        ),
        body: _products.isEmpty
            ? const Center(child: Text("لا يوجد منتجات"))
            : ReorderableListView(
          padding: const EdgeInsets.all(16),
          onReorder: (oldIndex, newIndex) async {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _products.removeAt(oldIndex);
            _products.insert(newIndex, item);
            setState(() {});
            await _updateOrder();
          },
          children: [
            for (final p in _products)
              Container(
                key: ValueKey(p["id"]),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: p["imageUrl"] != null &&
                          p["imageUrl"].toString().isNotEmpty
                          ? Image.network(
                        p["imageUrl"],
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.black45),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p["name"] ?? "",
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("${p["price"]} ل.س",
                              style: TextStyle(
                                  fontSize: 14,
                                  color: gold,
                                  fontWeight: FontWeight.w600)),
                          if ((p["discountPrice"]?.toString().isNotEmpty ?? false))
                            Text("خصم: ${p["discountPrice"]} ل.س",
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(p["category"] ?? "",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: SvgPicture.asset(
                        "assets/svg/edit.svg",
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF3BB54A), // أزرق
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: () => _editProduct(p),
                    ),
                    IconButton(
                      icon: SvgPicture.asset(
                        "assets/svg/delete.svg",
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFD32F2F), // أحمر
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: () => _deleteProduct(p["id"]),
                    ),
                    SvgPicture.asset(
                      "assets/svg/drag.svg",
                      width: 20,
                      height: 20,
                      colorFilter:
                      const ColorFilter.mode(Colors.black45, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: gold,
          onPressed: () {
            _nameController.clear();
            _descriptionController.clear();
            _priceController.clear();
            _discountController.clear();
            _selectedCategory =
            _categories.isNotEmpty ? _categories.first : null;
            _imageFile = null;
            _showProductDialog();
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
