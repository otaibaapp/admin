import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:otaibah_app_admin/super_admin/banner_manager.dart';
import 'package:otaibah_app_admin/super_admin/notification_requests_page.dart';
import 'package:otaibah_app_admin/super_admin/sections/general_announcements_section.dart';
import 'package:otaibah_app_admin/super_admin/sections/stores_section.dart';
import 'package:otaibah_app_admin/super_admin/users/admin_accounts_page.dart';
import 'package:otaibah_app_admin/super_admin/users/user_accounts_page.dart';
import '../services/notification_sender.dart';

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
    try {
      await NotificationSender.sendAccountApprovalNotification(uid);
      print("✅ تم إرسال إشعار الموافقة للمستخدم $uid");
    } catch (e) {
      print("⚠️ فشل إرسال إشعار الموافقة: $e");
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم تفعيل الحساب وإرسال إشعار للمستخدم")),
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

  // ✅ الكرت الترحيبي الجميل
  Widget _welcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0x10000000),
        borderRadius: BorderRadius.circular(16),

      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "أهلاً وسهلاً بالمدير العام 👋",
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "يسعدنا تواجدك اليوم! يمكنك إدارة المتاجر والمستخدمين والإعلانات والسوق المفتوح بكل سهولة واحترافية.",
            style: TextStyle(color: Colors.black, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ✅ كرت تصميم واحد لكل قسم
  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ واجهة السوبر أدمن بعد التعديل
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text(
            "لوحة السوبر أدمن",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            tooltip: "تسجيل الخروج",
            onPressed: () async {
              await FirebaseDatabase.instance.goOffline();
              // أو استخدم FirebaseAuth.instance.signOut() إذا عندك تسجيل دخول بالإيميل
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("تم تسجيل الخروج"),
                  backgroundColor: Colors.redAccent,
                ),
              );
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),

        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _welcomeCard(),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3, // ✅ ثلاث كروت في الصف الواحد
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.95,
                  children: [
                    _buildDashboardCard(
                      title: "إدارة صلاحيات الحسابات",
                      icon: Icons.security_rounded,
                      color: const Color(0xFF988561),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminAccountsPage()),
                        );
                      },
                    ),
                    _buildDashboardCard(
                      title: "إدارة المستخدمين",
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF4CAF50),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserAccountsPage()),
                        );
                      },
                    ),
                    _buildDashboardCard(
                      title: "إدارة الإعلانات (البانرات)",
                      icon: Icons.image_rounded,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BannerManager()),
                        );
                      },
                    ),
                    _buildDashboardCard(
                      title: "طلبات الإشعارات العامة",
                      icon: Icons.notifications_active_rounded,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                              const NotificationRequestsPage()),
                        );
                      },
                    ),
                    _buildDashboardCard(
                      title: "المتاجر",
                      icon: Icons.storefront_rounded,
                      color: const Color(0xFF0088CC),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StoresSection()),
                        );
                      },
                    ),
                    _buildDashboardCard(
                      title: "المنتجات",
                      icon: Icons.inventory_2_rounded,
                      color: Colors.deepPurple,
                      onTap: () {
                        // ✅ إدارة المنتجات لاحقاً
                      },
                    ),
                    _buildDashboardCard(
                      title: "السوق المفتوح",
                      icon: Icons.shopping_bag_rounded,
                      color: const Color(0xFF795548),
                      onTap: () {
                        // ✅ إدارة السوق المفتوح لاحقاً
                      },
                    ),
                    _buildDashboardCard(
                      title: "الإعلانات العامة",
                      icon: Icons.campaign_rounded,
                      color: Colors.blueAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GeneralAnnouncementsSection()),
                        );
                      },
                    ),

                    _buildDashboardCard(
                      title: "العناصر المخفية",
                      icon: Icons.visibility_off_rounded,
                      color: Colors.grey.shade800,
                      onTap: () {
                        // ✅ قائمة العناصر المخفية لاحقاً
                      },
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

  // ✅ نافذة المستخدمين (كما كانت)
  void _showUsersDialog(BuildContext context) async {
    setState(() => _loading = true);

    // ✅ نحمل المستخدمين فقط عند فتح النافذة
    final snap = await _usersRef.get();
    if (snap.exists) {
      _users = Map<String, dynamic>.from(snap.value as Map);
    } else {
      _users = {};
    }

    setState(() => _loading = false);

    if (!mounted) return;

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
                final user =
                Map<String, dynamic>.from(entry.value);
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
                      hint:
                      const Text("اختر دور المستخدم"),
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
