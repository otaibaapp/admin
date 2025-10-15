import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WaitingPage extends StatelessWidget {
  const WaitingPage({super.key});

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
