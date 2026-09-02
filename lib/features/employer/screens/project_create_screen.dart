import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/models/user_model.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/features/employer/providers/project_provider.dart';
import 'package:castelle/features/actor/widgets/skills_input_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Castelle - Proje Oluşturma / Düzenleme Ekranı

class ProjectCreateScreen extends StatefulWidget {
  final ProjectModel? existingProject; // null ise yeni proje

  const ProjectCreateScreen({super.key, this.existingProject});

  @override
  State<ProjectCreateScreen> createState() => _ProjectCreateScreenState();
}

class _ProjectCreateScreenState extends State<ProjectCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  late TextEditingController _shootDateController;
  late TextEditingController _shootDurationController;
  late TextEditingController _mediaController;
  late TextEditingController _scenarioController;
  bool _cashPayment = false;
  bool _isPrivate = false;

  String? _projectType;
  DateTime? _deadline;
  final List<_RoleFormData> _roles = [];
  // Project media & budget
  final ImagePicker _picker = ImagePicker();
  final List<String> _localImagePaths = [];
  final List<String> _uploadedImageUrls = [];
  String? _localVideoPath;
  String? _uploadedVideoUrl;
  bool _uploadingMedia = false;
  double _uploadProgress = 0.0;

  // Primary image
  String? _primaryImageUrlOrPath;

  // Casting coordinator (moderator) fields
  String? _coordinatorId;
  String? _coordinatorName;
  String? _coordinatorPhone;
  String? _oldCoordinatorId; // moderatör değişimini takip eder
  late TextEditingController _coordinatorSearchController;
  List<UserModel> _allModerators = [];
  List<UserModel> _filteredModerators = [];
  bool _loadingModerators = false;
  bool get isEditing => widget.existingProject != null;

  List<dynamic> _locationSuggestions = [];
  bool _isLoadingSuggestions = false;
  bool _isSelectingSuggestion = false;
  Timer? _debounceTimer;
  late String _projectId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _locationController = TextEditingController();
    _coordinatorSearchController = TextEditingController();
    _shootDateController = TextEditingController();
    _shootDurationController = TextEditingController();
    _mediaController = TextEditingController();
    _scenarioController = TextEditingController();

    _projectId = widget.existingProject?.id.isNotEmpty == true
        ? widget.existingProject!.id
        : FirebaseFirestore.instance.collection('projects').doc().id;

    if (isEditing) {
      _loadExisting();
    } else {
      // Varsayılan olarak 1 boş rol ekle
      _roles.add(_RoleFormData());
    }
    _locationController.addListener(_onLocationChanged);
    _fetchModerators();
  }

  Future<void> _fetchModerators() async {
    setState(() => _loadingModerators = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: UserRole.moderator.value)
          .where('isActive', isEqualTo: true)
          .get();
      
      final list = snap.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
      setState(() {
        _allModerators = list;
        _loadingModerators = false;
      });
    } catch (e) {
      debugPrint('Error fetching moderators: $e');
      setState(() => _loadingModerators = false);
    }
  }
  Future<void> _sendProjectPublishNotifications(
      String projectId, String projectTitle) async {
    try {
      final sender = context.read<AuthProvider>().user;
      final senderName = sender?.fullName ?? 'Admin';
      final senderId = sender?.uid;

      final batch = FirebaseFirestore.instance.batch();
      final List<String> recipients = [];

      // Get Admins
      try {
        final adminDocs = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .where('isActive', isEqualTo: true)
            .get();
        for (final doc in adminDocs.docs) {
          recipients.add(doc.id);
        }
      } catch (_) {}

      // Get Moderators
      try {
        final moderatorDocs = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'moderator')
            .where('isActive', isEqualTo: true)
            .get();
        for (final doc in moderatorDocs.docs) {
          if (!recipients.contains(doc.id)) {
            recipients.add(doc.id);
          }
        }
      } catch (_) {}

      for (final recipientId in recipients) {
        final docRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(docRef, {
          'recipientId': recipientId,
          'userId': recipientId,
          'title': 'Yeni Proje Yayınlandı: $projectTitle',
          'body': '$senderName tarafından yeni bir casting projesi yayınlandı. 🎬',
          'type': 'project_update',
          'isRead': false,
          'senderId': senderId,
          'senderName': senderName,
          'projectId': projectId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (_) {}
  }

  Future<void> _sendProjectDeadlineUpdatedNotifications(String projectId, String projectTitle) async {
    try {
      final sender = context.read<AuthProvider>().user;
      final senderName = sender?.fullName ?? 'Admin';
      final senderId = sender?.uid;

      // Find all unique recipient IDs from 'notifications' where projectId == projectId and type == 'casting_invite'
      final inviteDocs = await FirebaseFirestore.instance
          .collection('notifications')
          .where('projectId', isEqualTo: projectId)
          .where('type', isEqualTo: 'casting_invite')
          .get();

      final Set<String> recipientIds = {};
      for (final doc in inviteDocs.docs) {
        final rId = doc.data()['recipientId'] as String?;
        if (rId != null && rId.isNotEmpty) {
          recipientIds.add(rId);
        }
      }

      if (recipientIds.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final rId in recipientIds) {
        final docRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(docRef, {
          'recipientId': rId,
          'userId': rId,
          'title': 'Başvuru Süresi Güncellendi: $projectTitle',
          'body': 'Projenin son başvuru tarihi güncellendi. Audition videonuzu tekrar gönderebilirsiniz. 🎬',
          'type': 'project_update',
          'isRead': false,
          'senderId': senderId,
          'senderName': senderName,
          'projectId': projectId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error sending deadline updated notifications: $e');
    }
  }

  /// Moderatöre proje atama bildirimi gönder
  Future<void> _sendModeratorAssignmentNotification(
      String projectId, String projectTitle, String moderatorId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'moderator_assigned',
        'recipientId': moderatorId,
        'userId': moderatorId,
        'title': 'Projeye Atandınız 🎬',
        'body': '"$projectTitle" projesinin Casting Sorumlusu olarak atandınız.',
        'projectId': projectId,
        'projectTitle': projectTitle,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ [Notification] Moderatör atama bildirimi gönderildi: $moderatorId');
    } catch (e) {
      debugPrint('⚠️ [Notification] Moderatör bildirim hatası: $e');
    }
  }

  void _loadExisting() {
    final p = widget.existingProject!;
    _titleController.text = p.title;
    _descController.text = p.description ?? '';
    _locationController.text = p.location ?? '';
    _projectType = p.projectType;
    _deadline = p.deadline;
    _uploadedImageUrls.addAll(p.galleryImageUrls);
    _uploadedVideoUrl = p.sampleVideoUrl;

    _coordinatorId = p.coordinatorId;
    _oldCoordinatorId = p.coordinatorId; // eski değeri sakla
    _coordinatorName = p.coordinatorName;
    _coordinatorPhone = p.coordinatorPhone;
    if (_coordinatorName != null) {
      _coordinatorSearchController.text = _coordinatorName!;
    }

    _primaryImageUrlOrPath = p.primaryImageUrl;
    if (_primaryImageUrlOrPath == null && _uploadedImageUrls.isNotEmpty) {
      _primaryImageUrlOrPath = _uploadedImageUrls.first;
    }

    _shootDateController.text = p.shootDate ?? '';
    _shootDurationController.text = p.shootDuration ?? '';
    _mediaController.text = p.media ?? '';
    _scenarioController.text = p.scenario ?? '';
    _cashPayment = p.cashPayment;
    _isPrivate = p.isPrivate;

    for (final role in p.roles) {
      _roles.add(_RoleFormData.fromProjectRole(role));
    }
    if (_roles.isEmpty) {
      _roles.add(_RoleFormData());
    }
  }

  @override
  void dispose() {
    _locationController.removeListener(_onLocationChanged);
    _debounceTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _coordinatorSearchController.dispose();
    _shootDateController.dispose();
    _shootDurationController.dispose();
    _mediaController.dispose();
    _scenarioController.dispose();
    for (final role in _roles) {
      role.dispose();
    }
    super.dispose();
  }
  Future<bool> _uploadMediaFiles(String projectId) async {
    setState(() {
      _uploadingMedia = true;
      _uploadProgress = 0.1;
    });

    try {
      final storage = FirebaseStorage.instance;

      // 1. Upload local images
      String? uploadedPrimaryUrl;
      for (int i = 0; i < _localImagePaths.length; i++) {
        final path = _localImagePaths[i];
        final ref = storage.ref().child('projects/$projectId/gallery/image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        final uploadTask = ref.putFile(File(path));
        
        await uploadTask.whenComplete(() {});
        final url = await ref.getDownloadURL();
        _uploadedImageUrls.add(url);

        if (path == _primaryImageUrlOrPath) {
          uploadedPrimaryUrl = url;
        }

        setState(() {
          _uploadProgress = 0.1 + (0.5 * (i + 1) / _localImagePaths.length);
        });
      }
      _localImagePaths.clear();

      if (uploadedPrimaryUrl != null) {
        _primaryImageUrlOrPath = uploadedPrimaryUrl;
      }

      // 2. Upload local video
      if (_localVideoPath != null) {
        final ref = storage.ref().child('projects/$projectId/sample_video.mp4');
        final uploadTask = ref.putFile(File(_localVideoPath!));
        
        await uploadTask.whenComplete(() {});
        final url = await ref.getDownloadURL();
        _uploadedVideoUrl = url;
        _localVideoPath = null;
      }

      setState(() {
        _uploadProgress = 1.0;
        _uploadingMedia = false;
      });
      return true;
    } catch (e) {
      debugPrint('Error uploading project media: $e');
      setState(() => _uploadingMedia = false);
      return false;
    }
  }

  Future<void> _pickProjectImage() async {
    if (_uploadedImageUrls.length + _localImagePaths.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En fazla 10 adet görsel ekleyebilirsiniz.'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file != null) {
        setState(() {
          _localImagePaths.add(file.path);
          _primaryImageUrlOrPath ??= file.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking project image: $e');
    }
  }

  Future<void> _pickProjectVideo() async {
    try {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          title: Row(
            children: [
              const Icon(Icons.videocam, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text('Yatay Video Kuralı', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Lütfen yükleyeceğiniz örnek videonun YATAY (landscape) olduğundan emin olun.\nDikey videolar yüklenemez.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('Devam Et'),
            ),
          ],
        ),
      ) ?? false;

      if (!proceed) return;

      final file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 45));
      if (file != null) {
        // Enforce landscape check
        final controller = VideoPlayerController.file(File(file.path));
        await controller.initialize();
        final size = controller.value.size;
        final isLandscape = size.width > size.height;
        await controller.dispose();

        if (!isLandscape) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              title: const Text('Hata: Dikey Video'),
              content: const Text('Yüklemeye çalıştığınız video dikey. Lütfen sadece yatay (landscape) çekilmiş videolar yükleyin.'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          );
          return;
        }

        setState(() {
          _localVideoPath = file.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking project video: $e');
    }
  }

  void _onLocationChanged() {
    if (_isSelectingSuggestion) {
      _isSelectingSuggestion = false;
      return;
    }

    final query = _locationController.text;
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchLocationSuggestions(query);
    });
  }

  Future<void> _fetchLocationSuggestions(String query) async {
    if (query.trim().isEmpty || query.length < 3) {
      setState(() {
        _locationSuggestions = [];
      });
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5&addressdetails=1&accept-language=tr');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'CastelleApp/1.0.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _locationSuggestions = data;
            _isLoadingSuggestions = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingSuggestions = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching location suggestions: $e');
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _handleSave({bool isPublish = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final projectProvider = context.read<ProjectProvider>();

    final projectId = _projectId;

    if (_localImagePaths.isNotEmpty || _localVideoPath != null) {
      final ok = await _uploadMediaFiles(projectId);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dosya yüklemeleri başarısız oldu.'), backgroundColor: AppTheme.error),
          );
        }
        return;
      }
    }

    // Rolleri dönüştür
    final projectRoles = _roles.map((r) => r.toProjectRole()).toList();

    final newStatus = isPublish
        ? ProjectStatus.active
        : (widget.existingProject?.status ?? ProjectStatus.draft);

    String? finalPrimaryImageUrl;
    if (_primaryImageUrlOrPath != null && _primaryImageUrlOrPath!.startsWith('http')) {
      finalPrimaryImageUrl = _primaryImageUrlOrPath;
    } else if (_uploadedImageUrls.isNotEmpty) {
      finalPrimaryImageUrl = _uploadedImageUrls.first;
    }

    final project = ProjectModel(
      id: projectId,
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      employerId: authProvider.user!.uid,
      employerName: authProvider.user!.fullName,
      status: newStatus,
      roles: projectRoles,
      deadline: _deadline,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      projectType: _projectType,
      directorId: widget.existingProject?.directorId,
      directorName: widget.existingProject?.directorName,
      coordinatorId: _coordinatorId,
      coordinatorName: _coordinatorName,
      coordinatorPhone: _coordinatorPhone,
      primaryImageUrl: finalPrimaryImageUrl,
      createdAt: widget.existingProject?.createdAt ?? DateTime.now(),
      galleryImageUrls: _uploadedImageUrls,
      sampleVideoUrl: _uploadedVideoUrl,
      budget: widget.existingProject?.budget,
      shootDate: _shootDateController.text.trim().isEmpty ? null : _shootDateController.text.trim(),
      shootDuration: _shootDurationController.text.trim().isEmpty ? null : _shootDurationController.text.trim(),
      media: _mediaController.text.trim().isEmpty ? null : _mediaController.text.trim(),
      cashPayment: _cashPayment,
      isPrivate: _isPrivate,
      scenario: _scenarioController.text.trim().isEmpty ? null : _scenarioController.text.trim(),
    );

    bool success;
    String? createdProjectId;
    if (isEditing) {
      final oldDeadline = widget.existingProject?.deadline;
      final newDeadline = project.deadline;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      bool oldWasPassed = false;
      if (oldDeadline != null) {
        final oldDeadlineDate = DateTime(oldDeadline.year, oldDeadline.month, oldDeadline.day);
        if (oldDeadlineDate.isBefore(today)) {
          oldWasPassed = true;
        }
      }

      bool newIsFuture = false;
      if (newDeadline != null) {
        final newDeadlineDate = DateTime(newDeadline.year, newDeadline.month, newDeadline.day);
        if (!newDeadlineDate.isBefore(today)) {
          newIsFuture = true;
        }
      }

      success = await projectProvider.updateProject(project);
      createdProjectId = project.id;

      if (success && oldWasPassed && newIsFuture) {
        await _sendProjectDeadlineUpdatedNotifications(createdProjectId, project.title);
      }
    } else {
      createdProjectId = await projectProvider.createProject(project);
      success = createdProjectId != null;
    }

    if (success && isPublish && createdProjectId != null) {
      await _sendProjectPublishNotifications(
        createdProjectId,
        project.title,
      );
    }

    // Moderatör atandıysa bildirim gönder
    if (success && createdProjectId != null && _coordinatorId != null) {
      final isNewAssignment = _oldCoordinatorId == null;
      final isChangedAssignment = _oldCoordinatorId != null && _oldCoordinatorId != _coordinatorId;
      if (isNewAssignment || isChangedAssignment) {
        await _sendModeratorAssignmentNotification(
          createdProjectId,
          project.title,
          _coordinatorId!,
        );
      }
    }

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPublish
              ? 'Proje başarıyla oluşturuldu! 🎉'
              : (isEditing ? 'Proje güncellendi!' : 'Proje taslak olarak kaydedildi!')),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(projectProvider.errorMessage ?? 'İşlem başarısız.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    if (currentUser != null && currentUser.role == UserRole.moderator) {
      final isNew = widget.existingProject == null;
      final permToCheck = isNew ? 'projeOlusturma' : 'duzenlemeYetkisi';
      if (!currentUser.hasModeratorPermission(permToCheck)) {
        return Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: AppBar(
            title: Text(isNew ? 'Yeni Proje' : 'Projeyi Düzenle'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                isNew 
                    ? 'Proje oluşturma yetkiniz bulunmamaktadır.'
                    : 'Proje düzenleme yetkiniz bulunmamaktadır.',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Projeyi Düzenle' : 'Yeni Proje'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: projectProvider.isLoading
                ? null
                : () => _handleSave(isPublish: false),
            child: projectProvider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  )
                : Text(
                    isEditing ? 'Güncelle' : 'Kaydet',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ══════════ PROJE BİLGİLERİ ══════════
              _buildSectionHeader('Proje Bilgileri', Icons.movie_outlined),
              const SizedBox(height: 16),

              // Başlık
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Proje Adı',
                  hintText: 'Örn: Kış Masalı - Uzun Metraj Film',
                  prefixIcon: Icon(Icons.title, size: 20),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Proje adı gerekli' : null,
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 16),

              // Proje türü
              _buildProjectTypeSelector()
                  .animate()
                  .fadeIn(delay: 150.ms),

              const SizedBox(height: 16),

              // Açıklama
              TextFormField(
                controller: _descController,
                maxLines: 3,
                maxLength: 1000,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Açıklama',
                  hintText: 'Projenin kısa özeti...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 44),
                    child: Icon(Icons.description, size: 20),
                  ),
                  counterStyle: GoogleFonts.inter(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 16),

              // Lokasyon
              TextFormField(
                controller: _locationController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Çekim Lokasyonu',
                  hintText: 'Örn: İstanbul, Kadıköy veya tam adres...',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                  suffixIcon: _isLoadingSuggestions
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accent,
                            ),
                          ),
                        )
                      : (_locationController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppTheme.textTertiary),
                              onPressed: () {
                                setState(() {
                                  _isSelectingSuggestion = true;
                                  _locationController.clear();
                                  _locationSuggestions = [];
                                });
                              },
                            )
                          : null),
                ),
              ).animate().fadeIn(delay: 250.ms),

              // Öneriler Listesi
              if (_locationSuggestions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.shadowSm,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _locationSuggestions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _locationSuggestions[index];
                      final displayName = item['display_name'] ?? '';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined, color: AppTheme.accent, size: 16),
                        title: Text(
                          displayName,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _isSelectingSuggestion = true;
                            _locationController.text = displayName;
                            _locationSuggestions = [];
                          });
                        },
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Son başvuru tarihi
              GestureDetector(
                onTap: _pickDeadline,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 20, color: AppTheme.primarySoft),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _deadline != null
                              ? 'Son Başvuru: ${_formatDate(_deadline!)}'
                              : 'Son Başvuru Tarihi Seç...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _deadline != null
                                ? AppTheme.textPrimary
                                : AppTheme.textTertiary,
                          ),
                        ),
                      ),
                      if (_deadline != null)
                        GestureDetector(
                          onTap: () => setState(() => _deadline = null),
                          child: const Icon(Icons.close,
                              size: 18, color: AppTheme.textTertiary),
                        ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 16),

              // Casting Sorumlusu
              _buildCoordinatorSelector().animate().fadeIn(delay: 310.ms),

              const SizedBox(height: 16),

              // Gizli Proje Toggle
              SwitchListTile(
                title: Text(
                  'Gizli Proje',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Bu proje genel listede gizlenir, sadece davet edilenler görebilir.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                ),
                value: _isPrivate,
                onChanged: (val) => setState(() => _isPrivate = val),
                activeColor: AppTheme.accent,
                contentPadding: EdgeInsets.zero,
              ).animate().fadeIn(delay: 315.ms),

              const SizedBox(height: 24),
              _buildSectionHeader('Ek Proje Detayları', Icons.info_outline),
              const SizedBox(height: 16),

              // Çekim Tarihi
              GestureDetector(
                onTap: _pickShootDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range,
                          size: 20, color: AppTheme.primarySoft),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _shootDateController.text.isNotEmpty
                              ? 'Çekim Tarihi: ${_shootDateController.text}'
                              : 'Çekim Tarihi Seç...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _shootDateController.text.isNotEmpty
                                ? AppTheme.textPrimary
                                : AppTheme.textTertiary,
                          ),
                        ),
                      ),
                      if (_shootDateController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _shootDateController.clear()),
                          child: const Icon(Icons.close,
                              size: 18, color: AppTheme.textTertiary),
                        ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 320.ms),

              const SizedBox(height: 16),

              // Çekim Süresi
              TextFormField(
                controller: _shootDurationController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Çekim Süresi',
                  hintText: 'Örn: 1 Gün veya 3 Hafta',
                  prefixIcon: Icon(Icons.timer_outlined, size: 20),
                ),
              ).animate().fadeIn(delay: 325.ms),

              const SizedBox(height: 16),

              // Mecra
              TextFormField(
                controller: _mediaController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Mecra',
                  hintText: 'Örn: TV + Dijital + SM (Tiktok+reels)',
                  prefixIcon: Icon(Icons.language, size: 20),
                ),
              ).animate().fadeIn(delay: 330.ms),

              const SizedBox(height: 16),

              // Peşin Ödeme Switch
              SwitchListTile(
                title: Text(
                  'Peşin Ödeme',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Hakediş ödemesi peşin olarak mı yapılacak?',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                ),
                value: _cashPayment,
                onChanged: (val) => setState(() => _cashPayment = val),
                activeColor: AppTheme.accent,
                contentPadding: EdgeInsets.zero,
              ).animate().fadeIn(delay: 335.ms),

              const SizedBox(height: 24),
              _buildSectionHeader('Senaryo & Metin', Icons.menu_book_outlined),
              const SizedBox(height: 12),
              Text(
                'Projeye ait senaryo veya audition metnini buraya ekleyebilirsiniz. Aşağıdaki butonları kullanarak metni kalın, eğik yapabilir veya liste ekleyebilirsiniz.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 16),

              // Formatting Toolbar for scenario rich text editor
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSm)),
                  border: Border.all(color: AppTheme.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.format_bold, size: 20, color: AppTheme.textSecondary),
                      tooltip: 'Kalın Yazı',
                      onPressed: () => _insertFormatting('**', '**'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_italic, size: 20, color: AppTheme.textSecondary),
                      tooltip: 'Eğik Yazı',
                      onPressed: () => _insertFormatting('*', '*'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_list_bulleted, size: 20, color: AppTheme.textSecondary),
                      tooltip: 'Madde İşareti',
                      onPressed: () => _insertFormatting('\n- ', ''),
                    ),
                  ],
                ),
              ),
              TextFormField(
                controller: _scenarioController,
                maxLines: 8,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Senaryoyu buraya yazın veya yapıştırın...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusSm)),
                  ),
                ),
              ).animate().fadeIn(delay: 340.ms),

              const SizedBox(height: 32),

              // ══════════ PROJE MEDYALARI ══════════
              _buildSectionHeader('Proje Medyaları', Icons.collections_outlined),
              const SizedBox(height: 16),
              _buildGallerySection().animate().fadeIn(delay: 325.ms),
              const SizedBox(height: 16),
              _buildVideoSection().animate().fadeIn(delay: 350.ms),
              if (_uploadingMedia) ...[
                const SizedBox(height: 16),
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: AppTheme.border,
                        color: AppTheme.accent,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Medyalar yükleniyor... %${(_uploadProgress * 100).toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // ══════════ ROLLER ══════════
              _buildSectionHeader(
                  'Casting Rolleri (${_roles.length})', Icons.group_outlined),
              const SizedBox(height: 6),
              Text(
                'Her proje için aradığınız rolleri ve gereksinimlerini tanımlayın.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 16),

              // Rol kartları
              ...List.generate(_roles.length, (index) {
                return _buildRoleCard(index)
                    .animate()
                    .fadeIn(delay: (350 + index * 50).ms);
              }),

              // Rol ekle butonu
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _roles.add(_RoleFormData());
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Yeni Rol Ekle'),
                ),
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 32),

              // Butonlar (Taslak Olarak Kaydet / Talep Topla)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: projectProvider.isLoading
                            ? null
                            : () => _handleSave(isPublish: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        child: Text(
                          'Taslak Olarak Kaydet',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: projectProvider.isLoading
                            ? null
                            : () => _handleSave(isPublish: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.textOnAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        child: projectProvider.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppTheme.textOnAccent,
                                ),
                              )
                            : Text(
                                'Proje Oluştur',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Proje Galerisi (${_uploadedImageUrls.length + _localImagePaths.length}/10)',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_uploadedImageUrls.length + _localImagePaths.length < 10)
              TextButton.icon(
                onPressed: _pickProjectImage,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: const Text('Görsel Ekle', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Görsellerden birine tıklayarak onu "Birincil Görsel" yapabilirsiniz.',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        if (_uploadedImageUrls.isEmpty && _localImagePaths.isEmpty)
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_outlined, color: AppTheme.textTertiary, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    'Henüz görsel eklenmedi',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _uploadedImageUrls.length + _localImagePaths.length,
              itemBuilder: (context, index) {
                final isUploaded = index < _uploadedImageUrls.length;
                final pathOrUrl = isUploaded
                    ? _uploadedImageUrls[index]
                    : _localImagePaths[index - _uploadedImageUrls.length];
                final isPrimary = pathOrUrl == _primaryImageUrlOrPath;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _primaryImageUrlOrPath = pathOrUrl;
                    });
                  },
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: isPrimary ? AppTheme.accent : AppTheme.border,
                        width: isPrimary ? 2.5 : 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd - 1),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          isUploaded
                              ? Image.network(pathOrUrl, fit: BoxFit.cover)
                              : Image.file(File(pathOrUrl), fit: BoxFit.cover),
                          // Birincil Badge
                          if (isPrimary)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.star, size: 9, color: Colors.white),
                                    SizedBox(width: 2),
                                    Text(
                                      'Birincil',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star_border,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          // Sil Butonu
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  final isDeletedPrimary = pathOrUrl == _primaryImageUrlOrPath;
                                  if (isUploaded) {
                                    _uploadedImageUrls.removeAt(index);
                                  } else {
                                    _localImagePaths.removeAt(index - _uploadedImageUrls.length);
                                  }
                                  if (isDeletedPrimary) {
                                    if (_uploadedImageUrls.isNotEmpty) {
                                      _primaryImageUrlOrPath = _uploadedImageUrls.first;
                                    } else if (_localImagePaths.isNotEmpty) {
                                      _primaryImageUrlOrPath = _localImagePaths.first;
                                    } else {
                                      _primaryImageUrlOrPath = null;
                                    }
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVideoSection() {
    final hasVideo = _uploadedVideoUrl != null || _localVideoPath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tanıtım / Örnek Video (Yatay)',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (!hasVideo)
          InkWell(
            onTap: _pickProjectVideo,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.video_call_outlined, color: AppTheme.accent, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Yatay Örnek Video Ekle',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Max 45 saniye. Yatay format zorunludur.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.video_file_outlined, color: AppTheme.accent, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _localVideoPath != null
                            ? 'Yeni seçilen video (Yüklenecek)'
                            : 'Yüklenmiş video mevcut',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (_localVideoPath != null)
                        Text(
                          _localVideoPath!.split(Platform.pathSeparator).last,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  onPressed: () {
                    setState(() {
                      _localVideoPath = null;
                      _uploadedVideoUrl = null;
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proje Türü',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ProjectTypes.all.map((type) {
            final isSelected = _projectType == type['value'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _projectType = isSelected ? null : type['value'];
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : AppTheme.surfaceCard,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color:
                        isSelected ? AppTheme.accent : AppTheme.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      type['icon']!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type['label']!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _insertFormatting(String prefix, String suffix) {
    final text = _scenarioController.text;
    final selection = _scenarioController.selection;
    
    if (selection.start < 0 || selection.end < 0) {
      _scenarioController.text = text + prefix + suffix;
      return;
    }

    final selectedText = selection.textInside(text);
    final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
    
    _scenarioController.text = newText;
    _scenarioController.selection = TextSelection(
      baseOffset: selection.start + prefix.length,
      extentOffset: selection.start + prefix.length + selectedText.length,
    );
  }

  Widget _buildRoleCard(int index) {
    final role = _roles[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  role.nameController.text.isEmpty
                      ? 'Rol ${index + 1}'
                      : role.nameController.text,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (_roles.length > 1)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _roles[index].dispose();
                      _roles.removeAt(index);
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 14, color: AppTheme.error),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Rol adı
          TextFormField(
            controller: role.nameController,
            style: const TextStyle(color: AppTheme.textPrimary),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Rol Adı',
              hintText: 'Örn: Ana Karakter, Figüran',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Rol adı gerekli' : null,
          ),

          const SizedBox(height: 12),

          // Açıklama
          TextFormField(
            controller: role.descController,
            maxLines: 2,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Rol Açıklaması (opsiyonel)',
              hintText: 'Bu rolde aranan özellikler...',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 12),

          // Audition Notları
          TextFormField(
            controller: role.auditionNotesController,
            maxLines: 2,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Audition Notları (opsiyonel)',
              hintText: 'Oyuncunun audition çekerken dikkat etmesi gereken detaylar...',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 12),

          // Rol Bütçesi
          TextFormField(
            controller: role.budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Rol Bütçesi (₺)',
              hintText: 'Örn: 50000',
              prefixIcon: Icon(Icons.monetization_on_outlined, size: 20),
            ),
          ),

          const SizedBox(height: 12),

          // Audition Metni (Prompter için)
          TextFormField(
            controller: role.auditionScriptController,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Audition Metni (Prompter için)',
              hintText: 'Oyuncunun ön kamerayla kayıt yaparken okuyacağı metin...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.text_snippet_outlined, size: 20),
            ),
          ),

          const SizedBox(height: 12),

          // ═══ Audition Arka Plan Sesi ═══
          _buildAudioPickerSection(index, role),

          const SizedBox(height: 12),

          // Yaş + Kota
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: role.ageMinController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Min Yaş',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: role.ageMaxController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Max Yaş',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: role.quotaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Kota',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Boy (cm) Min - Max
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: role.heightMinController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Min Boy (cm)',
                    hintText: 'Örn: 165',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: role.heightMaxController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Max Boy (cm)',
                    hintText: 'Örn: 175',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Şehir & Görünüm
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: role.cityController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Aranan Şehir',
                    hintText: 'Örn: İstanbul',
                    prefixIcon: Icon(Icons.location_city, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: role.appearanceController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Görünüm / Saç',
                    hintText: 'Örn: Esmer, Sarışın',
                    prefixIcon: Icon(Icons.face, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Cinsiyet
          Row(
            children: [
              Text(
                'Cinsiyet: ',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              _buildGenderChip('Farketmez', null, role),
              _buildGenderChip('Erkek', 'male', role),
              _buildGenderChip('Kadın', 'female', role),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Aranan Yetenekler',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SkillsInputWidget(
            skills: role.requiredSkills,
            onSkillsChanged: (updatedSkills) {
              setState(() {
                role.requiredSkills = updatedSkills;
              });
            },
            maxSkills: 15,
          ),
          const SizedBox(height: 14),
          Text(
            'Aranan Yabancı Diller',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SkillsInputWidget(
            skills: role.requiredLanguages,
            onSkillsChanged: (updatedLangs) {
              setState(() {
                role.requiredLanguages = updatedLangs;
              });
            },
            maxSkills: 10,
          ),
          const SizedBox(height: 14),
          Text(
            'Aranan Hobiler & Özel Beceriler',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SkillsInputWidget(
            skills: role.requiredHobbies,
            onSkillsChanged: (updatedHobbies) {
              setState(() {
                role.requiredHobbies = updatedHobbies;
              });
            },
            maxSkills: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Casting Sorumlusu (Moderatör)',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _coordinatorSearchController,
          style: const TextStyle(color: AppTheme.textPrimary),
          onChanged: (val) {
            setState(() {
              if (val.trim().isEmpty) {
                _filteredModerators = [];
              } else {
                _filteredModerators = _allModerators
                    .where((m) => m.fullName
                        .toLowerCase()
                        .contains(val.toLowerCase()))
                    .toList();
              }
            });
          },
          decoration: InputDecoration(
            hintText: 'Casting sorumlusu arayın...',
            prefixIcon: const Icon(Icons.person_search, size: 20),
            suffixIcon: _coordinatorId != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _coordinatorId = null;
                        _coordinatorName = null;
                        _coordinatorPhone = null;
                        _coordinatorSearchController.clear();
                        _filteredModerators = [];
                      });
                    },
                  )
                : null,
          ),
        ),
        if (_loadingModerators) ...[
          const SizedBox(height: 6),
          const LinearProgressIndicator(
            color: AppTheme.accent,
            backgroundColor: Colors.transparent,
            minHeight: 2,
          ),
        ],
        if (_filteredModerators.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border, width: 0.5),
              boxShadow: AppTheme.shadowSm,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _filteredModerators.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final mod = _filteredModerators[index];
                return ListTile(
                  title: Text(
                    mod.fullName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    mod.email,
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                  ),
                  onTap: () {
                    setState(() {
                      _coordinatorId = mod.uid;
                      _coordinatorName = mod.fullName;
                      _coordinatorPhone = mod.phone;
                      _coordinatorSearchController.text = mod.fullName;
                      _filteredModerators = [];
                    });
                  },
                );
              },
            ),
          ),
        ],
        if (_coordinatorId != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_ind_outlined, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Atanan Sorumlu: $_coordinatorName (${_coordinatorPhone?.isNotEmpty == true ? _coordinatorPhone : "Telefon Yok"})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAudioPickerSection(int roleIndex, _RoleFormData role) {
    final hasAudio = role.backgroundAudioUrl != null && role.backgroundAudioUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.music_note, size: 14, color: AppTheme.accent),
            const SizedBox(width: 6),
            Text(
              'Audition Arka Plan Sesi',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                'opsiyonel',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.info,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Oyuncu kayıt başlatınca bu ses otomatik çalar ve çekilen videoya işlenir.',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: AppTheme.textTertiary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        if (!hasAudio)
          InkWell(
            onTap: () => _pickRoleAudio(roleIndex, role),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.25),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_file, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Ses Dosyası Seç (MP3, M4A, WAV)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: AppTheme.success.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.audio_file, color: AppTheme.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    role.backgroundAudioUrl!.contains('/')
                        ? role.backgroundAudioUrl!.split('/').last.split('?').first
                        : 'Ses dosyası hazır',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.error, size: 18),
                  onPressed: () {
                    setState(() {
                      role.backgroundAudioUrl = null;
                    });
                  },
                  tooltip: 'Sesi Kaldır',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pickRoleAudio(int roleIndex, _RoleFormData role) async {
    // context'i await'ten önce al
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
    );

    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    final file = File(filePath);

    // Yükleniyor göster
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Ses dosyası yükleniyor...'),
          ],
        ),
        duration: Duration(seconds: 60),
      ),
    );
    try {
      final uploadTask = FirebaseStorage.instance
          .ref('projects/$_projectId/gallery/audio_${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}')
          .putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _roles[roleIndex].backgroundAudioUrl = downloadUrl;
      });

      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ses dosyası yüklendi ✅'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [Audio Upload Error]: $e');
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Ses yükleme hatası: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildGenderChip(

      String label, String? value, _RoleFormData role) {
    final isSelected = role.gender == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => role.gender = value),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.12)
                : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? AppTheme.accent
                  : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickShootDate() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceCard,
              onSurface: AppTheme.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final startFormatted = _formatDateTurkish(picked.start);
      final endFormatted = _formatDateTurkish(picked.end);
      setState(() {
        _shootDateController.text = '$startFormatted - $endFormatted';
      });
    }
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceCard,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatDateTurkish(DateTime date) {
    final months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// Rol form data (Controller wrapper)
class _RoleFormData {
  final TextEditingController nameController;
  final TextEditingController descController;
  final TextEditingController auditionNotesController;
  final TextEditingController auditionScriptController;
  final TextEditingController ageMinController;
  final TextEditingController ageMaxController;
  final TextEditingController heightMinController;
  final TextEditingController heightMaxController;
  final TextEditingController cityController;
  final TextEditingController appearanceController;
  final TextEditingController quotaController;
  final TextEditingController budgetController;
  String? gender;
  List<String> requiredSkills;
  List<String> requiredLanguages;
  List<String> requiredHobbies;
  String? backgroundAudioUrl; // Arka plan ses URL'si (Firebase Storage)

  _RoleFormData()
      : nameController = TextEditingController(),
        descController = TextEditingController(),
        auditionNotesController = TextEditingController(),
        auditionScriptController = TextEditingController(),
        ageMinController = TextEditingController(),
        ageMaxController = TextEditingController(),
        heightMinController = TextEditingController(),
        heightMaxController = TextEditingController(),
        cityController = TextEditingController(),
        appearanceController = TextEditingController(),
        quotaController = TextEditingController(text: '1'),
        budgetController = TextEditingController(),
        requiredSkills = [],
        requiredLanguages = [],
        requiredHobbies = [],
        backgroundAudioUrl = null;

  _RoleFormData.fromProjectRole(ProjectRole role)
      : nameController = TextEditingController(text: role.roleName),
        descController = TextEditingController(text: role.description ?? ''),
        auditionNotesController =
            TextEditingController(text: role.auditionNotes ?? ''),
        auditionScriptController =
            TextEditingController(text: role.auditionScript ?? ''),
        ageMinController =
            TextEditingController(text: role.ageMin?.toString() ?? ''),
        ageMaxController =
            TextEditingController(text: role.ageMax?.toString() ?? ''),
        heightMinController =
            TextEditingController(text: role.heightMin?.toString() ?? ''),
        heightMaxController =
            TextEditingController(text: role.heightMax?.toString() ?? ''),
        cityController = TextEditingController(text: role.city ?? ''),
        appearanceController = TextEditingController(text: role.appearance ?? ''),
        quotaController =
            TextEditingController(text: role.quota.toString()),
        budgetController =
            TextEditingController(text: role.budget?.toString() ?? ''),
        gender = role.gender,
        requiredSkills = List.from(role.requiredSkills),
        requiredLanguages = List.from(role.requiredLanguages),
        requiredHobbies = List.from(role.requiredHobbies),
        backgroundAudioUrl = role.backgroundAudioUrl;

  ProjectRole toProjectRole() {
    return ProjectRole(
      roleName: nameController.text.trim(),
      description: descController.text.trim().isEmpty
          ? null
          : descController.text.trim(),
      auditionNotes: auditionNotesController.text.trim().isEmpty
          ? null
          : auditionNotesController.text.trim(),
      auditionScript: auditionScriptController.text.trim().isEmpty
          ? null
          : auditionScriptController.text.trim(),
      ageMin: int.tryParse(ageMinController.text),
      ageMax: int.tryParse(ageMaxController.text),
      heightMin: int.tryParse(heightMinController.text),
      heightMax: int.tryParse(heightMaxController.text),
      city: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
      appearance: appearanceController.text.trim().isEmpty ? null : appearanceController.text.trim(),
      gender: gender,
      requiredSkills: requiredSkills,
      requiredLanguages: requiredLanguages,
      requiredHobbies: requiredHobbies,
      quota: int.tryParse(quotaController.text) ?? 1,
      budget: double.tryParse(budgetController.text),
      backgroundAudioUrl: backgroundAudioUrl,
    );
  }

  void dispose() {
    nameController.dispose();
    descController.dispose();
    auditionNotesController.dispose();
    auditionScriptController.dispose();
    ageMinController.dispose();
    ageMaxController.dispose();
    heightMinController.dispose();
    heightMaxController.dispose();
    cityController.dispose();
    appearanceController.dispose();
    quotaController.dispose();
    budgetController.dispose();
  }
}
