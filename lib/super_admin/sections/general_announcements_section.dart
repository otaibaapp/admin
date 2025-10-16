import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

class GeneralAnnouncementsSection extends StatefulWidget {
  const GeneralAnnouncementsSection({super.key});

  @override
  State<GeneralAnnouncementsSection> createState() =>
      _GeneralAnnouncementsSectionState();
}

class _GeneralAnnouncementsSectionState
    extends State<GeneralAnnouncementsSection> {
  final DatabaseReference _db = FirebaseDatabase.instance
      .ref("otaibah_navigators_taps/announcements/categories/general");

  bool _loading = true;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    final snap = await _db.get();

    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      final list = <Map<String, dynamic>>[];
      data.forEach((key, value) {
        if (value is Map) {
          final item = Map<String, dynamic>.from(value);
          item["id"] = key;
          list.add(item);
        }
      });
      setState(() {
        _posts = list.reversed.toList();
        _loading = false;
      });
    } else {
      setState(() {
        _posts = [];
        _loading = false;
      });
    }
  }

  Future<void> _deletePost(String id) async {
    await _db.child(id).remove();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🗑️ تم حذف المنشور بنجاح"),
        backgroundColor: Colors.redAccent,
      ),
    );
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          centerTitle: true,
          title: const Text(
            "إدارة الإعلانات العامة",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: _loading
            ? Center(child: Lottie.asset('assets/lottie/loading.json', width: 100))
            : _posts.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/empty.json', width: 180),
              const SizedBox(height: 10),
              const Text(
                "لا توجد منشورات حالياً",
                style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadPosts,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              final item = _posts[index];
              final String id = item["id"] ?? "";
              final String content = item["content"] ?? "";
              final String source = item["source"] ?? "غير معروف";
              final String imageUrl = item["contentImgUrl"] ?? "";
              final String sourceImage =
                  item["sourceImageUrl"] ?? "";

              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 6),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== الهيدر (صورة الناشر + الاسم) =====
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              sourceImage,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(
                                    width: 46,
                                    height: 46,
                                    color: Colors.black,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white54,
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              source,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ===== نص المنشور =====
                      Text(
                        content,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ===== صورة المحتوى =====
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 150,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image,
                                color: Colors.white70,
                                size: 80,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // ===== زر حذف المنشور =====
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _deletePost(id),
                          icon: const Icon(Icons.delete_forever,
                              color: Colors.white),
                          label: const Text(
                            "حذف المنشور نهائيًا",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
