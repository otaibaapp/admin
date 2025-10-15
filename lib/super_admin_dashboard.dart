import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:otaibah_app_admin/super_admin/banner_manager.dart'; // ✅ تأكد من المسار الصحيح

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

  // 🧱 واجهة جميلة منظمة بالأقسام
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF988561),
        foregroundColor: Colors.white,
        title: const Text("لوحة السوبر أدمن"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "إدارة النظام",
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // ✅ إدارة صلاحيات الحسابات
          _AdminSectionCard(
            color: const Color(0xFF988561),
            icon: Icons.security,
            title: "إدارة صلاحيات الحسابات",
            description: "تحكم بصلاحيات المستخدمين (تاجر، موظف، أدمن...)",
            onTap: () {
              _showUsersDialog(context);
            },
          ),
          const SizedBox(height: 10),

          // ✅ إدارة الإعلانات (البانرات)
          _AdminSectionCard(
            color: const Color(0xFF0088CC),
            icon: Icons.campaign_outlined,
            title: "إدارة الإعلانات (البانرات)",
            description: "أضف أو عدّل البانرات الظاهرة في التطبيق",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BannerManager()),
              );
            },
          ),
          const SizedBox(height: 10),

          // ✅ إدارة المستخدمين
          _AdminSectionCard(
            color: const Color(0xFF4CAF50),
            icon: Icons.people,
            title: "إدارة المستخدمين",
            description: "استعرض جميع المستخدمين المسجلين وتحقق منهم",
            onTap: () => _showUsersDialog(context),
          ),
        ],
      ),
    );
  }

  // 📋 نافذة منبثقة لعرض المستخدمين بنفس النظام القديم
  void _showUsersDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? const Center(child: Text("لا يوجد مستخدمين"))
                : ListView(
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
                    subtitle:
                    Text("📧 $email\nالدور الحالي: $role"),
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
                          : null,
                      items: _roles
                          .map((r) => DropdownMenuItem(
                        value: r["key"],
                        child: Text(r["label"]!),
                      ))
                          .toList(),
                      hint: const Text("اختر دور المستخدم"),
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
          ),
        );
      },
    );
  }
}

// 👇 كرت مخصص للأقسام (نفس ستايل التاجر اللي بالصورة)
class _AdminSectionCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AdminSectionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios_rounded,
                size: 18, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}
