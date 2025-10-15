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
}
