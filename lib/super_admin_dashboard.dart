import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref("otaibah_users");

  Map<String, dynamic> _users = {};
  bool _loading = true;

  final List<Map<String, String>> _roles = [
    {"key": "admin", "label": "أدمن"},
    {"key": "merchant", "label": "تاجر"},
    {"key": "delivery", "label": "موظف توصيل"},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final snap = await _usersRef.get();
    if (snap.exists) {
      setState(() {
        _users = Map<String, dynamic>.from(snap.value as Map);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _approveUser(String uid) async {
    await _usersRef.child(uid).update({"pending": false});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم تفعيل الحساب")),
    );
    _loadUsers();
  }

  Future<void> _rejectUser(String uid) async {
    await _usersRef.child(uid).remove();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ تم رفض الحساب وحذفه")),
    );
    _loadUsers();
  }

  Future<void> _updateRole(String uid, String newRole) async {
    await _usersRef.child(uid).update({"role": newRole});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم تحديث الصلاحيات بنجاح ✅")),
    );
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text("لا يوجد مستخدمين"))
          : ListView(
        padding: const EdgeInsets.all(8),
        children: _users.entries.map((entry) {
          final uid = entry.key;
          final user = Map<String, dynamic>.from(entry.value);

          final email = user["email"] ?? "بدون بريد";
          final name = user["name"] ?? "مجهول";
          final role = user["role"] ?? "غير محدد";
          final pending = user["pending"] ?? false;

          return Card(
            child: ListTile(
              title: Text(name),
              subtitle: Text("📧 $email\nالدور الحالي: $role"),
              isThreeLine: true,
              trailing: pending == true
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle,
                        color: Colors.green),
                    tooltip: "قبول",
                    onPressed: () => _approveUser(uid),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel,
                        color: Colors.red),
                    tooltip: "رفض",
                    onPressed: () => _rejectUser(uid),
                  ),
                ],
              )
                  : DropdownButton<String>(
                value: _roles.any(
                        (r) => r["key"] == role)
                    ? role
                    : null, // 👈 تحقق إذا الدور موجود
                items: _roles
                    .map((r) => DropdownMenuItem(
                  value: r["key"],
                  child: Text(r["label"]!),
                ))
                    .toList(),
                hint: const Text("اختر دور المستخدم"), // 👈 يظهر إذا القيمة null
                onChanged: (val) {
                  if (val != null && val != role) {
                    _updateRole(uid, val);
                  }
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
