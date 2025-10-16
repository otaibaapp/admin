import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class PublisherPostsList extends StatefulWidget {
  const PublisherPostsList({super.key});

  @override
  State<PublisherPostsList> createState() => _PublisherPostsListState();
}

class _PublisherPostsListState extends State<PublisherPostsList> {
  final _db = FirebaseDatabase.instance;
  String? _publisherName;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _loadPublisherInfo();
  }

  Future<void> _loadPublisherInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _uid = user.uid;
    final pubSnap = await _db.ref("otaibah_publishers/${user.uid}").get();

    if (pubSnap.exists) {
      final data = Map<String, dynamic>.from(pubSnap.value as Map);
      _publisherName = data["publisherName"] ?? "";
    }
    setState(() {});
  }

  Future<void> _deletePost(String id) async {
    await _db
        .ref("otaibah_navigators_taps/announcements/categories/general/$id")
        .remove();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم حذف منشورك بنجاح")),
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
          elevation: 1,
          centerTitle: true,
          title: const Text(
            "منشوراتي",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        body: _uid == null
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : StreamBuilder(
          stream: _db
              .ref("otaibah_navigators_taps/announcements/categories/general")
              .onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.black),
              );
            }

            if (!snapshot.hasData ||
                snapshot.data == null ||
                (snapshot.data! as DatabaseEvent).snapshot.value == null) {
              return const Center(
                child: Text("لا توجد منشورات بعد",
                    style: TextStyle(color: Colors.black54)),
              );
            }

            final data = Map<dynamic, dynamic>.from(
              (snapshot.data! as DatabaseEvent).snapshot.value as Map,
            );

            final posts = data.entries
                .where((e) {
              final post = Map<String, dynamic>.from(e.value);
              return post["publisherId"] == _uid ||
                  post["source"] == _publisherName;
            })
                .map((e) {
              final post = Map<String, dynamic>.from(e.value);
              post["id"] = e.key;
              return post;
            })
                .toList()
                .reversed
                .toList();

            if (posts.isEmpty) {
              return const Center(
                child: Text("لا توجد منشورات لك حالياً",
                    style: TextStyle(color: Colors.black54)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: posts.length,
              itemBuilder: (context, i) {
                final p = posts[i];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p["contentImgUrl"] != null &&
                          (p["contentImgUrl"] as String).isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            p["contentImgUrl"],
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        p["content"] ?? "",
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            p["dateOfPost"] != null
                                ? "📅 ${p["dateOfPost"]}"
                                : "",
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text(
                                        "ميزة التعديل ستتوفر قريبًا"),
                                  ));
                                },
                                icon: const Icon(Icons.edit,
                                    color: Colors.blueAccent),
                              ),
                              IconButton(
                                onPressed: () => _deletePost(p["id"]),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
