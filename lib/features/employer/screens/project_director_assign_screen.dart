import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/employer/providers/project_provider.dart';

/// Castelle - Projeye Yönetmen Ata Ekranı
/// İş verenler ve Adminler için profilden erişilebilen, projelerin yönetmen atamalarını topluca yönetebildikleri premium ekran.

class ProjectDirectorAssignScreen extends StatefulWidget {
  const ProjectDirectorAssignScreen({super.key});

  @override
  State<ProjectDirectorAssignScreen> createState() => _ProjectDirectorAssignScreenState();
}

class _ProjectDirectorAssignScreenState extends State<ProjectDirectorAssignScreen> {
  List<Map<String, String>> _directors = [];
  bool _loadingDirectors = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await _loadDirectors();
    _loadProjects();
  }

  void _loadProjects() {
    final authProvider = context.read<AuthProvider>();
    final projectProvider = context.read<ProjectProvider>();
    if (authProvider.isAdmin) {
      projectProvider.loadAllProjects();
    }
  }

  Future<void> _loadDirectors() async {
    if (!mounted) return;
    setState(() => _loadingDirectors = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'director')
          .get();
      
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': (data['fullName'] ?? 'İsimsiz Yönetmen').toString(),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _directors = list;
          _loadingDirectors = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingDirectors = false);
      }
    }
  }

  Future<void> _assignDirector(ProjectModel project, String? directorId) async {
    final dName = directorId == null
        ? null
        : _directors.firstWhere((d) => d['id'] == directorId)['name'];

    try {
      // 1. Update Firestore
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(project.id)
          .update({
        'directorId': directorId,
        'directorName': dName,
      });

      // 2. Update Provider
      if (mounted) {
        final updated = project.copyWith(
          directorId: directorId,
          directorName: dName,
        );
        final messenger = ScaffoldMessenger.of(context);
        await context.read<ProjectProvider>().updateProject(updated);
        
        messenger.showSnackBar(
          SnackBar(
            content: Text(directorId == null 
                ? '${project.title} projesinden yönetmen ataması kaldırıldı.'
                : '${project.title} projesine $dName yönetmen olarak atandı! 🎬'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      // Fallback local update if firestore write fails in demo mode
      if (mounted) {
        final updated = project.copyWith(
          directorId: directorId,
          directorName: dName,
        );
        final messenger = ScaffoldMessenger.of(context);
        await context.read<ProjectProvider>().updateProject(updated);
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Yönetmen ataması güncellendi (Demo Modu).'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final projects = projectProvider.projects;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Yönetmen Ata'),
      ),
      body: _loadingDirectors || (projectProvider.isLoading && projects.isEmpty)
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : projects.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  color: AppTheme.accent,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: projects.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return _buildProjectAssignCard(projects[index], index);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_creation_outlined,
              size: 56,
              color: AppTheme.textTertiary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Atama yapılabilecek proje bulunmuyor',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Yönetmen atamak için önce bir proje oluşturmalısınız.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectAssignCard(ProjectModel project, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  project.projectTypeLabel,
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(project.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  project.status.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(project.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            project.title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          if (project.employerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'İş Veren: ${project.employerName}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
          const Divider(height: 24, color: AppTheme.border),
          Row(
            children: [
              const Icon(Icons.movie_creation_outlined, size: 18, color: AppTheme.textTertiary),
              const SizedBox(width: 8),
              Text(
                'Yönetmen:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Expanded(
                flex: 2,
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    initialValue: project.directorId,
                    isExpanded: true,
                    dropdownColor: AppTheme.surfaceCard,
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.accent),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: project.directorName != null
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                    ),
                    hint: const Text('Atanmadı'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Atanmadı (Boş bırak)'),
                      ),
                      ..._directors.map((d) => DropdownMenuItem<String>(
                            value: d['id'],
                            child: Text(
                              d['name']!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != project.directorId) {
                        _assignDirector(project, val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.02);
  }

  Color _statusColor(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.draft => AppTheme.textTertiary,
      ProjectStatus.active => AppTheme.success,
      ProjectStatus.casting => AppTheme.info,
      ProjectStatus.completed => AppTheme.accent,
      ProjectStatus.cancelled => AppTheme.error,
    };
  }
}
