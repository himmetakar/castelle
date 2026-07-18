import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/services/notification_service.dart';
import 'package:flutter/foundation.dart';

// Castelle - Project Service
// Proje CRUD operasyonları — saf Firestore, yerel depolama yok

class ProjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'projects';

  /// Proje oluştur — direkt Firestore + Admin bildirimi
  Future<String> createProject(ProjectModel project) async {
    final docRef = _firestore.collection(_collection).doc();
    final data = project.toMap();
    data['id'] = docRef.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.set(data);

    // Admin ve Moderatörlere bildirim gönder
    if (project.status == ProjectStatus.active ||
        project.status == ProjectStatus.casting) {
      try {
        final notifService = NotificationService();
        final title = 'Yeni Proje: ${project.title}';
        final body =
            '${project.employerName} tarafından yeni bir ${project.projectType ?? "proje"} oluşturuldu. '
            '${project.roles.length} rol mevcut.';

        await notifService.sendBulkNotification(
          title: title,
          body: body,
          type: NotificationType.newProject,
          target: NotificationTarget.admins,
          senderId: project.employerId,
          senderName: project.employerName,
          projectId: docRef.id,
          data: {'projectId': docRef.id},
        );

        await notifService.sendBulkNotification(
          title: title,
          body: body,
          type: NotificationType.newProject,
          target: NotificationTarget.moderators,
          senderId: project.employerId,
          senderName: project.employerName,
          projectId: docRef.id,
          data: {'projectId': docRef.id},
        );

        debugPrint('✅ [ProjectService] Admin/Moderatör bildirimleri gönderildi.');
      } catch (e) {
        debugPrint('⚠️ [ProjectService.createProject] Notification error: $e');
      }
    }

    return docRef.id;
  }

  /// Proje güncelle — direkt Firestore
  Future<void> updateProject(ProjectModel project) async {
    if (project.id.isEmpty) throw Exception('Proje ID boş olamaz');
    final data = project.toMap();
    // Firestore serverTimestamp ile updatedAt
    data['updatedAt'] = FieldValue.serverTimestamp();
    // createdAt'i korumak için server timestamp'i ekleme
    data.remove('createdAt'); // mevcut createdAt'i değiştirme
    await _firestore.collection(_collection).doc(project.id).update(data);
  }

  /// Proje durumunu güncelle — direkt Firestore
  Future<void> updateStatus(String projectId, ProjectStatus status) async {
    await _firestore.collection(_collection).doc(projectId).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Proje sil — direkt Firestore ve temizlik
  Future<void> deleteProject(String projectId) async {
    // 1. Proje belgesini sil
    await _firestore.collection(_collection).doc(projectId).delete();

    // 2. Projeye ait tüm bildirimleri sil
    final notificationsQuery = await _firestore
        .collection('notifications')
        .where('projectId', isEqualTo: projectId)
        .get();

    final batch = _firestore.batch();
    for (var doc in notificationsQuery.docs) {
      batch.delete(doc.reference);
    }

    // 3. Projeye ait onaylanmış (approved) olmayan tüm audition'ları sil
    final auditionsQuery = await _firestore
        .collection('auditions')
        .where('projectId', isEqualTo: projectId)
        .get();

    for (var doc in auditionsQuery.docs) {
      final status = doc.data()['status'] as String?;
      if (status != 'approved') {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  /// Tek proje getir — direkt Firestore
  Future<ProjectModel?> getProject(String projectId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(projectId).get();
      if (!doc.exists) return null;
      return ProjectModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('⚠️ [ProjectService.getProject] Error: $e');
      return null;
    }
  }

  /// İş verenin projelerini getir — Firestore (index gerektirmez)
  Future<List<ProjectModel>> getProjectsByEmployer(String employerId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('employerId', isEqualTo: employerId)
          .get();

      final list = snapshot.docs
          .map((doc) => ProjectModel.fromMap(doc.data(), doc.id))
          .toList();
      // Client-side sıralama
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('⚠️ [ProjectService.getProjectsByEmployer] Error: $e');
      return [];
    }
  }

  /// Casting sorumlusunun (moderatör) atandığı projeleri getir — Firestore (index gerektirmez)
  Future<List<ProjectModel>> getProjectsByCoordinator(String coordinatorId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('coordinatorId', isEqualTo: coordinatorId)
          .get();

      final list = snapshot.docs
          .map((doc) => ProjectModel.fromMap(doc.data(), doc.id))
          .toList();
      // Client-side sıralama
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('⚠️ [ProjectService.getProjectsByCoordinator] Error: $e');
      return [];
    }
  }

  /// Tüm projeleri getir (Admin/Mod için) — Firestore (index gerektirmez)
  Future<List<ProjectModel>> getAllProjects({
    ProjectStatus? status,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(_collection).limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }

      final snapshot = await query.get();
      final list = snapshot.docs
          .map((doc) => ProjectModel.fromMap(doc.data(), doc.id))
          .toList();
      // Client-side sıralama
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('⚠️ [ProjectService.getAllProjects] Error: $e');
      return [];
    }
  }

  /// Aktif projeleri getir (Oyuncular ve Yönetmenler için) — Firestore (index gerektirmez)
  Future<List<ProjectModel>> getActiveProjects({int limit = 30}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', whereIn: ['active', 'casting'])
          .limit(limit)
          .get();

      final list = snapshot.docs
          .map((doc) => ProjectModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('⚠️ [ProjectService.getActiveProjects] Error: $e');
      return [];
    }
  }

  /// Proje stream'i (gerçek zamanlı) — Firestore
  Stream<ProjectModel?> streamProject(String projectId) {
    return _firestore
        .collection(_collection)
        .doc(projectId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return ProjectModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// İş veren proje stream'i — Firestore (index gerektirmez)
  Stream<List<ProjectModel>> streamEmployerProjects(String employerId) {
    return _firestore
        .collection(_collection)
        .where('employerId', isEqualTo: employerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ProjectModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Tüm projeler stream'i (Admin/Mod) — Firestore (index gerektirmez)
  Stream<List<ProjectModel>> streamAllProjects({ProjectStatus? status}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ProjectModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
