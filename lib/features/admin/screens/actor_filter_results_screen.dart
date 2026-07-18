import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/widgets/actor_card.dart';
import 'package:castelle/features/admin/providers/actor_filter_provider.dart';
import 'package:castelle/features/admin/screens/actor_filter_screen.dart';
import 'package:castelle/features/admin/screens/actor_detail_screen.dart';

/// Castelle - Oyuncu Filtreleme Sonuçları
/// Admin/Moderatör oyuncu havuzu listeleme

class ActorFilterResultsScreen extends StatefulWidget {
  const ActorFilterResultsScreen({super.key});

  @override
  State<ActorFilterResultsScreen> createState() =>
      _ActorFilterResultsScreenState();
}

class _ActorFilterResultsScreenState extends State<ActorFilterResultsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // İlk yükleme
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isActorUser = context.read<AuthProvider>().isActor;
      final provider = context.read<ActorFilterProvider>();
      if (isActorUser) {
        provider.clearFilters();
      }
      if (provider.results.isEmpty) {
        provider.search();
      }
    });

    // Scroll ile daha fazla yükle
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<ActorFilterProvider>().search(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterProvider = context.watch<ActorFilterProvider>();
    final filter = filterProvider.filter;
    final results = filterProvider.results;
    final isLoading = filterProvider.isLoading;
    final isActor = context.watch<AuthProvider>().isActor;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Oyuncu Havuzu'),
        actions: [
          // Filtre butonu (Oyuncular filtreleme yapamaz)
          if (!isActor)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    final applied = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActorFilterScreen(),
                      ),
                    );
                    if (applied == true && mounted) {
                      setState(() {});
                    }
                  },
                ),
                if (filter.hasActiveFilters)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${filter.activeFilterCount}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textOnAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // İsim ile Arama Barı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (val) {
                final currentFilter = filterProvider.filter;
                filterProvider.updateFilter(
                  currentFilter.copyWith(
                    searchQuery: val.trim().isEmpty ? null : val.trim(),
                    clearSearchQuery: val.trim().isEmpty,
                  ),
                );
                filterProvider.search();
              },
              decoration: InputDecoration(
                hintText: 'Oyuncu adı ile ara...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textTertiary,
                ),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.surfaceCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide(
                    color: AppTheme.border.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: const BorderSide(
                    color: AppTheme.accent,
                    width: 1.5,
                  ),
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          // Aktif filtre göstergesi (Oyuncular için gösterilmez)
          if (!isActor && filter.hasActiveFilters)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.accent.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt,
                      size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${filter.activeFilterCount} aktif filtre · ${results.length} sonuç',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      filterProvider.clearFilters();
                      filterProvider.search();
                    },
                    child: Text(
                      'Temizle',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Sonuç listesi
          Expanded(
            child: _buildBody(results, isLoading, filterProvider, isActor),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    List<ActorProfileModel> results,
    bool isLoading,
    ActorFilterProvider provider,
    bool isActor,
  ) {
    if (isLoading && results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (provider.errorMessage != null && results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              'Hata oluştu',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => provider.search(),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search,
                size: 56,
                color: AppTheme.textTertiary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Sonuç bulunamadı',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isActor
                  ? 'Farklı bir isim aramayı deneyin'
                  : 'Filtreleri değiştirip tekrar deneyin',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
            if (!isActor) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ActorFilterScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Filtreleri Düzenle'),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: results.length + (provider.hasMore ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        if (index >= results.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2),
            ),
          );
        }

        final actor = results[index];
        final filter = provider.filter;
        int matchedSkillCount = 0;
        if (filter.skills.isNotEmpty) {
          final querySkills =
              filter.skills.map((s) => s.toLowerCase()).toSet();
          matchedSkillCount = actor.skills
              .where((s) => querySkills.contains(s.toLowerCase()))
              .length;
        }
        return ActorCard(
          actor: actor,
          index: index,
          showAdminInfo: !isActor,
          matchedSkillCount: matchedSkillCount,
          onTap: actor.isHidden
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bu kişi profilini gizledi.'),
                      duration: Duration(seconds: 2),
                      backgroundColor: AppTheme.textSecondary,
                    ),
                  )
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActorDetailScreen(actor: actor),
                    ),
                  ),
        );
      },
    );
  } // _buildBody end
} // _ActorFilterResultsScreenState end
