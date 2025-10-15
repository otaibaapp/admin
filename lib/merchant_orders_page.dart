import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:lottie/lottie.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'services/notification_sender.dart';

Future<void> updateOrderStatus({
  required String orderId,
  required String userId,
  required String status,
  String? rejectionReason,
}) async {
  final db = FirebaseDatabase.instance;
  final ref = db.ref();

  final Map<String, dynamic> updates = {
    'orders/$orderId/status': status,
    'orders/$orderId/updatedAt': ServerValue.timestamp,
    'user_orders/$userId/$orderId/status': status,
    'user_orders/$userId/$orderId/updatedAt': ServerValue.timestamp,
  };

  updates['orders/$orderId/statusHistory/$status'] = ServerValue.timestamp;
  updates['user_orders/$userId/$orderId/statusHistory/$status'] =
      ServerValue.timestamp;

  if (rejectionReason != null && rejectionReason.isNotEmpty) {
    updates['orders/$orderId/rejectionReason'] = rejectionReason;
    updates['user_orders/$userId/$orderId/rejectionReason'] = rejectionReason;
  }

  await ref.update(updates);
}

class MerchantOrdersPage extends StatefulWidget {
  final String shopId;
  final String? highlightedOrderId;

  const MerchantOrdersPage({
    super.key,
    required this.shopId,
    this.highlightedOrderId,
  });

  @override
  State<MerchantOrdersPage> createState() => _MerchantOrdersPageState();
}

