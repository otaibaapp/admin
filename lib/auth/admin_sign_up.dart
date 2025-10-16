import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'admin_sign_in.dart';
import '../waiting_page.dart';


class AdminSignUp extends StatefulWidget {
  const AdminSignUp({super.key});

  @override
  State<AdminSignUp> createState() => _AdminSignUpState();
}

class _AdminSignUpState extends State<AdminSignUp> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _selectedRole;

  bool obscurePass = true;
  bool obscureConfirm = true;
  bool loading = false;

  final _roles = const [
    {'key': 'merchant', 'label': 'تاجر'},
    {'key': 'delivery', 'label': 'عامل توصيل'},
    {'key': 'publisher', 'label': 'ناشر'},
    {'key': 'super_admin', 'label': 'مدير'},
  ];

  void _show(String msg, Color c) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
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
      fillColor: Colors.transparent, // ✅ خلفية بيضاء ثابتة لكل الحقول
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

  Future<void> _register() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pass = _password.text.trim();
    final confirm = _confirm.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      _show('يرجى تعبئة جميع الحقول', Colors.red);
      return;
    }
    if (!email.contains('@')) {
      _show('الرجاء إدخال بريد إلكتروني صحيح', Colors.red);
      return;
    }
    if (pass.length < 6) {
      _show('كلمة المرور يجب أن تكون 6 أحرف على الأقل', Colors.red);
      return;
    }
    if (pass != confirm) {
      _show('كلمتا المرور غير متطابقتين', Colors.red);
      return;
    }
    if (_selectedRole == null) {
      _show('الرجاء اختيار نوع الحساب', Colors.red);
      return;
    }

    setState(() => loading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      await FirebaseDatabase.instance
          .ref('otaibah_users/${cred.user!.uid}')
          .set({
        'name': name,
        'email': email,
        'role': _selectedRole,
        'pending': true,
        'shopId': null,
      });

      // ✅ عرض التوستين المطلوبين
      _show('تم تسجيل الدخول إلى حسابك بنجاح ✅', Colors.green);
      await Future.delayed(const Duration(milliseconds: 600));
      _show('تم إرسال طلبك إلى مدير التطبيق وسيتم مراجعته قريبًا.', Colors.black87);


      _show('تم إرسال طلبك للمراجعة، يرجى انتظار الموافقة.', Colors.green);

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const WaitingPage(),
        ),
      );

    } on FirebaseAuthException catch (e) {
      _show(e.message ?? e.code, Colors.red);
    } catch (e) {
      _show('حدث خطأ غير متوقع: $e', Colors.red);
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
                    const Text('فتح حساب جديد',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    // الاسم الكامل
                    TextField(
                      controller: _name,
                      textAlign: TextAlign.right,
                      decoration: _decor(
                        hint: 'الاسم الكامل',
                        prefix: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: SvgPicture.asset(
                            'assets/svg/name_icon.svg',
                            width: 14,
                            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // البريد الإلكتروني
                    TextField(
                      controller: _email,
                      textAlign: TextAlign.right,
                      decoration: _decor(
                        hint: 'البريد الإلكتروني',
                        prefix: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: SvgPicture.asset(
                            'assets/svg/email_icon.svg',
                            width: 14,
                            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // كلمة المرور
                    TextField(
                      controller: _password,
                      obscureText: obscurePass,
                      textAlign: TextAlign.right,
                      decoration: _decor(
                        hint: 'كلمة المرور',
                        prefix: Padding(
                          padding: const EdgeInsets.all(13.0),
                          child: SvgPicture.asset(
                            'assets/svg/password_icon.svg',
                            width: 20,
                            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          ),
                        ),
                        suffix: InkWell(
                          onTap: () => setState(() => obscurePass = !obscurePass),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: SvgPicture.asset(
                              obscurePass
                                  ? 'assets/svg/eye_closed.svg'
                                  : 'assets/svg/eye_open.svg',
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // تأكيد كلمة المرور
                    TextField(
                      controller: _confirm,
                      obscureText: obscureConfirm,
                      textAlign: TextAlign.right,
                      decoration: _decor(
                        hint: 'تأكيد كلمة المرور',
                        prefix: Padding(
                          padding: const EdgeInsets.all(13.0),
                          child: SvgPicture.asset(
                            'assets/svg/password_icon.svg',
                            width: 20,
                            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          ),
                        ),
                        suffix: InkWell(
                          onTap: () => setState(() => obscureConfirm = !obscureConfirm),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: SvgPicture.asset(
                              obscureConfirm
                                  ? 'assets/svg/eye_closed.svg'
                                  : 'assets/svg/eye_open.svg',
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // نوع الحساب
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<String>(
                        value: _selectedRole,
                        isExpanded: true,
                        alignment: Alignment.centerRight,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.black54),
                        dropdownColor: Colors.white,
                        menuMaxHeight: 260,
                        decoration: InputDecoration(
                          hintText: 'اختر نوع الحساب',
                          hintStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: SvgPicture.asset(
                              'assets/svg/user_role_icon.svg',
                              width: 18,
                              colorFilter:
                              const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                            ),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          filled: true,
                          fillColor: Colors.transparent,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.black26, width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                            const BorderSide(color: Color(0xFF988561), width: 1.5),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        items: _roles
                            .map(
                              (r) => DropdownMenuItem(
                            alignment: Alignment.centerRight,
                            value: r['key'],
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                              child: Text(
                                r['label']!,
                                textAlign: TextAlign.right,
                                style:
                                const TextStyle(fontSize: 15, color: Colors.black87),
                              ),
                            ),
                          ),
                        )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedRole = v),
                      ),
                    ),





                    const SizedBox(height: 22),

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
                        onPressed: loading ? null : _register,
                        child: loading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                            : const Text('إنشاء الحساب', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('هل لديك حساب بالفعل؟', style: TextStyle(color: Colors.black87)),
                    const SizedBox(height: 8),

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
                            MaterialPageRoute(builder: (_) => const AdminSignIn()),
                          );
                        },
                        child: const Text(
                          'الانتقال لتسجيل الدخول',
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
