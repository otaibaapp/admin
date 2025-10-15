import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

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
  final _discountController = TextEditingController();

  File? _imageFile;
  final picker = ImagePicker();

  List<Map<String, dynamic>> _products = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = false;

  final db = FirebaseDatabase.instance;

  DatabaseReference get _productsRef => db.ref(
      "otaibah_navigators_taps/shopping/categories/${widget.category}/${widget.shopId}/products");

  DatabaseReference get _categoriesRef => db.ref(
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

  void _showProductDialog({String? editId, String? oldImageUrl}) {
    showDialog(
      context: context,
      barrierColor: Colors.black54, // خلفية شفافة خفيفة
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95, // ✅ 95% من عرض الشاشة
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      editId == null ? "إضافة منتج" : "تعديل المنتج",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ✅ صورة المنتج
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 150, // ✅ خليها مربعة أكثر
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all( // ✅ البوردر الجديد
                            color: Color(0x01000000), // لون خفيف جداً
                            width: 1, // سماكة البوردر
                          ),
                          boxShadow: [
                            BoxShadow( // ظل خفيف للمسة فخامة
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _imageFile != null
                              ? Image.file(_imageFile!, fit: BoxFit.cover)
                              : (oldImageUrl != null && oldImageUrl.isNotEmpty)
                              ? Image.network(oldImageUrl, fit: BoxFit.cover)
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo_outlined,
                                  size: 38, color: Colors.black45),
                              SizedBox(height: 6),
                              Text("اضغط لإضافة صورة",
                                  style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                      fontFamily: 'PortadaAra')),
                            ],
                          ),
                        ),
                      ),
                    ),



                    const SizedBox(height: 14),

                    _styledField(
                      controller: _nameController,
                      hint: "اسم المنتج",
                      validator: true,
                    ),
                    const SizedBox(height: 10),
                    _styledField(
                      controller: _descriptionController,
                      hint: "الوصف (اختياري)",
                    ),
                    const SizedBox(height: 10),
                    _styledField(
                      controller: _priceController,
                      hint: "السعر (مثلاً 5000)",
                      isNumber: true,
                    ),
                    const SizedBox(height: 10),
                    _styledField(
                      controller: _discountController,
                      hint: "السعر بعد الخصم (اختياري)",
                      isNumber: true,
                    ),
                    const SizedBox(height: 10),

                    // ✅ Dropdown
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        value: _categories.contains(_selectedCategory)
                            ? _selectedCategory
                            : null,
                        items: _categories
                            .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: const TextStyle(
                              fontFamily: 'PortadaAra', // ✅ الخط المخصص
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "التصنيف",
                          hintStyle: TextStyle(
                            fontFamily: 'PortadaAra', // ✅ الخط المخصص لتلميح النص
                            color: Colors.black45,
                            fontSize: 14,
                          ),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black54,
                        ),
                        style: const TextStyle(
                          fontFamily: 'PortadaAra', // ✅ الخط المخصص للقيمة المختارة
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        dropdownColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ✅ الأزرار
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "إلغاء",
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: const Size(100, 44),
                            ),
                            onPressed: () async {
                              await _addOrUpdateProduct(productId: editId);
                              if (mounted) Navigator.pop(context);
                            },
                            child: const Text("حفظ",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }



  // ✅ دالة مساعدة لتغليف حقول النصوص بنفس الستايل
  Widget _filledField({required Widget child}) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      child: child,
    );
  }


  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    bool validator = false,
    bool isNumber = false,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: validator
            ? (v) => v == null || v.isEmpty ? "أدخل $hint" : null
            : null,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }



  Widget _buildTextField(TextEditingController controller, String label,
      {bool validator = false, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: validator ? (v) => v == null || v.isEmpty ? "أدخل $label" : null : null,
      textAlign: TextAlign.right,
      decoration: const InputDecoration(
        labelText: null,
        hintText: null,
        border: InputBorder.none,              // ❗️بدون بوردر
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,       // ❗️نخلي اللفّافة تتحكم بالبادينغ
      ),
      style: const TextStyle(fontSize: 14, color: Colors.black87),
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            "إدارة المنتجات",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _loading
            ? Center(child: Lottie.asset('assets/lottie/loading.json', width: 100))
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: _products.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset('assets/lottie/empty.json', width: 160),
                const SizedBox(height: 10),
                const Text("لا يوجد منتجات حالياً",
                    style: TextStyle(fontSize: 15)),
              ],
            ),
          )
              : ReorderableListView(
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
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
                            borderRadius:
                            BorderRadius.circular(8),
                          ),
                          child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.black45),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(p["name"] ?? "",
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Text("${p["price"]} ل.س",
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600)),
                            if ((p["discountPrice"]
                                ?.toString()
                                .isNotEmpty ??
                                false))
                              Text("خصم: ${p["discountPrice"]} ل.س",
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(p["category"] ?? "",
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: SvgPicture.asset(
                          "assets/svg/edit.svg",
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                              Colors.blue, BlendMode.srcIn),
                        ),
                        onPressed: () => _editProduct(p),
                      ),
                      IconButton(
                        icon: SvgPicture.asset(
                          "assets/svg/delete.svg",
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                              Colors.red, BlendMode.srcIn),
                        ),
                        onPressed: () => _deleteProduct(p["id"]),
                      ),
                      SvgPicture.asset(
                        "assets/svg/drag.svg",
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                            Colors.black45, BlendMode.srcIn),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.black,
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



          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
