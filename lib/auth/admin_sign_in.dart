import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'admin_sign_up.dart';
import '../waiting_page.dart'; // ✅ موجود داخل lib
import '../publisher/publisher_dashboard.dart'; // ✅ مسار الناشر
import '../merchant_dashboard.dart'; // ✅ مسار التاجر
import '../super_admin_dashboard.dart'; // ✅ مسار المدير

class AdminSignIn extends StatefulWidget {
  const AdminSignIn({super.key});

  @override
  State<AdminSignIn> createState() => _AdminSignInState();
}

class _AdminSignInState extends State<AdminSignIn> {
  bool obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _showSnack(String msg, Color color) {
    if (!mounted) return; // ✅ تأكد أن الواجهة ما انحذفت
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack('تحقق من البريد أو كلمة المرور', Colors.red);
      return;
    }

    // ✅ عرض مؤشر التحميل (بحماية كاملة)
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.brown),
        ),
      );
    }

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showSnack('تعذر تسجيل الدخول. حاول مجددًا.', Colors.red);
        return;
      }

      final snap = await FirebaseDatabase.instance.ref('otaibah_users/$uid').get();
      final data = (snap.value as Map?) ?? {};

      final bool pending = data['pending'] == true;
      final String role = (data['role'] ?? 'publisher').toString();
      final String shopId = (data['shopId'] ?? '') as String;

      // ✅ إغلاق المؤشر دائمًا بعد الجلب
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (!mounted) return;
      _showSnack('تم تسجيل الدخول إلى حسابك بنجاح ✅', Colors.green);
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      if (pending) {
        _showSnack('تم إرسال طلبك إلى مدير التطبيق وسيتم مراجعته قريبًا.', Colors.black87);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WaitingPage()),
              (_) => false,
        );
        return;
      }

      // ✅ التوجيه حسب الدور
      if (!mounted) return;
      switch (role) {
        case 'merchant':
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MerchantDashboard(shopId: shopId)),
                (_) => false,
          );
          break;
        case 'super_admin':
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SuperAdminDashboard()),
                (_) => false,
          );
          break;
        default:
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PublisherDashboard()),
                (_) => false,
          );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      String msg = e.message ?? e.code;
      if (e.code == 'user-not-found') msg = 'البريد غير مسجل!';
      if (e.code == 'wrong-password') msg = 'كلمة المرور غير صحيحة!';
      _showSnack(msg, Colors.red);
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showSnack('حدث خطأ غير متوقع: $e', Colors.red);
    }
  }



  // ✅ توجيه المستخدم حسب نوع الحساب
  void _goToRoleHome(String role, String shopId) {
    Widget page;
    switch (role) {
      case 'merchant':
        page = MerchantDashboard(shopId: shopId); // ✅ أضفنا shopId الإجباري
        break;
      case 'super_admin':
        page = const SuperAdminDashboard();
        break;
      default:
        page = const PublisherDashboard();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
          (_) => false,
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('أدخل بريدك الإلكتروني أولاً', Colors.red);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack('تم إرسال رابط إعادة التعيين إلى بريدك', Colors.green);
    } catch (e) {
      _showSnack('تعذّر الإرسال: $e', Colors.red);
    }
  }

  InputDecoration _decor({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black54),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.transparent,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black26, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF988561), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    SvgPicture.asset('assets/svg/app_logo.svg', height: 40, width: 40),
                    const SizedBox(height: 8),
                    const Text('تطبيق بلدة العتيبة',
                        style: TextStyle(fontSize: 16, color: Colors.black54)),
                    const SizedBox(height: 12),
                    const Text('تسجيل الدخول',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    // البريد الإلكتروني
                    TextField(
                      controller: _emailController,
                      textAlign: TextAlign.right,
                      decoration: _decor(
                        hint: 'البريد الإلكتروني',
                        prefix: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: SvgPicture.asset(
                            'assets/svg/email_icon.svg',
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // كلمة المرور
                    TextField(
                      controller: _passwordController,
                      obscureText: obscurePassword,
                      textAlign: TextAlign.right,
                      decoration: _decor(
                        hint: 'كلمة المرور',
                        prefix: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: SvgPicture.asset(
                            'assets/svg/password_icon.svg',
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          ),
                        ),
                        suffix: InkWell(
                          onTap: () => setState(() => obscurePassword = !obscurePassword),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: SvgPicture.asset(
                              obscurePassword
                                  ? 'assets/svg/eye_closed.svg'
                                  : 'assets/svg/eye_open.svg',
                              width: 14,
                              height: 14,
                              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // زر تسجيل الدخول
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        onPressed: _signIn,
                        child: const Text('تسجيل الدخول', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // نسيت كلمة المرور
                    TextButton(
                      onPressed: _resetPassword,
                      child: const Text(
                        'نسيت كلمة المرور؟',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),

                    const Text('ليس لديك حساب بعد؟', style: TextStyle(color: Colors.black87)),
                    const SizedBox(height: 8),

                    // زر إنشاء حساب
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: const Color(0xFF988561),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (c) => const AdminSignUp()),
                          );
                        },
                        child: const Text(
                          'إنشاء حساب جديد',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
