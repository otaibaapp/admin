import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otaibah_app_admin/product_editor.dart';
import 'package:otaibah_app_admin/product_categories_editor.dart';
import 'admin_store_editor.dart';

class MerchantDashboard extends StatefulWidget {
  final String shopId;
  const MerchantDashboard({super.key, required this.shopId});

  @override
  State<MerchantDashboard> createState() => _MerchantDashboardState();
}

class _MerchantDashboardState extends State<MerchantDashboard> {
  Map<String, dynamic>? shopData;
  bool loading = true;

  final Color gold = const Color(0xFF988561);
  final Color gray = Colors.grey.shade100;

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    final snap = await FirebaseDatabase.instance
        .ref("otaibah_navigators_taps/shopping/categories")
        .get();

    if (!snap.exists) {
      setState(() => loading = false);
      return;
    }

    final cats = Map<dynamic, dynamic>.from(snap.value as Map);
    for (final cat in cats.keys) {
      final stores = Map<dynamic, dynamic>.from(cats[cat]);
      if (stores.containsKey(widget.shopId)) {
        final store = Map<String, dynamic>.from(stores[widget.shopId]);
        store["id"] = widget.shopId;
        store["category"] = cat.toString();
        setState(() {
          shopData = store;
          loading = false;
        });
        return;
      }
    }

    setState(() => loading = false);
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Directionality( // 👈 إجبار RTL داخل الكارت
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (color ?? gold).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color ?? gold, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // النص يضل مضبوط
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color ?? gold,
                        )),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
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
    return Directionality( // 👈 إجبار الصفحة كلها RTL
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: gray,
        appBar: AppBar(
          backgroundColor: gold,
          title: const Text("لوحة التاجر"),
          actions: [
            IconButton(
              tooltip: "تسجيل الخروج",
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : shopData == null
            ? const Center(child: Text("❌ لم يتم العثور على بيانات متجرك"))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // صورة المتجر
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  shopData!["imageUrl"] ?? "",
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      height: 160, color: Colors.grey[300]),
                ),
              ),
              const SizedBox(height: 16),

              // اسم المتجر
              Text(
                shopData!["name"] ?? "",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                shopData!["description"] ?? "",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),

              // Cards للأقسام
              _buildDashboardCard(
                icon: Icons.edit,
                title: "تعديل بيانات المتجر",
                subtitle: "قم بتحديث تفاصيل متجرك وصورته",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminStoreEditor()),
                  );
                },
              ),
              _buildDashboardCard(
                icon: Icons.inventory,
                title: "إدارة المنتجات",
                subtitle: "أضف، عدل أو احذف منتجاتك بسهولة",
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductEditor(
                        shopId: widget.shopId,
                        category: shopData!["category"],
                      ),
                    ),
                  );
                },
              ),
              _buildDashboardCard(
                icon: Icons.category,
                title: "إدارة الفئات",
                subtitle: "تحكم في تصنيفات منتجات متجرك",
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductCategoriesEditor(
                        shopId: widget.shopId,
                        storeCategory: shopData!["category"],
                      ),
                    ),
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