class _MerchantOrdersPageState extends State<MerchantOrdersPage>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  final db = FirebaseDatabase.instance.ref("orders");
  String _filter = "all";

  Map<String, IconData> statusIcons = {
    "pending": Icons.hourglass_bottom_rounded,
    "accepted": Icons.check_circle_outline,
    "preparing": Icons.local_dining_outlined,
    "on_delivery": Icons.delivery_dining_outlined,
    "delivered": Icons.verified_outlined,
    "rejected": Icons.cancel_outlined,
  };

  Color statusColor(String s) {
    switch (s) {
      case "pending":
        return Colors.orange;
      case "accepted":
        return Colors.green;
      case "preparing":
        return Colors.blue;
      case "on_delivery":
        return Colors.purple;
      case "delivered":
        return Colors.black;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
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
          title: const Text(
            "الطلبات الواردة",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: (widget.shopId.isEmpty)
            ? const Center(child: Text("حدث خطأ في تحميل الطلب. (shopId فارغ)"))
            : StreamBuilder(
          stream:
          db.orderByChild("shopId").equalTo(widget.shopId).onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: Lottie.asset('assets/lottie/loading.json',
                      width: 100));
            }

            if (!snapshot.hasData ||
                snapshot.data!.snapshot.value == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset('assets/lottie/empty.json', width: 180),
                    const SizedBox(height: 12),
                    const Text("لا توجد طلبات حالياً",
                        style: TextStyle(fontSize: 15)),
                  ],
                ),
              );
            }

            final data = Map<dynamic, dynamic>.from(
                snapshot.data!.snapshot.value as Map);
            List<Map<String, dynamic>> orders = data.values
                .map((v) => Map<String, dynamic>.from(v))
                .toList();

            orders.sort((a, b) {
              final t1 = a['createdAt'] ?? a['timestamp'] ?? 0;
              final t2 = b['createdAt'] ?? b['timestamp'] ?? 0;
              return t2.compareTo(t1);
            });

            if (_filter != "all") {
              orders =
                  orders.where((o) => o["status"] == _filter).toList();
            }

            final total = data.length;
            final pendingCount = data.values
                .where((o) => o["status"] == "pending")
                .length;
            final activeCount = data.values
                .where((o) =>
            o["status"] == "preparing" ||
                o["status"] == "on_delivery")
                .length;
            final doneCount = data.values
                .where((o) =>
            o["status"] == "delivered" ||
                o["status"] == "rejected")
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDashboard(
                    total, pendingCount, activeCount, doneCount),
                _buildFilterButtons(),
                const Padding(
                  padding:
                  EdgeInsets.only(right: 12, left: 12, top: 8, bottom: 6),
                  child: Text(
                    "قائمة الطلبات الحالية",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _buildOrderCard(orders[i]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboard(int total, int pending, int active, int done) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _dashCard("الكل", total, Icons.all_inbox_outlined, Colors.grey.shade200),
          _dashCard("جديدة", pending, Icons.new_releases_outlined, Colors.grey.shade200),
          _dashCard("جارية", active, Icons.fire_truck_outlined, Colors.grey.shade200),
          _dashCard("منتهية", done, Icons.verified_outlined, Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _dashCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.black87, size: 22),
            const SizedBox(height: 4),
            Text("$count",
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    final filters = {
      "all": "الكل",
      "accepted": "مقبول وقيد التحضير",
      "delivered": "استلمه موظّف التوصيل",
      "rejected": "مرفوضة",
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: filters.entries.map((f) {
            final selected = _filter == f.key;
            return GestureDetector(
              onTap: () => setState(() => _filter = f.key),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(selected ? 0.1 : 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  f.value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String statusLabel(String status) {
    switch (status) {
      case "pending":
        return "بإنتظار القبول";
      case "accepted":
        return "قيد التحضير";
      case "delivered":
        return "خرج الطلب مع السائق";
      case "rejected":
        return "مرفوض";
      default:
        return "غير معروف";
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order["status"];
    final createdAt = order["createdAt"] ?? order["timestamp"] ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final formattedDate =
        "${date.year}/${_two(date.month)}/${_two(date.day)} - ${_two(date.hour)}:${_two(date.minute)}:${_two(date.second)}";
    final bool isHighlighted = widget.highlightedOrderId == order["orderId"];
    final Animation<double> opacity =
    Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );

    if (isHighlighted) {
      controller.repeat(reverse: true);
      Future.delayed(const Duration(seconds: 3), () => controller.stop());
    }

    return AnimatedBuilder(
      animation: opacity,
      builder: (context, child) => Opacity(
        opacity: isHighlighted ? opacity.value : 1.0,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Colors.yellow.withOpacity(0.25)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس الطلب
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "طلب #${order["referenceNumber"] ?? "-"}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel(status),
                      style: TextStyle(
                        color: statusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text("تاريخ الإنشاء: $formattedDate",
                  style:
                  const TextStyle(fontSize: 12, color: Colors.black54)),

              const Divider(height: 20, color: Colors.black12),

              // ✅ تنسيق الفاتورة
              if (order["items"] != null)
              // ✅ تنسيق الفاتورة مع عناوين الأعمدة
                if (order["items"] != null) ...[
                  // عنوان الأعمدة
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "المُنتج",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              "الكمية",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "السعر",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // قائمة المنتجات
                  Column(
                    children: Map<String, dynamic>.from(order["items"])
                        .entries
                        .map((e) {
                      final item = Map<String, dynamic>.from(e.value);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(item["name"],
                                        style: const TextStyle(fontSize: 13)))),
                            Expanded(
                                child: Center(
                                    child: Text("x${item["qty"]}",
                                        style: const TextStyle(fontSize: 13)))),
                            Expanded(
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text("${item["price"]} ل.س",
                                        style: const TextStyle(fontSize: 13)))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],


              const Divider(height: 20, color: Colors.black12),
              Text("الإجمالي: ${order["total"]} ل.س",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              _buildActionButtons(order),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== أزرار التحكم بالحالة ====================
  Widget _buildActionButtons(Map<String, dynamic> order) {
    final status = order["status"];

    final nextSteps = <String, dynamic>{
      "pending": [
        {
          "label": "قبول الطلب وبدء التحضير",
          "status": "accepted",
          "color": Colors.green
        },
        {
          "label": "رفض الطلب",
          "status": "rejected",
          "color": Colors.red,
          "ask": true
        },
      ],
      "accepted": [
        {
          "label": "خرج الطلب مع سائق التوصيل",
          "status": "delivered",
          "color": Colors.blue
        },
      ],
    };

    if (!nextSteps.containsKey(status)) return const SizedBox();

    final steps = nextSteps[status];

    if (steps.length == 2) {
      return Row(
        children: [
          Expanded(
            child: _coloredButton(order, steps[0]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _coloredButton(order, steps[1]),
          ),
        ],
      );
    }

    return _coloredButton(order, steps[0]);
  }

  Widget _coloredButton(Map<String, dynamic> order, Map<String, dynamic> step) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: step["color"],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),

      onPressed: () => _handleStatusChange(
        order,
        step["status"],
        step["label"],
        step["color"],
        askReason: step["ask"] == true,
      ),
      child: Text(
        step["label"],
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }


  Widget _whiteButton(Map<String, dynamic> order, Map<String, dynamic> step) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: BorderSide(color: step["color"], width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: () => _handleStatusChange(
        order,
        step["status"],
        step["label"],
        step["color"],
        askReason: step["ask"] == true,
      ),
      child: Text(
        step["label"],
        style: TextStyle(
            color: step["color"],
            fontWeight: FontWeight.bold,
            fontSize: 13),
      ),
    );
  }

  Future<void> _handleStatusChange(
      Map<String, dynamic> order,
      String nextStatus,
      String label,
      Color color, {
        bool askReason = false,
      }) async {
    String? reason;
    if (askReason) {
      reason = await _showRejectionDialog();
      if (reason == null) return;
    }

    await updateOrderStatus(
      orderId: order["orderId"],
      userId: order["userId"],
      status: nextStatus,
      rejectionReason: reason,
    );

    await _sendNotification(
      order,
      _notifTitle(nextStatus),
      _notifBody(nextStatus, order, reason),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("تم تحديث الحالة إلى: ${statusLabel(nextStatus)}"),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendNotification(
      Map<String, dynamic> order, String title, String body) async {
    try {
      final userTokenRef =
      FirebaseDatabase.instance.ref("users/${order["userId"]}/fcmToken");
      final tokenSnap = await userTokenRef.get();

      if (!tokenSnap.exists) return;

      final token = tokenSnap.value.toString();
      await NotificationSender.sendNotification(
        token: token,
        title: title,
        body: body,
        orderId: order["orderId"],
        status: order["status"],
        data: {
          "orderId": order["orderId"],
          "shopId": order["shopId"],
          "click_action": "FLUTTER_NOTIFICATION_CLICK"
        },
      );
    } catch (e) {
      print("❌ خطأ أثناء إرسال الإشعار: $e");
    }
  }

  String _notifTitle(String status) {
    switch (status) {
      case "accepted":
        return "تم قبول طلبك وبدأ التحضير";
      case "delivered":
        return "طلبك خرج مع سائق التوصيل";
      case "rejected":
        return "تم رفض طلبك";
      default:
        return "تم تحديث الطلب";
    }
  }

  String _notifBody(String status, Map<String, dynamic> order, String? reason) {
    final ref = order["referenceNumber"] ?? "-";
    final shop = order["shopName"] ?? "المتجر";
    switch (status) {
      case "accepted":
        return "بدأ المتجر $shop بتحضير طلبك رقم $ref ✅";
      case "delivered":
        return "خرج طلبك رقم $ref مع سائق التوصيل 🚚";
      case "rejected":
        return "تم رفض طلبك رقم $ref. السبب: $reason";
      default:
        return "";
    }
  }

  Future<String?> _showRejectionDialog() async {
    String reason = "";
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("سبب الرفض"),
        content: TextField(
          onChanged: (v) => reason = v,
          decoration: const InputDecoration(hintText: "اكتب السبب هنا."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, reason), child: const Text("رفض")),
        ],
      ),
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
