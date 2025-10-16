import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/notification_sender.dart';
import 'package:lottie/lottie.dart';

class AdminAccountsPage extends StatefulWidget {
  const AdminAccountsPage({super.key});

  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage> {
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref("otaibah_users");
  bool _loading = true;
  Map<String, dynamic> _admins = {};

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    final snap = await _usersRef.get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);

      // ✅ نعرض فقط الحسابات اللي لها أدوار إدارية أو تجارية
      final filtered = data.map((k, v) {
        if (v is Map &&
            ((v["role"] == "admin") ||
                (v["role"] == "merchant") ||
                (v["role"] == "delivery"))) {
          return MapEntry(k, v);
        }
        return MapEntry(k, {});
      })..removeWhere((k, v) => v.isEmpty);

      setState(() {
        _admins = filtered;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _approveAdmin(String uid) async {
    await _usersRef.child(uid).update({"pending": false});
    try {
      await NotificationSender.sendAccountApprovalNotification(uid);
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم تفعيل الحساب")),
    );
    _loadAdmins();
  }

  Future<void> _rejectAdmin(String uid) async {
    await _usersRef.child(uid).remove();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ تم رفض الحساب وحذفه")),
    );
    _loadAdmins();
  }

  Future<void> _deleteAdmin(String uid) async {
    await _usersRef.child(uid).remove();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🗑️ تم حذف الحساب بنجاح")),
    );
    _loadAdmins();
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
            "إدارة صلاحيات الحسابات",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: _loading
            ? Center(
            child: Lottie.asset('assets/lottie/loading.json', width: 100))
            : _admins.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/empty.json', width: 180),
              const SizedBox(height: 10),
              const Text(
                "لا توجد حسابات حالياً",
                style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        )
            : ListView(
          padding: const EdgeInsets.all(12),
          children: _admins.entries.map((entry) {
            final uid = entry.key;
            final user = Map<String, dynamic>.from(entry.value);
            final name = user["name"] ?? "بدون اسم";
            final email = user["email"] ?? "بدون بريد";
            final role = user["role"] ?? "غير محدد";
            final pending = user["pending"] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        role == "admin"
                            ? Icons.admin_panel_settings_rounded
                            : role == "merchant"
                            ? Icons.storefront_rounded
                            : Icons.delivery_dining_rounded,
                        color: Colors.black87,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "📧 $email",
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 13),
                  ),
                  Text(
                    "الدور: $role",
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 13),
                  ),
                  const Divider(),
                  if (pending)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _approveAdmin(uid),
                            child: const Text("قبول الحساب"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _rejectAdmin(uid),
                            child: const Text("رفض"),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _deleteAdmin(uid),
                        child: const Text(
                          "حذف الحساب",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
