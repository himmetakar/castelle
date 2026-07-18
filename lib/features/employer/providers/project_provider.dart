import 'package:flutter/material.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/services/project_service.dart';

// Castelle - Project Provider
// Proje durum yönetimi — saf Firestore, yerel depolama yok

class ProjectProvider extends ChangeNotifier {
  final ProjectService _service = ProjectService();

  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<ProjectModel> get projects => _projects;
  ProjectModel? get selectedProject => _selectedProject;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // İstatistikler
  int get totalProjects => _projects.length;
  int get activeProjects =>
      _projects.where((p) => p.status == ProjectStatus.active).length;
  int get castingProjects =>
      _projects.where((p) => p.status == ProjectStatus.casting).length;
  int get completedProjects =>
      _projects.where((p) => p.status == ProjectStatus.completed).length;

  /// İş verenin projelerini yükle — Firestore
  Future<void> loadEmployerProjects(String employerId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _projects = await _service.getProjectsByEmployer(employerId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _projects = [];
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  /// Casting sorumlusunun (moderatör) projelerini yükle — Firestore
  Future<void> loadCoordinatorProjects(String coordinatorId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _projects = await _service.getProjectsByCoordinator(coordinatorId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _projects = [];
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  /// Tüm projeleri yükle (Admin) — Firestore
  Future<void> loadAllProjects({ProjectStatus? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _projects = await _service.getAllProjects(status: status);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _projects = [];
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  /// Proje oluştur — direkt Firestore
  Future<String?> createProject(ProjectModel project) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = await _service.createProject(project);
      final created = ProjectModel(
        id: id,
        title: project.title,
        description: project.description,
        employerId: project.employerId,
        employerName: project.employerName,
        status: project.status,
        roles: project.roles,
        deadline: project.deadline,
        location: project.location,
        projectType: project.projectType,
        directorId: project.directorId,
        directorName: project.directorName,
        createdAt: DateTime.now(),
      );
      _projects.insert(0, created);
      _isLoading = false;
      notifyListeners();
      return id;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Proje güncelle — direkt Firestore
  Future<bool> updateProject(ProjectModel project) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.updateProject(project);
      final index = _projects.indexWhere((p) => p.id == project.id);
      if (index != -1) {
        _projects[index] = project;
      }
      _selectedProject = project;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Proje durumunu güncelle — direkt Firestore
  Future<bool> updateStatus(String projectId, ProjectStatus status) async {
    try {
      await _service.updateStatus(projectId, status);
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = _projects[index].copyWith(status: status);
      }
      if (_selectedProject?.id == projectId) {
        _selectedProject = _selectedProject!.copyWith(status: status);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Proje sil — direkt Firestore
  Future<bool> deleteProject(String projectId) async {
    try {
      await _service.deleteProject(projectId);
      _projects.removeWhere((p) => p.id == projectId);
      if (_selectedProject?.id == projectId) {
        _selectedProject = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Seçili projeyi ayarla
  void selectProject(ProjectModel project) {
    _selectedProject = project;
    notifyListeners();
  }

  /// Hata temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
