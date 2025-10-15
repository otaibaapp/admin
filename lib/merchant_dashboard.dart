import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'product_editor.dart';
import 'product_categories_editor.dart';
import 'admin_store_editor.dart';
import 'merchant_orders_page.dart';
import 'services/fcm_service.dart';
import 'statistics_page.dart';

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

    // ✅ حفظ توكن التاجر عند فتح التطبيق
    FCMService.saveMerchantFcmToken(widget.shopId);
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
            "لوحة التاجر",
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
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("تأكيد الخروج"),
                      content: const Text("هل تريد تسجيل الخروج من الحساب؟"),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("إلغاء")),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                          child: const Text("خروج"),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FirebaseAuth.instance.signOut();
                  }
                },
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
            : shopData == null
            ? const Center(
          child: Text(
            "❌ لم يتم العثور على بيانات متجرك",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ✅ صورة المتجر (بانر)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  shopData!["imageUrl"] ?? "",
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 170,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.storefront,
                        size: 50, color: Colors.black38),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                shopData!["name"] ?? "",
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                shopData!["description"] ?? "",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 26),

              // ✅ الأقسام
              _buildDashboardCard(
                icon: Icons.edit,
                title: "تعديل بيانات المتجر",
                subtitle: "قم بتحديث تفاصيل متجرك وصورته",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminStoreEditor(),
                    ),
                  );
                },
              ),
              _buildDashboardCard(
                icon: Icons.inventory_2,
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
                icon: Icons.category_outlined,
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
              _buildDashboardCard(
                icon: Icons.receipt_long_rounded,
                title: "الطلبات الواردة",
                subtitle: "شاهد الطلبات الجديدة وقم بقبولها أو رفضها",
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MerchantOrdersPage(shopId: widget.shopId),
                    ),
                  );
                },
              ),
              _buildDashboardCard(
                icon: Icons.bar_chart_rounded,
                title: "الإحصائيات والأرشيف",
                subtitle: "تحليل أداء متجرك شهرياً وأرشفة الطلبات القديمة",
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatisticsPage(shopId: widget.shopId),

                    ),
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
