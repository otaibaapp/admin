import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

class StoresSection extends StatefulWidget {
  const StoresSection({super.key});

  @override
  State<StoresSection> createState() => _StoresSectionState();
}

class _StoresSectionState extends State<StoresSection> {
  final DatabaseReference _db =
  FirebaseDatabase.instance.ref("otaibah_navigators_taps/shopping/categories");

  bool _loading = true;
  List<Map<dynamic, dynamic>> _allStores = [];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _loading = true);

    final snapshot = await _db.get();
    final List<Map<dynamic, dynamic>> storesList = [];

    if (snapshot.exists) {
      final Map<dynamic, dynamic> categories =
      Map<dynamic, dynamic>.from(snapshot.value as Map);
      categories.forEach((catName, catData) {
        if (catData is Map) {
          catData.forEach((id, value) {
            if (value is Map) {
              final m = Map<dynamic, dynamic>.from(value);
              m['id'] = id;
              m['category'] = catName;
              storesList.add(m);
            }
          });
        }
      });
    }

    setState(() {
      _allStores = storesList;
      _loading = false;
    });
  }

  Future<void> _hideStore(String category, String id, bool hidden) async {
    await _db.child(category).child(id).update({'hidden': hidden});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(hidden ? 'تم إخفاء المتجر مؤقتًا 🕓' : 'تم إظهاره ✅'),
      backgroundColor: hidden ? Colors.grey.shade700 : Colors.green,
    ));
    _loadStores();
  }

  Future<void> _deleteStore(String category, String id) async {
    await _db.child(category).child(id).remove();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('❌ تم حذف المتجر نهائيًا'),
      backgroundColor: Colors.redAccent,
    ));
    _loadStores();
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
            "إدارة المتاجر",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: _loading
            ? Center(child: Lottie.asset('assets/lottie/loading.json', width: 100))
            : _allStores.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/empty.json', width: 180),
              const SizedBox(height: 10),
              const Text(
                "لا توجد متاجر حالياً",
                style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadStores,
          child: ListView.builder(
            padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            itemCount: _allStores.length,
            itemBuilder: (context, index) {
              final shop = _allStores[index];
              final name = shop['name']?.toString() ?? 'متجر بدون اسم';
              final imageUrl = shop['imageUrl']?.toString() ?? '';
              final discount = shop['discountText']?.toString() ?? '';
              final deliveryTime = shop['deliveryTime']?.toString() ?? '';
              final deliveryMethod =
                  shop['deliveryMethod']?.toString() ?? '';
              final openTime = shop['openTime']?.toString() ?? '';
              final closeTime = shop['closeTime']?.toString() ?? '';
              final description = shop['description']?.toString() ?? '';
              final verified = shop['verified'] == true;
              final hidden = shop['hidden'] == true;
              final category = shop['category'] ?? "غير محدد";

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12)),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 2.35,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.store,
                                      size: 60, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          if (discount.isNotEmpty)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                child: Text(
                                  discount,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (hidden)
                            Positioned(
                              bottom: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade700
                                      .withOpacity(0.85),
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "مخفي مؤقتًا",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        overflow:
                                        TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (verified)
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(right: 4),
                                        child: SvgPicture.asset(
                                          'assets/svg/verified.svg',
                                          width: 14,
                                          height: 14,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "الفئة: $category",
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (deliveryTime.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'خلال $deliveryTime دقيقة',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Image.asset(
                                      'assets/images/time_delivery.png',
                                      width: 15,
                                      height: 15,
                                      fit: BoxFit.contain,
                                    ),
                                  ],
                                ),
                              if (deliveryMethod.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'عبر $deliveryMethod',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Image.asset(
                                      'assets/images/delivery_method.png',
                                      width: 15,
                                      height: 15,
                                      fit: BoxFit.contain,
                                    ),
                                  ],
                                ),
                              if (openTime.isNotEmpty &&
                                  closeTime.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'من $openTime إلى $closeTime',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Image.asset(
                                      'assets/images/clock.png',
                                      width: 15,
                                      height: 15,
                                      fit: BoxFit.contain,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 0, color: Colors.black12),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _hideStore(
                                  category.toString(),
                                  shop['id'].toString(),
                                  !hidden),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hidden
                                    ? Colors.green
                                    : Colors.black87,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                              ),
                              child: Text(
                                hidden ? "إظهار المتجر" : "إخفاء مؤقت",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _deleteStore(
                                  category.toString(),
                                  shop['id'].toString()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                              ),
                              child: const Text(
                                "حذف نهائي",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
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
