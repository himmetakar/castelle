import 'package:cloud_firestore/cloud_firestore.dart';

// Castelle - Notification Model
// Uygulama içi bildirim sistemi

/// Bildirim türü
enum NotificationType {
  castingInvite('casting_invite', 'Casting Daveti'),
  projectUpdate('project_update', 'Proje Güncellemesi'),
  auditionResult('audition_result', 'Audition Sonucu'),
  systemMessage('system_message', 'Sistem Mesajı'),
  announcement('announcement', 'Duyuru'),
  roleAssigned('role_assigned', 'Rol Atandı'),
  deadlineReminder('deadline_reminder', 'Süre Hatırlatması'),
  newProject('new_project', 'Yeni Proje'),
  newAudition('new_audition', 'Yeni Audition Başvurusu'),
  forwardedAudition('forwarded_audition', 'Yönlendirilen Audition'),
  calendarEvent('calendar_event', 'Takvim Etkinliği');

  const NotificationType(this.value, this.displayName);
  final String value;
  final String displayName;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => NotificationType.systemMessage,
    );
  }

  /// Her türe ait ikon
  String get iconName {
    return switch (this) {
      NotificationType.castingInvite => 'campaign',
      NotificationType.projectUpdate => 'movie',
      NotificationType.auditionResult => 'how_to_vote',
      NotificationType.systemMessage => 'info',
      NotificationType.announcement => 'notifications',
      NotificationType.roleAssigned => 'person_add',
      NotificationType.deadlineReminder => 'timer',
      NotificationType.newProject => 'movie_creation',
      NotificationType.newAudition => 'rate_review',
      NotificationType.forwardedAudition => 'forward_to_inbox',
      NotificationType.calendarEvent => 'calendar_month',
    };
  }
}

/// Bildirim hedef kitlesi (toplu gönderim için)
enum NotificationTarget {
  all('all', 'Tüm Kullanıcılar'),
  actors('actors', 'Tüm Oyuncular'),
  employers('employers', 'Tüm İş Verenler'),
  directors('directors', 'Tüm Yönetmenler'),
  moderators('moderators', 'Tüm Moderatörler'),
  admins('admins', 'Tüm Adminler'),
  specific('specific', 'Belirli Kullanıcı');

  const NotificationTarget(this.value, this.displayName);
  final String value;
  final String displayName;
}

/// Bildirim Modeli
class NotificationModel {
  final String id;
  final String recipientId;      // Alıcı uid
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final String? senderId;        // Gönderen uid (sistem ise null)
  final String? senderName;
  final String? projectId;       // İlgili proje (varsa)
  final String? actionUrl;       // Deep link (gelecek için)
  final Map<String, dynamic>? data; // Ek veri
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    this.type = NotificationType.systemMessage,
    this.isRead = false,
    this.senderId,
    this.senderName,
    this.projectId,
    this.actionUrl,
    this.data,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      recipientId: map['recipientId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: NotificationType.fromString(map['type'] ?? 'system_message'),
      isRead: map['isRead'] ?? false,
      senderId: map['senderId'],
      senderName: map['senderName'],
      projectId: map['projectId'],
      actionUrl: map['actionUrl'],
      data: map['data'] as Map<String, dynamic>?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'userId': recipientId,
      'title': title,
      'body': body,
      'type': type.value,
      'isRead': isRead,
      'senderId': senderId,
      'senderName': senderName,
      'projectId': projectId,
      'actionUrl': actionUrl,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      recipientId: recipientId,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      senderId: senderId,
      senderName: senderName,
      projectId: projectId,
      actionUrl: actionUrl,
      data: data,
      createdAt: createdAt,
    );
  }
}
