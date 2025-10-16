import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../services/notification_sender.dart'; // ✅ مهم جدًا

class PublisherNewPost extends StatefulWidget {
  const PublisherNewPost({super.key});

  @override
  State<PublisherNewPost> createState() => _PublisherNewPostState();
}

class _PublisherNewPostState extends State<PublisherNewPost> {
  final _contentController = TextEditingController();
  String? _contentImageUrl;
  bool _loading = false;
  bool _sendNotification = false; // ✅ سويتش الإشعار
  final Color gold = const Color(0xFF988561);
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child("otaibah_publishers/$uid/posts/${path.basename(file.path)}");

      await ref.putFile(File(file.path));
      _contentImageUrl = await ref.getDownloadURL();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم رفع الصورة بنجاح ✅")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل رفع الصورة: $e")),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى كتابة محتوى المنشور")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final pubSnap =
      await FirebaseDatabase.instance.ref("otaibah_publishers/$uid").get();

      if (!pubSnap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("يرجى تعيين بيانات الناشر أولاً")),
        );
        setState(() => _loading = false);
        return;
      }

      final data = Map<String, dynamic>.from(pubSnap.value as Map);
      final ref = FirebaseDatabase.instance
          .ref("otaibah_navigators_taps/announcements/categories/general")
          .push();

      final date = DateTime.now();
      final formattedDate = "${date.year}/${date.month}/${date.day}";

      await ref.set({
        "id": ref.key,
        "publisherId": uid,
        "source": data["publisherName"],
        "sourceImageUrl": data["publisherImageUrl"],
        "content": content,
        "contentImgUrl": _contentImageUrl ?? "",
        "dateOfPost": formattedDate,
        "numberOfComments": 0,
        "numberOfLoved": 0,
        "requiresNotification": _sendNotification, // ✅ الحقل الجديد
      });

      // ✅ في حال تم تفعيل الإشعار، أرسل إشعار للمدير فقط
      if (_sendNotification) {
        await _notifyAdmin(ref.key ?? "", data["publisherName"] ?? "ناشر");
      }

      _contentController.clear();
      _contentImageUrl = null;
      setState(() => _sendNotification = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم نشر المنشور بنجاح 🎉")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ أثناء النشر: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  /// ✅ إرسال إشعار إلى المدير فقط
  Future<void> _notifyAdmin(String postId, String publisherName) async {
    try {
      final adminsRef = FirebaseDatabase.instance.ref("otaibah_users");
      final adminsSnap = await adminsRef.get();

      if (!adminsSnap.exists) return;
      final admins = Map<String, dynamic>.from(adminsSnap.value as Map);

      for (var entry in admins.entries) {
        final user = Map<String, dynamic>.from(entry.value);
        if (user["role"] == "super_admin" && user["fcmToken"] != null) {
          await NotificationSender.sendNotification(
            token: user["fcmToken"],
            title: "منشور جديد يتطلب إشعار عام",
            body: "الناشر $publisherName طلب إرسال إشعار عام للمنشور الجديد.",
            orderId: postId,
            status: "new_post_request",
          );
        }
      }

      print("✅ تم إرسال إشعار للمدير بنجاح");
    } catch (e) {
      print("❌ فشل إرسال إشعار للمدير: $e");
    }
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
            "نشر منشور جديد",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _contentController,
                maxLines: 8,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: "اكتب محتوى المنشور...",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_contentImageUrl != null && _contentImageUrl!.isNotEmpty)
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _contentImageUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text("اختيار صورة المنشور (اختياري)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _publish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "نشر",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),


              const SizedBox(height: 25),

              // ✅ خيار إرسال إشعار للمدير
              SwitchListTile(
                value: _sendNotification,
                onChanged: (v) => setState(() => _sendNotification = v),
                title: const Text("إرسال إشعار لكافة مُستخدمي التطبيق"),
                subtitle: const Text(
                  "إذا كُنت تعتقد أنَّ هذا المنشور هام جدًا ويجب أن يصل لجميع مُستخدمي التطبيق فقم بتفعيل الخيار وسيتم إشعار المدير لمراجعة المنشور للإرسال العام, في حال تكرار إرسال الإشعار للمدير دون أن يكون لهذا المنشور أهميّة فربما يتسبب هذا في حذف حسابك أو تقييد صلاحياتك فاستخدم الميّزة بكل حذر.",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                activeColor: Colors.green,
              ),

            ],
          ),
        ),
      ),
    );
  }
}
