import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../merchant_orders_page.dart';
import '../main.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'otaibah_channel',
    'إشعارات العتيبة',
    description: 'قناة إشعارات الطلبات',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  // =========================================================
  // 🟢 تهيئة النظام (المكافئ لـ initLocalNotifications + requestPermission + listenToForegroundMessages)
  // =========================================================
  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        print("📩 onDidReceiveNotificationResponse payload: $payload");

        if (payload == null || payload.isEmpty) return;

        try {
          final data = jsonDecode(payload);
          final shopId = (data['shopId'] ?? "").toString();
          final orderId = (data['orderId'] ?? "").toString();

          if (shopId.isEmpty) {
            print("⚠️ payload بدون shopId، لن يتم فتح الصفحة");
            return;
          }

          // تأخير خفيف لضمان جاهزية الـ Navigator/Firebase
          await Future.delayed(const Duration(milliseconds: 500));

          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => MerchantOrdersPage(
                shopId: shopId,
                highlightedOrderId: orderId,
              ),
            ),
          );
        } catch (e) {
          print("⚠️ خطأ أثناء فك الـ payload: $e");
        }
      },
    );

    // إنشاء القناة
    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // طلب الصلاحيات
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // أثناء المقدّمة
    FirebaseMessaging.onMessage.listen(_onMessage);

    // التطبيق بالخلفية وتم الضغط على الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final data = message.data;
      final shopId = (data['shopId'] ?? "").toString();
      final orderId = (data['orderId'] ?? "").toString();

      if (shopId.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => MerchantOrdersPage(
              shopId: shopId,
              highlightedOrderId: orderId,
            ),
          ),
        );
      }
    });

    // التطبيق كان مُغلق تماماً وتم فتحه من الإشعار
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final data = initialMessage.data;
      final shopId = (data['shopId'] ?? "").toString();
      final orderId = (data['orderId'] ?? "").toString();

      if (shopId.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 700));
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => MerchantOrdersPage(
              shopId: shopId,
              highlightedOrderId: orderId,
            ),
          ),
        );
      }
    }
  }


  // =========================================================
  // 🟠 استقبال الإشعارات أثناء عمل التطبيق
  // =========================================================
  static void _onMessage(RemoteMessage message) {
    final notif = message.notification;
    final data = message.data;

    if (notif != null) {
      _showNotification(
        notif.title ?? "إشعار جديد",
        notif.body ?? "",
        data,
      );
    }
  }

  // =========================================================
  // 🟣 عند فتح التطبيق من الإشعار
  // =========================================================
  static void _onMessageOpened(RemoteMessage message) {
    final data = message.data;
    final shopId = data['shopId'];
    final orderId = data['orderId'];
    if (shopId != null) {
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) =>
            MerchantOrdersPage(shopId: shopId, highlightedOrderId: orderId),
      ));
    }
  }

  // =========================================================
  // 🔵 عرض الإشعار محلياً (مع إيقاظ الشاشة)
  // =========================================================
  static Future<void> _showNotification(
      String title, String body, Map<String, dynamic> data) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableLights: true,
        enableVibration: true,
        fullScreenIntent: true,
        groupKey: "orders",
        ticker: 'otaibah_notification',
        icon: '@mipmap/ic_launcher',
      ),
    );

    // ✅ تأكد إنك تمرّر الـ payload هنا
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: jsonEncode({
        "shopId": data["shopId"] ?? "",
        "orderId": data["orderId"] ?? "",
      }),
    );

  }


  // =========================================================
  // 🟤 حفظ توكن المستخدم
  // =========================================================
  static Future<void> saveUserFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token != null) {
      final ref = FirebaseDatabase.instance.ref("users/${user.uid}/fcmToken");
      await ref.set(token);
      print("✅ تم حفظ توكن المستخدم بنجاح");
    }
  }

  // =========================================================
  // ⚫ حفظ توكن التاجر
  // =========================================================
  static Future<void> saveMerchantFcmToken(String shopId) async {
    final token = await _messaging.getToken();
    if (token != null) {
      final root = FirebaseDatabase.instance.ref("merchants/$shopId");
      await root.child("fcmTokens/$token").set(true);
      await root.child("fcmToken").set(token);
      print("✅ تم حفظ توكن التاجر: $token");
    }
  }
}
