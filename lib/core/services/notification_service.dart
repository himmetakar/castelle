import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/constants/app_constants.dart';

// Castelle - Notification Service
// Bildirim CRUD + toplu gönderim operasyonları — saf Firestore, yerel depolama yok

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'notifications';

  /// Tek kullanıcıya bildirim gönder — direkt Firestore
  Future<void> sendNotification(NotificationModel notification) async {
    try {
      final data = notification.toMap();
      data['userId'] = notification.recipientId;
      data['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(_collection).add(data);
    } catch (e) {
      debugPrint('⚠️ [NotificationService.sendNotification Error]: $e');
    }
  }

  /// Toplu bildirim gönder (belirli hedef kitleye) — direkt Firestore batch
  Future<int> sendBulkNotification({
    required String title,
    required String body,
    required NotificationType type,
    required NotificationTarget target,
    String? senderId,
    String? senderName,
    String? projectId,
    Map<String, dynamic>? data,
  }) async {
    final recipients = await _getTargetRecipients(target);
    if (recipients.isEmpty) {
      debugPrint('ℹ️ [NotificationService.sendBulkNotification] No recipients for target: ${target.name}');
      return 0;
    }

    int sentCount = 0;
    WriteBatch currentBatch = _firestore.batch();
    int batchCount = 0;
    final batches = <WriteBatch>[];

    for (final recipientId in recipients) {
      final docRef = _firestore.collection(_collection).doc();
      currentBatch.set(docRef, {
        'recipientId': recipientId,
        'userId': recipientId,
        'title': title,
        'body': body,
        'type': type.value,
        'isRead': false,
        'senderId': senderId,
        'senderName': senderName,
        'projectId': projectId,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batchCount++;
      sentCount++;

      if (batchCount >= 450) {
        batches.add(currentBatch);
        currentBatch = _firestore.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      batches.add(currentBatch);
    }

    try {
      for (final batch in batches) {
        await batch.commit();
      }
      debugPrint('✅ [NotificationService.sendBulkNotification] Sent $sentCount notifications');
    } catch (e) {
      debugPrint('⚠️ [NotificationService.sendBulkNotification Batch Error]: $e');
    }

    return sentCount;
  }

  /// Hedef kitle uid listesini getir — Firestore
  Future<List<String>> _getTargetRecipients(NotificationTarget target) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(AppConstants.usersCollection);

      switch (target) {
        case NotificationTarget.all:
          break;
        case NotificationTarget.actors:
          query = query.where('role', isEqualTo: 'actor');
          break;
        case NotificationTarget.employers:
          query = query.where('role', isEqualTo: 'employer');
          break;
        case NotificationTarget.directors:
          query = query.where('role', isEqualTo: 'director');
          break;
        case NotificationTarget.moderators:
          query = query.where('role', isEqualTo: 'moderator');
          break;
        case NotificationTarget.admins:
          query = query.where('role', isEqualTo: 'admin');
          break;
        case NotificationTarget.specific:
          return [];
      }

      query = query.where('isActive', isEqualTo: true);
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('⚠️ [NotificationService._getTargetRecipients Error]: $e');
      return [];
    }
  }

  /// Kullanıcının bildirimlerini getir — Firestore (index gerektirmez, client-side sıralama)
  Future<List<NotificationModel>> getUserNotifications(
    String uid, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      // orderBy kaldırıldı → bileşik index gerekmez
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collection)
          .where('recipientId', isEqualTo: uid)
          .limit(limit);

      final snapshot = await query.get();
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();

      // Client-side sıralama
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('⚠️ [NotificationService.getUserNotifications Error]: $e');
      return [];
    }
  }

  /// Bildirim stream'i (gerçek zamanlı) — Firestore (index gerektirmez)
  Stream<List<NotificationModel>> streamUserNotifications(
      String uid, {int limit = 50}) {
    return _firestore
        .collection(_collection)
        .where('recipientId', isEqualTo: uid)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
              .toList();
          // Client-side sıralama
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Okunmamış bildirim sayısı stream'i — Firestore (index gerektirmez)
  Stream<int> streamUnreadCount(String uid) {
    return _firestore
        .collection(_collection)
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Bildirimi okundu işaretle — Firestore
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('⚠️ [NotificationService.markAsRead Error]: $e');
    }
  }

  /// Tümünü okundu işaretle — Firestore batch
  Future<void> markAllAsRead(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('recipientId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('⚠️ [NotificationService.markAllAsRead Error]: $e');
    }
  }

  /// Bildirimi sil — Firestore
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).delete();
    } catch (e) {
      debugPrint('⚠️ [NotificationService.deleteNotification Error]: $e');
    }
  }

  /// Kullanıcının tüm bildirimlerini sil — Firestore batch
  Future<void> deleteAllNotifications(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('recipientId', isEqualTo: uid)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('⚠️ [NotificationService.deleteAllNotifications Error]: $e');
    }
  }
}
