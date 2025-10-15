import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'otaibah_channel',
    'Otaibah Notifications',
    description: 'إشعارات تطبيق العتيبة',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    // تهيئة الإشعارات المحلية
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // إنشاء القناة على أندرويد
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // طلب الصلاحيات
    await FirebaseMessaging.instance.requestPermission(); // iOS/عام
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission(); // Android 13+
    }

    // ملاحظة: الاستماع لرسائل المقدّمة حالياً مُفعّل داخل FCMService
    // إبقاء هذا الكود كما هو للاستخدام المستقبلي عند الحاجة.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notif = message.notification;
      if (notif == null) return;

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      );

      await _plugin.show(
        notif.hashCode,
        notif.title ?? 'إشعار جديد',
        notif.body ?? '',
        details,
      );
    });
  }
}
