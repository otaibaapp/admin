import 'package:flutter/material.dart';
import 'super_admin_dashboard.dart';
import 'admin_store_editor.dart';
import 'add_to_firebase_database.dart';

class SuperAdminHome extends StatefulWidget {
  const SuperAdminHome({super.key});

  @override
  State<SuperAdminHome> createState() => _SuperAdminHomeState();
}

class _SuperAdminHomeState extends State<SuperAdminHome> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    SuperAdminDashboard(),   // تبويب 1: تعديل الأدوار
    AdminStoreEditor(),      // تبويب 2: إدارة المتاجر
    AddToFirebaseDatabase(), // تبويب 3: إضافة بيانات للتطبيق
  ];

  final List<String> _titles = const [
    "إدارة الأدوار",
    "إدارة المتاجر",
    "لوحة البيانات",
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: const Color(0xFF988561),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF988561),
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: "الأدوار",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: "المتاجر",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "البيانات",
          ),
        ],
      ),
    );
  }
}
