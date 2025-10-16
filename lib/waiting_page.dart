import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'publisher/publisher_dashboard.dart';
import 'merchant_dashboard.dart';
import 'super_admin_dashboard.dart';

class WaitingPage extends StatefulWidget {
  const WaitingPage({super.key});

  @override
  State<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> {
  late DatabaseReference _userRef;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userRef = FirebaseDatabase.instance.ref('otaibah_users/$uid');
      _userRef.onValue.listen((event) {
        final data = (event.snapshot.value as Map?) ?? {};
        final pending = data['pending'] == true;
        final role = (data['role'] ?? 'publisher').toString();
        final shopId = (data['shopId'] ?? '').toString();

        if (!pending && !_handled) {
          _handled = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ تمت الموافقة على حسابك، يمكنك الآن استخدام جميع ميزات التطبيق.',
                textAlign: TextAlign.center,
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          Future.delayed(const Duration(seconds: 2), () {
            _navigateToHome(role, shopId);
          });
        }
      });
    }
  }

  void _navigateToHome(String role, String shopId) {
    Widget page;
    switch (role) {
      case 'merchant':
        page = MerchantDashboard(shopId: shopId);
        break;
      case 'super_admin':
        page = const SuperAdminDashboard();
        break;
      case 'publisher':
      default:
        page = const PublisherDashboard();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF988561),
        title: const Text("حسابك قيد المراجعة"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "تسجيل الخروج",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "🚧 شكراً لتسجيلك.\n\n"
                "حسابك قيد المراجعة من قِبل مدير التطبيق.\n\n"
                "سيتم إشعارك بمجرد الموافقة وتفعيل الحساب.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}
