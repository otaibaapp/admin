import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

class ProductCategoriesEditor extends StatefulWidget {
  final String shopId;
  final String storeCategory; // الفئة الرئيسية (مثلاً: مطاعم)

  const ProductCategoriesEditor({
    super.key,
    required this.shopId,
    required this.storeCategory,
  });

  @override
  State<ProductCategoriesEditor> createState() =>
      _ProductCategoriesEditorState();
}

class _ProductCategoriesEditorState extends State<ProductCategoriesEditor> {
  final _categoryController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  final db = FirebaseDatabase.instance;

  DatabaseReference get _catRef => db.ref(
      "otaibah_navigators_taps/shopping/categories/${widget.storeCategory}/${widget.shopId}/categories");

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final snap = await _catRef.get();
    if (snap.exists) {
      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      final list = map.entries.map((e) {
        final value = (e.value is Map)
            ? Map<String, dynamic>.from(e.value)
            : <String, dynamic>{};
        return {
          "id": e.key.toString(),
          "order": value["order"] ?? 0,
        };
      }).toList()
        ..sort((a, b) => (a["order"] ?? 0).compareTo(b["order"] ?? 0));

      setState(() {
        _categories = list;
        _loading = false;
      });
    } else {
      setState(() {
        _categories = [];
        _loading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isEmpty) return;

    final order = _categories.isEmpty
        ? 0
        : (_categories.map((c) => c["order"] as int).reduce((a, b) => a > b ? a : b)) + 1;

    await _catRef.child(name).set({"order": order});
    _categoryController.clear();
    await _loadCategories();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ تمت إضافة التصنيف: $name")),
      );
    }
  }

  Future<void> _deleteCategory(String id) async {
    await _catRef.child(id).remove();
    await _loadCategories();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🗑️ تم حذف التصنيف: $id")),
      );
    }
  }

  Future<void> _updateOrder() async {
    for (int i = 0; i < _categories.length; i++) {
      final id = _categories[i]["id"];
      _categories[i]["order"] = i;
      await _catRef.child(id).update({"order": i});
    }
  }

  Future<void> _renameCategory(String oldId) async {
    final controller = TextEditingController(text: oldId);

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("تعديل اسم التصنيف"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: "الاسم الجديد",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () async {
                final newId = controller.text.trim();
                if (newId.isEmpty || newId == oldId) {
                  Navigator.pop(ctx);
                  return;
                }

                final snap = await _catRef.child(oldId).get();
                if (snap.exists) {
                  final data = Map<String, dynamic>.from(snap.value as Map);
                  await _catRef.child(newId).set(data);
                  await _catRef.child(oldId).remove();
                  await _loadCategories();
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("✏️ تم تعديل التصنيف: $oldId → $newId")),
                  );
                }

                Navigator.pop(ctx);
              },
              child: const Text("حفظ", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
            "إدارة تصنيفات المنتجات",
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding:
                EdgeInsets.only(right: 4, left: 4, bottom: 8, top: 4),
                child: Text(
                  "إضافة تصنيف جديد",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _categoryController,
                      decoration: InputDecoration(
                        hintText: "اسم التصنيف...",
                        hintStyle:
                        const TextStyle(color: Colors.black45, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    child: const Text(
                      "إضافة",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _categories.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset('assets/lottie/empty.json', width: 160),
                      const SizedBox(height: 10),
                      const Text("لا توجد تصنيفات حالياً",
                          style: TextStyle(fontSize: 15)),
                    ],
                  ),
                )
                    : ReorderableListView(
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _categories.removeAt(oldIndex);
                    _categories.insert(newIndex, item);
                    setState(() {});
                    await _updateOrder();
                  },
                  children: [
                    for (final c in _categories)
                      Container(
                        key: ValueKey(c["id"]),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c["id"],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
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
                              onPressed: () =>
                                  _renameCategory(c["id"]),
                            ),
                            IconButton(
                              icon: SvgPicture.asset(
                                "assets/svg/delete.svg",
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                    Colors.red, BlendMode.srcIn),
                              ),
                              onPressed: () =>
                                  _deleteCategory(c["id"]),
                            ),
                            SvgPicture.asset(
                              "assets/svg/drag.svg",
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                Colors.black45,
                                BlendMode.srcIn,
                              ),
                            ),
                          ],
                        ),
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
}
