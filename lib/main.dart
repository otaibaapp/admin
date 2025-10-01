import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:otaibah_app_admin/add_to_firebase_database.dart';
import 'package:otaibah_app_admin/admin_store_editor.dart'; // ✅ أضفنا صفحة إدارة المتاجر

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Otaibah Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF988561)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'لوحة إدارة تطبيق العتيبة'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // ✅ كودك الأصلي بالكامل بدون حذف
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF988561),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // ✅ زر جديد في الأعلى لفتح صفحة إدارة المتاجر
          IconButton(
            tooltip: "إدارة المتاجر",
            icon: const Icon(Icons.store_mall_directory, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminStoreEditor()),
              );
            },
          ),
        ],
      ),

      // ✅ هنا الجسم الرئيسي الأصلي، ضفنا فقط زر إضافي بأسفل الصفحة
      body: SafeArea(
        child: Column(
          children: [
            // ✅ الكود الأصلي لصفحة الإضافة القديمة
            const Expanded(
              child: AddToFirebaseDatabase(),
            ),

            // ✅ زر جديد واضح لفتح صفحة إدارة المتجر
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF988561),
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminStoreEditor()),
                  );
                },
                icon: const Icon(Icons.add_business_rounded),
                label: const Text("إضافة متجر جديد"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
