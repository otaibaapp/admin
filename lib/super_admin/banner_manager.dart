import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';

class BannerManager extends StatefulWidget {
  const BannerManager({super.key});

  @override
  State<BannerManager> createState() => _BannerManagerState();
}

class _BannerManagerState extends State<BannerManager> {
  // ✅ استخدم نفس المسار اللي يقرأ منه التطبيق
  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref('global_banners');

  final DatabaseReference _shopsRef =
  FirebaseDatabase.instance.ref('otaibah_navigators_taps/shopping/categories');

  File? _selectedImage;
  bool _uploading = false;
  String _actionType = "url";
  String _actionValue = "";
  String _section = "shopping";

  String? _selectedShopId; // المتجر المختار
  List<Map<String, String>> _shops = [];

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  // ✅ تحميل المتاجر من جميع الفئات (categories)
  Future<void> _loadShops() async {
    try {
      final snap = await _shopsRef.get();

      if (snap.exists) {
        final Map data = Map.from(snap.value as Map);
        final List<Map<String, String>> shops = [];

        data.forEach((categoryKey, categoryVal) {
          if (categoryVal is Map) {
            final Map sub = Map.from(categoryVal);
            sub.forEach((shopId, shopVal) {
              if (shopVal is Map && shopVal["name"] != null) {
                shops.add({
                  "id": shopId.toString(),
                  "name": shopVal["name"].toString(),
                });
              }
            });
          }
        });

        setState(() {
          _shops = shops;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ لم يتم العثور على متاجر في قاعدة البيانات")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ خطأ أثناء تحميل المتاجر: $e")),
      );
    }
  }

  // ✅ اختيار صورة وضغطها
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final dir = await Directory.systemTemp.createTemp();
    final targetPath = "${dir.path}/compressed.jpg";
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      targetPath,
      quality: 80,
    );

    setState(() => _selectedImage = File(compressed?.path ?? picked.path));

  }

  // ✅ رفع الصورة وحفظ البيانات
  Future<void> _uploadBanner() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📸 الرجاء اختيار صورة أولاً")),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref("global_banners/$fileName.jpg");

      await ref.putFile(_selectedImage!);
      final imageUrl = await ref.getDownloadURL();

      // ✅ لو كان الإجراء متجر، نضيف اسم المتجر كحقل إضافي (جميل في لوحة التحكم)
      String? shopName;
      if (_actionType == "internal" && _actionValue.startsWith("shop:")) {
        final id = _actionValue.split(":").last;
        shopName = _shops.firstWhere(
              (s) => s["id"] == id,
          orElse: () => {"name": "متجر غير معروف"},
        )["name"];
      }

      await _dbRef.push().set({
        "imageUrl": imageUrl,
        "section": _section,
        "actionType": _actionType,
        "actionValue": _actionValue,
        if (shopName != null) "shopName": shopName,
        "createdAt": ServerValue.timestamp,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم رفع البانر بنجاح")),
      );

      setState(() {
        _selectedImage = null;
        _actionType = "url";
        _actionValue = "";
        _selectedShopId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ فشل الرفع: $e")),
      );
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF988561),
        title: const Text("إدارة الإعلانات"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "صورة الإعلان:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0x20a7a9ac),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: _selectedImage == null
                      ? const Center(child: Text("اضغط لاختيار صورة"))
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // نوع الإجراء
              const Text("نوع الإجراء:", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _actionType,
                items: const [
                  DropdownMenuItem(value: "url", child: Text("رابط خارجي")),
                  DropdownMenuItem(value: "call", child: Text("اتصال هاتفي")),
                  DropdownMenuItem(value: "internal", child: Text("عنصر داخل التطبيق")),
                ],
                onChanged: (v) => setState(() => _actionType = v!),
              ),
              const SizedBox(height: 8),

              if (_actionType == "url") ...[
                TextField(
                  decoration: const InputDecoration(labelText: "أدخل الرابط"),
                  onChanged: (v) => _actionValue = v.trim(),
                ),
              ] else if (_actionType == "call") ...[
                TextField(
                  decoration: const InputDecoration(labelText: "رقم الهاتف"),
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => _actionValue = v.trim(),
                ),
              ] else if (_actionType == "internal") ...[
                const SizedBox(height: 8),
                const Text("اختر المتجر:", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedShopId,
                  hint: const Text("اختر المتجر"),
                  items: _shops
                      .map((shop) => DropdownMenuItem(
                    value: shop["id"],
                    child: Text(shop["name"] ?? ""),
                  ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedShopId = v;
                      _actionValue = "shop:$v";
                    });
                  },
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF988561),
                  ),
                  onPressed: _uploading ? null : _uploadBanner,
                  icon: _uploading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_uploading ? "جارٍ الرفع..." : "رفع الإعلان"),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(thickness: 1),

// ✅ عرض كل البانرات الموجودة حالياً
              FutureBuilder(
                future: _dbRef.get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text("لا توجد بانرات حالياً"));
                  }

                  final data = Map<String, dynamic>.from(snapshot.data!.value as Map);
                  final banners = data.entries.map((e) {
                    final v = Map<String, dynamic>.from(e.value);
                    return {
                      "id": e.key,
                      "imageUrl": v["imageUrl"],
                      "section": v["section"],
                      "actionType": v["actionType"],
                      "actionValue": v["actionValue"],
                      "shopName": v["shopName"],
                    };
                  }).toList();

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: banners.length,
                    itemBuilder: (context, index) {
                      final b = banners[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Image.network(
                            b["imageUrl"],
                            width: 50,
                            fit: BoxFit.cover,
                          ),
                          title: Text(b["shopName"] ?? "بدون اسم"),
                          subtitle: Text("نوع الإجراء: ${b["actionType"]}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _dbRef.child(b["id"]).remove();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("🗑️ تم حذف البانر")),
                              );
                              setState(() {}); // إعادة تحميل
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),


            ],
          ),
        ),
      ),
    );
  }
}

