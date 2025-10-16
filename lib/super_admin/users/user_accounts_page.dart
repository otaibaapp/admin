// lib/super_admin/users/user_accounts_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:lottie/lottie.dart';

class UserAccountsPage extends StatefulWidget {
  const UserAccountsPage({super.key});

  @override
  State<UserAccountsPage> createState() => _UserAccountsPageState();
}

class _UserAccountsPageState extends State<UserAccountsPage> {
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref("otaibah_users");
  bool _loading = true;
  Map<String, dynamic> _users = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final snap = await _usersRef.get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);

      // ✅ نعرض المستخدمين اللي دورهم "user" أو بدون role واضح
      final filtered = data.map((k, v) {
        if (v is Map &&
            (v["role"] == null || v["role"] == "user" || v["role"] == "customer")) {
          return MapEntry(k, v);
        }
        return MapEntry(k, {});
      })..removeWhere((k, v) => v.isEmpty);

      setState(() {
        _users = filtered;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }


  Future<void> _deleteUser(String uid) async {
    await _usersRef.child(uid).remove();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🗑️ تم حذف المستخدم")),
    );
    _loadUsers();
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
          title: const Text("إدارة المستخدمين",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: _loading
            ? Center(child: Lottie.asset('assets/lottie/loading.json', width: 100))
            : _users.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/empty.json', width: 180),
              const SizedBox(height: 10),
              const Text(
                "لا توجد بيانات حالياً",
                style: TextStyle(color: Colors.black54, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )


            : ListView(
          padding: const EdgeInsets.all(12),
          children: _users.entries.map((entry) {
            final uid = entry.key;
            final user = Map<String, dynamic>.from(entry.value);
            final name = user["name"] ?? "مجهول";
            final email = user["email"] ?? "بدون بريد";

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(email,
                    style: const TextStyle(color: Colors.black54)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(uid),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
