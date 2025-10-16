import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/notification_sender.dart';

class NotificationRequestsPage extends StatefulWidget {
  const NotificationRequestsPage({super.key});

  @override
  State<NotificationRequestsPage> createState() => _NotificationRequestsPageState();
}

class _NotificationRequestsPageState extends State<NotificationRequestsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final snap = await FirebaseDatabase.instance
        .ref("otaibah_navigators_taps/announcements/categories/general")
        .get();

    if (!snap.exists) {
      setState(() => _loading = false);
      return;
    }

    final data = Map<String, dynamic>.from(snap.value as Map);
    _requests = data.values
        .map((v) => Map<String, dynamic>.from(v))
        .where((p) => p["requiresNotification"] == true)
        .toList();

    setState(() => _loading = false);
  }

  Future<void> _approveNotification(Map<String, dynamic> post) async {
    final postId = post["id"];
    await FirebaseDatabase.instance
        .ref("otaibah_navigators_taps/announcements/categories/general/$postId/requiresNotification")
        .set(false);

    await _sendNotificationToAll(post);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم إرسال الإشعار لجميع المستخدمين")),
    );
    _loadRequests();
  }

  Future<void> _sendNotificationToAll(Map<String, dynamic> post) async {
    final usersSnap = await FirebaseDatabase.instance.ref("otaibah_users").get();
    if (!usersSnap.exists) return;

    final users = Map<String, dynamic>.from(usersSnap.value as Map);

    for (var entry in users.entries) {
      final user = Map<String, dynamic>.from(entry.value);
      final token = user["fcmToken"];
      if (token != null && token.toString().isNotEmpty) {
        await NotificationSender.sendNotification(
          token: token,
          title: "📢 منشور جديد من ${post["source"]}",
          body: post["content"] ?? "",
          orderId: post["id"] ?? "general",
          status: "announcement",
        );
      }
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
            "طلبات الإشعارات العامة",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        body: _loading
            ? Center(child: Lottie.asset('assets/lottie/loading.json', width: 100))
            : _requests.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/empty.json', width: 180),
              const SizedBox(height: 10),
              const Text(
                "لا توجد طلبات إشعار حالياً",
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadRequests,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _requests.length,
            itemBuilder: (_, i) {
              final post = _requests[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: Colors.orange,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post["content"] ?? "",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "من: ${post["source"] ?? 'غير معروف'}",
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _approveNotification(post),
                        child: const Text(
                          "إرسال الإشعار الآن",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
