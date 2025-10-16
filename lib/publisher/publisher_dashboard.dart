import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'publisher_edit_profile.dart';
import 'publisher_new_post.dart';
import 'publisher_posts_list.dart';

class PublisherDashboard extends StatefulWidget {
  const PublisherDashboard({super.key});

  @override
  State<PublisherDashboard> createState() => _PublisherDashboardState();
}

class _PublisherDashboardState extends State<PublisherDashboard> {
  Map<String, dynamic>? publisherData;
  bool loading = true;
  final Color gold = const Color(0xFF988561);

  @override
  void initState() {
    super.initState();
    _loadPublisherData();
  }

  Future<void> _loadPublisherData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap =
    await FirebaseDatabase.instance.ref("otaibah_publishers/$uid").get();

    if (snap.exists) {
      setState(() {
        publisherData = Map<String, dynamic>.from(snap.value as Map);
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (color ?? gold).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color ?? gold, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: color ?? gold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 15, color: Colors.black45),
            ],
          ),
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
          elevation: 1,
          centerTitle: true,
          title: const Text(
            "لوحة الناشر",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () async => await FirebaseAuth.instance.signOut(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.black),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (publisherData != null &&
                  publisherData!["publisherImageUrl"] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    publisherData!["publisherImageUrl"],
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person,
                      size: 60, color: Colors.black38),
                ),
              const SizedBox(height: 16),
              Text(
                publisherData?["publisherName"] ?? "ناشر جديد",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 26),

              // ✅ كاردات التحكم
              _buildCard(
                icon: Icons.add_circle_outline,
                title: "نشر إعلان جديد",
                subtitle: "أضف منشورًا جديدًا ليراه المستخدمون",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PublisherNewPost()),
                  );
                },
              ),
              _buildCard(
                icon: Icons.list_alt_rounded,
                title: "منشوراتي الحالية",
                subtitle: "عرض / تعديل / حذف المنشورات السابقة",
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PublisherPostsList()),
                  );
                },
              ),
              _buildCard(
                icon: Icons.person_outline,
                title: "تعديل بيانات الناشر",
                subtitle: "تغيير الاسم أو صورة الحساب الخاصة بك",
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PublisherEditProfile()),
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
