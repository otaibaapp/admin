import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProductCategoriesEditor extends StatefulWidget {
  final String shopId;
  final String storeCategory; // الفئة الرئيسية (مثلاً: مطاعم)
  const ProductCategoriesEditor(
      {super.key, required this.shopId, required this.storeCategory});

  @override
  State<ProductCategoriesEditor> createState() =>
      _ProductCategoriesEditorState();
}

class _ProductCategoriesEditorState extends State<ProductCategoriesEditor> {
  final _categoryController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  final Color gold = const Color(0xFF988561);
  final Color gray = Colors.grey.shade100;

  DatabaseReference get _catRef => FirebaseDatabase.instance.ref(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                backgroundColor: const Color(0xFF988561),
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
              child: const Text("حفظ"),
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
        backgroundColor: gray,
        appBar: AppBar(
          backgroundColor: gold,
          title: const Text("إدارة تصنيفات المنتجات"),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // إضافة تصنيف جديد
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _categoryController,
                      decoration: InputDecoration(
                        labelText: "اسم التصنيف",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: gold, width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    child: const Text("إضافة"),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: _categories.isEmpty
                    ? const Center(child: Text("لا توجد تصنيفات"))
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
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c["id"],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: SvgPicture.asset(
                                "assets/svg/edit.svg",
                                width: 20,
                                height: 20,
                                colorFilter:
                                const ColorFilter.mode(
                                  Color(0xFF1976D2),
                                  BlendMode.srcIn,
                                ),
                              ),
                              onPressed: () =>
                                  _renameCategory(c["id"]),
                            ),
                            IconButton(
                              icon: SvgPicture.asset(
                                "assets/svg/delete.svg",
                                width: 20,
                                height: 20,
                                colorFilter:
                                const ColorFilter.mode(
                                  Color(0xFFD32F2F),
                                  BlendMode.srcIn,
                                ),
                              ),
                              onPressed: () =>
                                  _deleteCategory(c["id"]),
                            ),
                            SvgPicture.asset(
                              "assets/svg/drag.svg",
                              width: 20,
                              height: 20,
                              colorFilter:
                              const ColorFilter.mode(
                                  Colors.black45,
                                  BlendMode.srcIn),
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
