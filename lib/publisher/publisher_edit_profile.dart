import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class PublisherEditProfile extends StatefulWidget {
  const PublisherEditProfile({super.key});

  @override
  State<PublisherEditProfile> createState() => _PublisherEditProfileState();
}

class _PublisherEditProfileState extends State<PublisherEditProfile> {
  final _nameController = TextEditingController();
  String? _imageUrl;
  bool _loading = true;
  final Color gold = const Color(0xFF988561);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ✅ تحميل بيانات الناشر
  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap =
    await FirebaseDatabase.instance.ref("otaibah_publishers/$uid").get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      _nameController.text = data["publisherName"] ?? "";
      _imageUrl = data["publisherImageUrl"];
    }
    setState(() => _loading = false);
  }

  // ✅ اختيار صورة جديدة
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child("otaibah_publishers/$uid/${path.basename(file.path)}");
      await ref.putFile(File(file.path));
      _imageUrl = await ref.getDownloadURL();
      await FirebaseDatabase.instance
          .ref("otaibah_publishers/$uid")
          .update({"publisherImageUrl": _imageUrl});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم تحديث الصورة بنجاح")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // ✅ حفظ التعديلات
  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseDatabase.instance
        .ref("otaibah_publishers/$uid")
        .update({"publisherName": name});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("تم حفظ البيانات ✅")));
  }

  // ✅ حذف الحساب بالكامل (مع تأكيد + حذف المنشورات)
  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد حذف الحساب"),
        content: const Text(
            "⚠️ هل أنت متأكد أنك تريد حذف حسابك وجميع منشوراتك بشكل نهائي؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text("نعم، حذف"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    final uid = user.uid;

    try {
      // ✅ إعادة تسجيل الدخول لتجنب requires-recent-login
      final email = user.email!;
      final cred = EmailAuthProvider.credential(
        email: email,
        password: await _askForPassword(context),
      );
      await user.reauthenticateWithCredential(cred);

      // ✅ حذف جميع منشورات الناشر
      final postsRef = FirebaseDatabase.instance.ref(
          "otaibah_navigators_taps/announcements/categories/general");
      final postsSnap = await postsRef.get();
      if (postsSnap.exists) {
        final data = Map<String, dynamic>.from(postsSnap.value as Map);
        for (var entry in data.entries) {
          final post = Map<String, dynamic>.from(entry.value);
          if (post["publisherId"] == uid || post["sourceId"] == uid) {
            await postsRef.child(entry.key).remove();
          }
        }
      }

      // ✅ حذف بيانات الناشر من otaibah_publishers و otaibah_users
      await FirebaseDatabase.instance.ref("otaibah_publishers/$uid").remove();
      await FirebaseDatabase.instance.ref("otaibah_users/$uid").remove();

      // ✅ حذف الحساب من Firebase Auth
      await user.delete();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم حذف الحساب والمنشورات بنجاح ✅")),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? "حدث خطأ أثناء الحذف";
      if (e.code == 'wrong-password') {
        msg = "كلمة المرور غير صحيحة";
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ $msg")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ خطأ: $e")));
    } finally {
      setState(() => _loading = false);
      await FirebaseAuth.instance.signOut();
    }
  }

  // ✅ طلب كلمة المرور لإعادة المصادقة
  Future<String> _askForPassword(BuildContext context) async {
    final controller = TextEditingController();
    String password = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد كلمة المرور"),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration:
          const InputDecoration(labelText: "أدخل كلمة المرور الحالية"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () {
              password = controller.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );
    return password;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text(
            "تعديل بيانات الناشر",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: "حذف الحساب",
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: _loading ? null : _deleteAccount,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage:
                  _imageUrl != null ? NetworkImage(_imageUrl!) : null,
                  backgroundColor: Colors.grey.shade300,
                  child: _imageUrl == null
                      ? const Icon(Icons.person,
                      size: 48, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: "اسم الناشر",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("حفظ التعديلات",
                      style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
