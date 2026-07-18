import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/employer/providers/project_provider.dart';
import 'package:castelle/features/employer/screens/project_create_screen.dart';
import 'package:castelle/features/employer/screens/project_detail_screen.dart';

/// Castelle - Proje Listesi Ekranı

class ProjectListScreen extends StatefulWidget {
  final bool isAdmin; // Admin tüm projeleri görür
  final bool isModerator; // Moderatör kendisine atanan projeleri görür

  const ProjectListScreen({super.key, this.isAdmin = false, this.isModerator = false});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjects();
    });
  }

  void _loadProjects() {
    final provider = context.read<ProjectProvider>();
    if (widget.isAdmin) {
      provider.loadAllProjects();
    } else if (widget.isModerator) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        provider.loadCoordinatorProjects(uid);
      }
    } else {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        provider.loadEmployerProjects(uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final projects = provider.projects;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.isAdmin
            ? 'Tüm Projeler'
            : (widget.isModerator ? 'Atanmış Projelerim' : 'Projelerim')),
        actions: widget.isModerator
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProjectCreateScreen(),
                      ),
                    );
                    if (created == true) {
                      _loadProjects();
                    }
                  },
                ),
              ],
      ),
      body: provider.isLoading && projects.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : projects.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async => _loadProjects(),
                  color: AppTheme.accent,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: projects.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildProjectCard(projects[index], index);
                    },
                  ),
                ),
      floatingActionButton: widget.isModerator
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProjectCreateScreen(),
                  ),
                );
                if (created == true) {
                  _loadProjects();
                }
              },
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.textOnAccent,
              icon: const Icon(Icons.add),
              label: Text(
                'Yeni Proje',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
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
            'Henüz proje yok',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isModerator
                ? 'Size atanmış herhangi bir proje bulunmuyor.'
                : 'İlk projenizi oluşturarak casting sürecini başlatın',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
          if (!widget.isModerator) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProjectCreateScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Proje Oluştur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.textOnAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectThumbnail(ProjectModel project) {
    Widget imageWidget;
    
    if (project.primaryImageUrl != null && project.primaryImageUrl!.isNotEmpty) {
      if (project.primaryImageUrl!.startsWith('http')) {
        imageWidget = Image.network(
          project.primaryImageUrl!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/images/ana-logo-siyah.png',
            fit: BoxFit.contain,
          ),
        );
      } else {
        imageWidget = Image.file(
          File(project.primaryImageUrl!),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/images/ana-logo-siyah.png',
            fit: BoxFit.contain,
          ),
        );
      }
    } else {
      imageWidget = Image.asset(
        'assets/images/ana-logo-siyah.png',
        fit: BoxFit.contain,
      );
    }

    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd - 4.5),
        child: imageWidget,
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(project: project),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProjectThumbnail(project),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst: Tür + Durum
                  Row(
                    children: [
                      // Proje türü chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          project.projectTypeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Durum
                      _buildStatusChip(project.status),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Başlık
                  Text(
                    project.title,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (project.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      project.description!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Alt bilgi satırı
                  Row(
                    children: [
                      // Roller
                      _buildInfoChip(
                          Icons.group, '${project.roles.length} rol'),

                      const SizedBox(width: 12),

                      // Toplam kota
                      _buildInfoChip(
                          Icons.people, '${project.totalQuota} kişi'),

                      if (project.location != null) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: _buildInfoChip(
                              Icons.location_on, project.location!),
                        ),
                      ],

                      const SizedBox(width: 8),

                      const Icon(Icons.chevron_right,
                          size: 18, color: AppTheme.textTertiary),
                    ],
                  ),

                  // Deadline
                  if (project.deadline != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: _isDeadlineSoon(project.deadline!)
                              ? AppTheme.warning
                              : AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Son başvuru: ${_formatDate(project.deadline!)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _isDeadlineSoon(project.deadline!)
                                ? AppTheme.warning
                                : AppTheme.textTertiary,
                            fontWeight: _isDeadlineSoon(project.deadline!)
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (50 + index * 40).ms).slideX(begin: 0.02);
  }

  Widget _buildStatusChip(ProjectStatus status) {
    final color = switch (status) {
      ProjectStatus.draft => AppTheme.textTertiary,
      ProjectStatus.active => AppTheme.success,
      ProjectStatus.casting => AppTheme.info,
      ProjectStatus.completed => AppTheme.accent,
      ProjectStatus.cancelled => AppTheme.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.displayName,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  bool _isDeadlineSoon(DateTime deadline) {
    return deadline.difference(DateTime.now()).inDays <= 3;
  }
}
