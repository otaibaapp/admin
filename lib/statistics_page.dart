import 'dart:ui' as flutter;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class StatisticsPage extends StatefulWidget {
  final String shopId;
  const StatisticsPage({super.key, required this.shopId});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with TickerProviderStateMixin {
  bool _loading = true;
  String _selectedMonth = DateFormat('yyyy_MM').format(DateTime.now());
  final db = FirebaseDatabase.instance.ref("orders");
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, String>> _availableMonths = [];
  late AnimationController _controller;
  double? _prevSuccessRate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initLocale();
  }

  Future<void> _initLocale() async {
    await initializeDateFormatting('ar', null);
    _listenOrders();
  }

  void _listenOrders() {
    db.orderByChild("shopId").equalTo(widget.shopId).onValue.listen((event) {
      if (!mounted) return;
      final snap = event.snapshot;
      if (!snap.exists) {
        setState(() {
          _orders = [];
          _availableMonths = [];
          _loading = false;
        });
        return;
      }

      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final all = data.values.map((v) => Map<String, dynamic>.from(v)).toList();

      final Set<String> months = {};
      for (final o in all) {
        final ts = o["createdAt"] ?? o["timestamp"];
        if (ts == null) continue;
        final date = DateTime.fromMillisecondsSinceEpoch(ts);
        months.add(DateFormat('yyyy_MM').format(date));
      }

      final sortedMonths = months.toList()..sort((b, a) => a.compareTo(b));
      final available = sortedMonths
          .map((m) {
        final parts = m.split('_');
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        return {
          "id": m,
          "label": DateFormat('MMMM yyyy', 'ar').format(date),
        };
      })
          .toList();

      final filtered = all.where((o) {
        final date = DateTime.fromMillisecondsSinceEpoch(
            o["createdAt"] ?? o["timestamp"] ?? 0);
        return DateFormat('yyyy_MM').format(date) == _selectedMonth;
      }).toList();

      if (available.length > 1) {
        final prevId = available[1]["id"];
        final prevOrders = all.where((o) {
          final date = DateTime.fromMillisecondsSinceEpoch(
              o["createdAt"] ?? o["timestamp"] ?? 0);
          return DateFormat('yyyy_MM').format(date) == prevId;
        }).toList();

        if (prevOrders.isNotEmpty) {
          final totalPrev = prevOrders.length;
          final successfulPrev =
              prevOrders.where((o) => o["status"] == "delivered").length;
          _prevSuccessRate =
          totalPrev == 0 ? 0 : (successfulPrev / totalPrev) * 100;
        }
      }

      setState(() {
        _orders = filtered;
        _availableMonths = available;
        _loading = false;
      });

      if (mounted) _controller.forward(from: 0);
    });
  }

  Map<String, dynamic> _calculateStats() {
    int total = _orders.length;
    int successful =
        _orders.where((o) => o["status"] == "delivered").length;
    int rejected =
        _orders.where((o) => o["status"] == "rejected").length;

    double totalRevenue = 0;
    for (final o in _orders) {
      if (o["status"] == "delivered") {
        totalRevenue += double.tryParse(o["total"].toString()) ?? 0;
      }
    }

    double successRate = total == 0 ? 0 : (successful / total) * 100;
    double rejectRate = total == 0 ? 0 : (rejected / total) * 100;

    return {
      "total": total,
      "successful": successful,
      "rejected": rejected,
      "revenue": totalRevenue,
      "successRate": successRate,
      "rejectRate": rejectRate,
    };
  }

  String _generatePerformanceComment(double currentRate) {
    if (_prevSuccessRate == null) {
      return "📊 لا توجد بيانات من الشهر الماضي للمقارنة بعد.";
    }

    final diff = currentRate - _prevSuccessRate!;
    if (diff > 5) {
      return "🎯 أداء ممتاز هذا الشهر 👏، نسبة النجاح ارتفعت ${diff.toStringAsFixed(1)}٪ مقارنة بالشهر الماضي!";
    } else if (diff < -5) {
      return "⚠️ الأداء هذا الشهر أقل من الشهر الماضي بنسبة ${diff.abs().toStringAsFixed(1)}٪ — حاول تحسين الاستجابة للعملاء 💪";
    } else {
      return "⚪ الأداء مستقر هذا الشهر بنفس مستوى الشهر الماضي 👍";
    }
  }

  double _calculateRevenueProgress(double currentRevenue) {
    double prevRevenue = 0;
    for (final o in _orders) {
      final ts = o["createdAt"] ?? o["timestamp"];
      if (ts == null) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
      final monthKey = DateFormat('yyyy_MM').format(date);

      if (_availableMonths.length > 1 &&
          monthKey == _availableMonths[1]["id"]) {
        if (o["status"] == "delivered") {
          prevRevenue += double.tryParse(o["total"].toString()) ?? 0;
        }
      }
    }

    if (prevRevenue == 0) return 100;
    final progress = (currentRevenue / prevRevenue) * 100;
    return progress.clamp(0, 200);
  }


  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return Directionality(
      textDirection: flutter.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            "إحصائيات المتجر",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            child: FadeTransition(
              opacity: _controller,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthSelector(),
                  const SizedBox(height: 20),
                  _buildSummaryCards(stats),
                  const SizedBox(height: 25),
                  const Text(
                    "نسب الأداء الشهرية:",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildProgressLine(
                      "الطلبات الناجحة",
                      stats["successRate"],
                      Colors.green,
                      Icons.check_circle_outline),
                  const SizedBox(height: 14),
                  _buildProgressLine(
                      "الطلبات المرفوضة",
                      stats["rejectRate"],
                      Colors.red,
                      Icons.cancel_outlined),
                  const SizedBox(height: 14),
                  _buildProgressLine(
                    "مقارنة المبيعات مع الشهر السابق",
                    _prevSuccessRate == null
                        ? 100
                        : _calculateRevenueProgress(stats["revenue"]),
                    const Color(0xFFF5C147),
                    Icons.attach_money_rounded,
                  ),

                  const SizedBox(height: 20),
                  const Divider(thickness: 0.5),
                  const SizedBox(height: 10),
                  Text(
                    _generatePerformanceComment(stats["successRate"]),
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500),
                  ),



                  const SizedBox(height: 20),
                  const Text(
                    "💡 ملاحظات عامة:",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                  const Text(
                    "▪️ الألوان تعبّر عن الحالة: الأخضر نجاح، الأحمر رفض، الذهبي مبيعات.\n"
                        "▪️ القيم تُحدث تلقائيًا من بيانات الطلبات الفعلية.\n"
                        "▪️ النص التحليلي أسفل الصفحة يوضح أداء الشهر مقارنة بالشهر السابق.",
                    style: TextStyle(color: Colors.black54, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMonth,
          isExpanded: true,
          items: _availableMonths
              .map((m) => DropdownMenuItem<String>(
            value: m["id"],
            child: Text(m["label"]!,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _selectedMonth = v);
              _controller.forward(from: 0);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats) {
    final cards = [
      {
        "title": "إجمالي الطلبات",
        "value": stats["total"].toString(),
        "color": Colors.blue,
        "icon": Icons.list_alt_rounded
      },
      {
        "title": "الطلبات الناجحة",
        "value": stats["successful"].toString(),
        "color": Colors.green,
        "icon": Icons.check_circle_outline
      },
      {
        "title": "الطلبات المرفوضة",
        "value": stats["rejected"].toString(),
        "color": Colors.red,
        "icon": Icons.cancel_outlined
      },
      {
        "title": "إجمالي المبيعات",
        "value": "${stats["revenue"].toStringAsFixed(0)} ل.س",
        "color": const Color(0xFFF5C147),
        "icon": Icons.attach_money_rounded
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, i) {
        final c = cards[i];
        final color = c["color"] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(c["icon"] as IconData, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c["title"] as String,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54)),
                    Text(c["value"] as String,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressLine(
      String title, double percentage, Color color, IconData icon) {
    percentage = percentage.clamp(0, 100);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final animatedWidth = MediaQuery.of(context).size.width *
            ((percentage * _controller.value) / 100);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  height: 10,
                  width: animatedWidth,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text("${percentage.toStringAsFixed(1)}%",
                style:
                const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
