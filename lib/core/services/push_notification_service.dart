import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

/// Castelle - Push Notification Service
/// Firebase Cloud Messaging (FCM) ile telefona WhatsApp benzeri sesli/banner
/// bildirimler düşürür. Firestore'a yazılan bildirimler zaten uygulama içi
/// listede gösteriliyordu (bkz. NotificationService); bu servis, ayrıca
/// Cloud Functions tarafından gönderilen gerçek push bildirimini telefonun
/// bildirim çubuğunda sesli/banner olarak göstermekten sorumludur.
///
/// Gerçek push'un GÖNDERİLMESİ (Firestore'daki 'notifications' koleksiyonuna
/// yeni bir doküman eklendiğinde ilgili kullanıcının cihazına FCM mesajı
/// gönderilmesi) sunucu tarafında bir Cloud Function ile yapılır
/// (bkz. functions/index.js — `firebase deploy --only functions` ile
/// deploy edilmesi gerekir).

/// Yüksek öncelikli (WhatsApp benzeri) push bildirim kanalı.
/// AndroidManifest.xml içindeki `default_notification_channel_id` ile
/// aynı id'yi kullanmalıdır.
const AndroidNotificationChannel castelleHighImportanceChannel =
    AndroidNotificationChannel(
  'castelle_high_importance',
  'Castelle Bildirimleri',
  description: 'Yeni audition, onay ve mesaj bildirimleri',
  importance: Importance.max,
  playSound: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Uygulama arka plandayken veya tamamen kapalıyken gelen FCM mesajlarını
/// işler. Üst düzey (top-level) bir fonksiyon olmalı ve ayrı bir izole (isolate)
/// üzerinde çalışacağı için `@pragma('vm:entry-point')` taşımalıdır.
/// `notification` alanı dolu bir mesaj geldiğinde Android/iOS bunu zaten
/// otomatik olarak sistem bildirimi + varsayılan ses ile gösterir; burada
/// ekstra bir işlem yapmamıza gerek yoktur.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 [FCM Background] ${message.messageId} — ${message.notification?.title}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _userInitDone = false;

  /// Uygulama açılışında (main()) bir kez çağrılır: yerel bildirim eklentisini
  /// başlatır ve yüksek öncelikli bildirim kanalını oluşturur. Giriş yapılmamış
  /// olsa bile güvenle çağrılabilir.
  Future<void> initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    try {
      await flutterLocalNotificationsPlugin.initialize(initSettings);
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(castelleHighImportanceChannel);
    } catch (e) {
      debugPrint('⚠️ [PushNotificationService] Yerel bildirim başlatma hatası: $e');
    }
  }

  /// Kullanıcı giriş yaptıktan sonra çağrılır:
  /// - Bildirim izni ister (Android 13+ / iOS)
  /// - FCM cihaz token'ını alır ve [onToken] ile kaydettirir
  /// - Token yenilendiğinde tekrar kaydeder
  /// - Uygulama ön plandayken gelen mesajları sistem bildirimi (sesli) olarak gösterir
  Future<void> initForUser({
    required Future<void> Function(String token) onToken,
  }) async {
    if (_userInitDone) return;
    _userInitDone = true;

    final messaging = FirebaseMessaging.instance;

    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      debugPrint('⚠️ [PushNotificationService] İzin isteme hatası: $e');
    }

    // iOS: uygulama ön plandayken de banner + ses göster
    try {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    try {
      final token = await messaging.getToken();
      if (token != null) await onToken(token);
    } catch (e) {
      debugPrint('⚠️ [PushNotificationService] Token alınamadı: $e');
    }

    messaging.onTokenRefresh.listen((token) {
      onToken(token);
    });

    // Uygulama ön plandayken FCM bildirimleri kendiliğinden gösterilmez
    // (Android); bu yüzden yerel bildirim eklentisiyle manuel gösteriyoruz.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          castelleHighImportanceChannel.id,
          castelleHighImportanceChannel.name,
          channelDescription: castelleHighImportanceChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/launcher_icon',
          color: const Color(0xFF1E6B1E),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Kullanıcı çıkış yaptığında sıfırla, böylece bir sonraki kullanıcı için
  /// izin/token akışı yeniden çalışır.
  void reset() {
    _userInitDone = false;
  }
}
