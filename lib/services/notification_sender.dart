import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationSender {
  static Future<void> sendNotification({
    required String token,
    required String title,
    required String body,
    required String orderId,
    required String status,
    Map<String, dynamic>? data,
  }) async {
    try {
      final db = FirebaseDatabase.instance.ref("orders/$orderId");
      final lastSnap = await db.child("lastNotifiedStatus").get();

      if (lastSnap.exists && lastSnap.value == status) {
        print("⚠️ تم إرسال إشعار سابق لهذه الحالة، لن نكررها.");
        return;
      }

      final callable = FirebaseFunctions.instance.httpsCallable('sendNotification');
      await callable.call({
        "token": token,
        "title": title,
        "body": body,
        "data": data ?? {},
      });

      await db.child("lastNotifiedStatus").set(status);
      print("✅ إشعار جديد تم إرساله بنجاح ($status)");
    } catch (e) {
      print("❌ خطأ أثناء إرسال الإشعار: $e");
    }
  }

  // ✅ إرسال إشعار الموافقة على الحساب
  static Future<void> sendAccountApprovalNotification(String userId) async {
    try {
      final userRef = FirebaseDatabase.instance.ref('otaibah_users/$userId');
      final snap = await userRef.get();
      if (!snap.exists) {
        print("⚠️ لم يتم العثور على المستخدم $userId");
        return;
      }

      final data = snap.value as Map?;
      final token = data?['fcmToken'];
      final role = data?['role'] ?? 'publisher';
      final name = data?['name'] ?? 'مستخدم';

      if (token == null) {
        print("⚠️ لا يوجد FCM token للمستخدم $userId");
        return;
      }

      final title = "تمت الموافقة على حسابك 🎉";
      final body = "مرحباً $name، تم تفعيل حسابك كـ $role ويمكنك الآن استخدام جميع ميزات التطبيق.";

      final callable = FirebaseFunctions.instance.httpsCallable('sendNotification');
      await callable.call({
        "token": token,
        "title": title,
        "body": body,
        "data": {"type": "account_approved", "role": role},
      });

      print("✅ تم إرسال إشعار الموافقة للمستخدم $userId");
    } catch (e) {
      print("❌ خطأ أثناء إرسال إشعار الموافقة: $e");
    }
  }



}
