import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:lottie/lottie.dart';

class BannerManager extends StatefulWidget {
  const BannerManager({super.key});

  @override
  State<BannerManager> createState() => _BannerManagerState();
}

class _BannerManagerState extends State<BannerManager> {
  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref('global_banners');

  final DatabaseReference _shopsRef =
  FirebaseDatabase.instance.ref('otaibah_navigators_taps/shopping/categories');

  File? _selectedImage;
  bool _uploading = false;
  String _actionType = "url";
  String _actionValue = "";
  String _section = "shopping";
  String? _selectedShopId;
  List<Map<String, String>> _shops = [];

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

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
        setState(() => _shops = shops);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ خطأ أثناء تحميل المتاجر: $e")),
      );
    }
  }

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "إدارة الإعلانات",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBannerUploadSection(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              const Text(
                "الإعلانات الحالية",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildBannerList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerUploadSection() {
    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("صورة الإعلان",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
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
            const Text("نوع الإجراء",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _actionType,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              items: const [
                DropdownMenuItem(value: "url", child: Text("رابط خارجي")),
                DropdownMenuItem(value: "call", child: Text("اتصال هاتفي")),
                DropdownMenuItem(value: "internal", child: Text("عنصر داخل التطبيق")),
              ],
              onChanged: (v) => setState(() => _actionType = v!),
            ),
            const SizedBox(height: 10),
            if (_actionType == "url")
              TextField(
                decoration: _inputDecoration("أدخل الرابط"),
                onChanged: (v) => _actionValue = v.trim(),
              ),
            if (_actionType == "call")
              TextField(
                decoration: _inputDecoration("رقم الهاتف"),
                keyboardType: TextInputType.phone,
                onChanged: (v) => _actionValue = v.trim(),
              ),
            if (_actionType == "internal") ...[
              const SizedBox(height: 10),
              const Text("🛍️ اختر المتجر:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedShopId,
                hint: const Text("اختر المتجر"),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                items: _shops
                    .map((shop) => DropdownMenuItem(
                    value: shop["id"], child: Text(shop["name"] ?? "")))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedShopId = v;
                    _actionValue = "shop:$v";
                  });
                },
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _uploading ? null : _uploadBanner,
                child: _uploading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  "رفع الإعلان",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );

  Widget _buildBannerList() {
    return FutureBuilder(
      future: _dbRef.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: Lottie.asset('assets/lottie/loading.json', width: 100));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Column(
            children: [
              Lottie.asset('assets/lottie/empty.json', width: 150),
              const Text("لا توجد إعلانات حالياً",
                  style: TextStyle(color: Colors.black54)),
            ],
          );
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

        banners.sort((a, b) => b["id"].compareTo(a["id"]));

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: banners.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final b = banners[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      b["imageUrl"],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b["shopName"] ?? "بدون اسم",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("نوع الإجراء: ${b["actionType"]}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await _dbRef.child(b["id"]).remove();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("🗑️ تم حذف البانر")),
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
