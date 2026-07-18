import 'dart:async';
import 'package:flutter/material.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/services/notification_service.dart';

// Castelle - Notification Provider
// Bildirim durum yönetimi — saf Firestore, yerel depolama yok

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<NotificationModel>>? _notifSub;
  StreamSubscription<int>? _unreadSub;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasUnread => _unreadCount > 0;

  /// Gerçek zamanlı bildirim dinlemeyi başlat — sadece stream kullanır (race condition yok)
  void startListening(String uid, {String? role}) {
    // Bildirim stream — tek kaynak, loadNotifications ile yarış yok
    _notifSub?.cancel();
    _notifSub = _service.streamUserNotifications(uid).listen(
      (notifs) {
        _notifications = notifs;
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('⚠️ [NotificationProvider] Stream error: $e');
      },
    );

    // Okunmamış sayı stream
    _unreadSub?.cancel();
    _unreadSub = _service.streamUnreadCount(uid).listen(
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
      onError: (_) {
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      },
    );
  }

  /// Dinlemeyi durdur
  void stopListening() {
    _notifSub?.cancel();
    _unreadSub?.cancel();
    _notifSub = null;
    _unreadSub = null;
  }

  /// Bildirimleri manuel yükle
  Future<void> loadNotifications(String uid, {String? role}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _service.getUserNotifications(uid);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Okundu işaretle
  Future<void> markAsRead(String notificationId) async {
    // Önce UI'ı güncelle (optimistik)
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
    // Sonra Firestore'u güncelle
    await _service.markAsRead(notificationId);
  }

  /// Tümünü okundu işaretle
  Future<void> markAllAsRead(String uid) async {
    // Önce UI'ı güncelle (optimistik)
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();
    // Sonra Firestore'u güncelle
    await _service.markAllAsRead(uid);
  }

  /// Bildirimi sil
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
    await _service.deleteNotification(notificationId);
  }

  /// Toplu bildirim gönder (Admin)
  Future<int> sendBulkNotification({
    required String title,
    required String body,
    required NotificationType type,
    required NotificationTarget target,
    String? senderId,
    String? senderName,
    String? projectId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final count = await _service.sendBulkNotification(
        title: title,
        body: body,
        type: type,
        target: target,
        senderId: senderId,
        senderName: senderName,
        projectId: projectId,
      );
      _isLoading = false;
      notifyListeners();
      return count;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return 0;
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
