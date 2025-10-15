import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart';

// إبقاء الاستيراد كما هو في مشروعك (حتى لو لم نستخدمه هنا)
import 'services/notification_service.dart';
// ✅ إضافة FCMService
import 'services/fcm_service.dart';
import 'auth_page.dart';
import 'merchant_dashboard.dart';
import 'merchant_orders_page.dart'; // ✅ جديد
import 'admin_store_editor.dart';
import 'add_to_firebase_database.dart';
import 'super_admin_dashboard.dart';
import 'super_admin_home.dart';
import 'waiting_page.dart';

// ✅ مفتاح التنقل العام لتوجيه المستخدم من خارج السياق
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ تهيئة الإشعارات FCM
  // ✅ تهيئة إشعارات FCM مرة واحدة فقط
  await FCMService.initialize();


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ يسمح بفتح صفحات من خارج السياق
      debugShowCheckedModeBanner: false,
      title: 'Otaibah Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF988561)),
        useMaterial3: true,
        fontFamily: 'PortadaAra',
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'PortadaAra',
      ),
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  /// ✅ تحديد الصفحة المناسبة حسب بيانات المستخدم
  Future<Widget> _getHomePage(User user) async {
    final userRef = FirebaseDatabase.instance.ref("otaibah_users/${user.uid}");
    final snap = await userRef.get();

    if (!snap.exists) {
      return const AuthPage(); // ما في بيانات → يطلب تسجيل
    }

    final data = Map<String, dynamic>.from(snap.value as Map);
    final role = data["role"];
    final pending = data["pending"] ?? false;

    // ✅ لو الحساب قيد المراجعة
    if (pending == true) {
      return const WaitingPage();
    }

    // ✅ لو سوبر أدمن
    if (role == "super_admin") {
      return const SuperAdminHome();
    }

    // ✅ لو أدمن ناشر
    if (role == "admin") {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF988561),
          title: const Text("لوحة الأدمن"),
        ),
        body: const AddToFirebaseDatabase(),
      );
    }

    // ✅ لو تاجر
    if (role == "merchant") {
      final shopId = data["shopId"];
      if (shopId == null || shopId.toString().isEmpty) {
        // ما عنده متجر → يضيف متجر
        return const AdminStoreEditor();
      } else {
        // عنده متجر → لوحة التاجر
        return MerchantDashboard(shopId: shopId);
      }
    }

    // ✅ لو موظف توصيل
    if (role == "delivery") {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF988561),
          title: const Text("لوحة موظف التوصيل"),
        ),
        body: const Center(
          child: Text("هنا تظهر الطلبات المخصصة لموظف التوصيل"),
        ),
      );
    }

    // ❌ أي حالة أخرى → يرجع لتسجيل الدخول
    return const AuthPage();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ⏳ لسه عم نتحقق من حالة المستخدم
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ ما في مستخدم → لازم يسجل دخول
        if (!snapshot.hasData) {
          return const AuthPage();
        }

        // ✅ في مستخدم → نجيب بياناته من DB ونحدد الصفحة
        final user = snapshot.data!;
        return FutureBuilder<Widget>(
          future: _getHomePage(user),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snap.hasData) {
              return const AuthPage();
            }
            return snap.data!;
          },
        );
      },
    );
  }
}
