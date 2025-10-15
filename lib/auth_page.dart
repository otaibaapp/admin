// lib/auth_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref("otaibah_users");

  String? _selectedRole;
  final List<Map<String, String>> _roles = [
    {"key": "admin", "label": "أدمن"},
    {"key": "merchant", "label": "تاجر"},
    {"key": "delivery", "label": "موظف توصيل"},
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        // ✅ تسجيل دخول
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // 👉 التوجيه سيتم من RootPage في main.dart
      } else {
        // ✅ تحقق من مطابقة كلمة المرور
        if (_passwordController.text.trim() !=
            _confirmPasswordController.text.trim()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("كلمتا المرور غير متطابقتين")),
          );
          setState(() => _loading = false);
          return;
        }

        if (_selectedRole == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("الرجاء اختيار نوع الحساب")),
          );
          setState(() => _loading = false);
          return;
        }

        // ✅ إنشاء حساب جديد
        final cred = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // إضافة المستخدم في قاعدة البيانات مع pending = true
        await _db.child(cred.user!.uid).set({
          "name": _nameController.text.trim(),
          "email": _emailController.text.trim(),
          "role": _selectedRole,
          "pending": true, // 👈 يحتاج موافقة المدير
          "shopId": null,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تم إرسال طلبك للمدير، يرجى انتظار الموافقة."),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "خطأ غير متوقع")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("أدخل بريدك الإلكتروني أولاً")),
      );
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إرسال رابط إعادة التعيين لبريدك")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: Text(_isLogin ? "تسجيل الدخول" : "إنشاء حساب"),
        backgroundColor: const Color(0xFF988561),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (!_isLogin) ...[
                  // الاسم الثلاثي
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "الاسم الثلاثي"),
                    validator: (v) =>
                    v == null || v.isEmpty ? "أدخل الاسم الثلاثي" : null,
                  ),
                  const SizedBox(height: 10),

                  // اختيار الدور
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: "اختر نوع الحساب",
                      border: OutlineInputBorder(),
                    ),
                    items: _roles
                        .map((r) => DropdownMenuItem(
                      value: r["key"],
                      child: Text(r["label"]!),
                    ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedRole = val),
                  ),
                  const SizedBox(height: 10),
                ],

                // البريد الإلكتروني
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "البريد الإلكتروني"),
                  validator: (v) =>
                  v == null || !v.contains("@") ? "بريد غير صالح" : null,
                ),
                const SizedBox(height: 10),

                // كلمة المرور
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "كلمة المرور"),
                  validator: (v) =>
                  v == null || v.length < 6 ? "على الأقل 6 محارف" : null,
                ),
                const SizedBox(height: 10),

                // تأكيد كلمة المرور (فقط عند التسجيل)
                if (!_isLogin)
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration:
                    const InputDecoration(labelText: "تأكيد كلمة المرور"),
                    validator: (v) {
                      if (!_isLogin) {
                        if (v == null || v.isEmpty) {
                          return "أدخل تأكيد كلمة المرور";
                        }
                        if (v != _passwordController.text.trim()) {
                          return "كلمتا المرور غير متطابقتين";
                        }
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 20),

                // زر الدخول / التسجيل
                if (_loading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF988561),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                    ),
                    child: Text(_isLogin ? "تسجيل الدخول" : "إنشاء حساب"),
                  ),

                const SizedBox(height: 10),

                // رابط استعادة كلمة المرور
                TextButton(
                  onPressed: _resetPassword,
                  child: const Text("نسيت كلمة المرور؟"),
                ),

                // تبديل بين تسجيل / إنشاء حساب
                TextButton(
                  onPressed: () {
                    setState(() => _isLogin = !_isLogin);
                  },
                  child: Text(
                    _isLogin ? "إنشاء حساب جديد" : "لديك حساب؟ تسجيل الدخول",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
