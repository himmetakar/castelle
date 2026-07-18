import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/models/actor_filter_model.dart';
import 'package:castelle/features/admin/providers/actor_filter_provider.dart';
import 'package:castelle/features/actor/widgets/skills_input_widget.dart';

/// Castelle - Gelişmiş Oyuncu Filtreleme Ekranı
/// Admin ve Moderatör için çoklu kriter bazlı arama

class ActorFilterScreen extends StatefulWidget {
  const ActorFilterScreen({super.key});

  @override
  State<ActorFilterScreen> createState() => _ActorFilterScreenState();
}

class _ActorFilterScreenState extends State<ActorFilterScreen> {
  late TextEditingController _searchController;
  late TextEditingController _minAgeController;
  late TextEditingController _maxAgeController;
  late TextEditingController _minHeightController;
  late TextEditingController _maxHeightController;
  late TextEditingController _minWeightController;
  late TextEditingController _maxWeightController;
  late TextEditingController _cityController;

  Gender? _gender;
  EyeColor? _eyeColor;
  HairColor? _hairColor;
  String? _experienceLevel;
  List<String> _selectedSkills = [];
  bool _onlyComplete = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _minAgeController = TextEditingController();
    _maxAgeController = TextEditingController();
    _minHeightController = TextEditingController();
    _maxHeightController = TextEditingController();
    _minWeightController = TextEditingController();
    _maxWeightController = TextEditingController();
    _cityController = TextEditingController();

    // Mevcut filtreleri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentFilters();
    });
  }

  void _loadCurrentFilters() {
    final filterProvider = context.read<ActorFilterProvider>();
    final f = filterProvider.filter;

    _searchController.text = f.searchQuery ?? '';
    _minAgeController.text = f.minAge?.toString() ?? '';
    _maxAgeController.text = f.maxAge?.toString() ?? '';
    _minHeightController.text = f.minHeight?.toString() ?? '';
    _maxHeightController.text = f.maxHeight?.toString() ?? '';
    _minWeightController.text = f.minWeight?.toString() ?? '';
    _maxWeightController.text = f.maxWeight?.toString() ?? '';
    _cityController.text = f.city ?? '';

    setState(() {
      _gender = f.gender;
      _eyeColor = f.eyeColor;
      _hairColor = f.hairColor;
      _experienceLevel = f.experienceLevel;
      _selectedSkills = List.from(f.skills);
      _onlyComplete = f.onlyComplete;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    _minHeightController.dispose();
    _maxHeightController.dispose();
    _minWeightController.dispose();
    _maxWeightController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final filter = ActorFilterModel(
      searchQuery: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      minAge: int.tryParse(_minAgeController.text),
      maxAge: int.tryParse(_maxAgeController.text),
      gender: _gender,
      minHeight: int.tryParse(_minHeightController.text),
      maxHeight: int.tryParse(_maxHeightController.text),
      minWeight: int.tryParse(_minWeightController.text),
      maxWeight: int.tryParse(_maxWeightController.text),
      eyeColor: _eyeColor,
      hairColor: _hairColor,
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      experienceLevel: _experienceLevel,
      skills: _selectedSkills,
      onlyComplete: _onlyComplete,
    );

    final filterProvider = context.read<ActorFilterProvider>();
    filterProvider.updateFilter(filter);
    filterProvider.search();

    Navigator.pop(context, true);
  }

  void _clearAll() {
    setState(() {
      _searchController.clear();
      _minAgeController.clear();
      _maxAgeController.clear();
      _minHeightController.clear();
      _maxHeightController.clear();
      _minWeightController.clear();
      _maxWeightController.clear();
      _cityController.clear();
      _gender = null;
      _eyeColor = null;
      _hairColor = null;
      _experienceLevel = null;
      _selectedSkills = [];
      _onlyComplete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Oyuncu Filtrele'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _clearAll,
            child: Text(
              'Temizle',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ══════════ ARAMA ══════════
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'İsim veya e-posta ara...',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                  ).animate().fadeIn(duration: 200.ms),

                  const SizedBox(height: 24),

                  // ══════════ CİNSİYET ══════════
                  _buildSectionTitle('Cinsiyet'),
                  const SizedBox(height: 10),
                  _buildChipGroup<Gender>(
                    items: Gender.values,
                    selected: _gender,
                    labelOf: (g) => g.displayName,
                    onSelected: (g) => setState(() {
                      _gender = _gender == g ? null : g;
                    }),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 24),

                  // ══════════ YAŞ ARALIĞI ══════════
                  _buildSectionTitle('Yaş Aralığı'),
                  const SizedBox(height: 10),
                  _buildRangeRow(
                    minController: _minAgeController,
                    maxController: _maxAgeController,
                    minHint: 'Min',
                    maxHint: 'Max',
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 24),

                  // ══════════ BOY ARALIĞI ══════════
                  _buildSectionTitle('Boy (cm)'),
                  const SizedBox(height: 10),
                  _buildRangeRow(
                    minController: _minHeightController,
                    maxController: _maxHeightController,
                    minHint: 'Min cm',
                    maxHint: 'Max cm',
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 24),

                  // ══════════ KİLO ARALIĞI ══════════
                  _buildSectionTitle('Kilo (kg)'),
                  const SizedBox(height: 10),
                  _buildRangeRow(
                    minController: _minWeightController,
                    maxController: _maxWeightController,
                    minHint: 'Min kg',
                    maxHint: 'Max kg',
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 24),

                  // ══════════ GÖZ RENGİ ══════════
                  _buildSectionTitle('Göz Rengi'),
                  const SizedBox(height: 10),
                  _buildChipGroup<EyeColor>(
                    items: EyeColor.values,
                    selected: _eyeColor,
                    labelOf: (e) => e.displayName,
                    onSelected: (e) => setState(() {
                      _eyeColor = _eyeColor == e ? null : e;
                    }),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 24),

                  // ══════════ SAÇ RENGİ ══════════
                  _buildSectionTitle('Saç Rengi'),
                  const SizedBox(height: 10),
                  _buildChipGroup<HairColor>(
                    items: HairColor.values,
                    selected: _hairColor,
                    labelOf: (h) => h.displayName,
                    onSelected: (h) => setState(() {
                      _hairColor = _hairColor == h ? null : h;
                    }),
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 24),

                  // ══════════ ŞEHİR ══════════
                  _buildSectionTitle('Şehir'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cityController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Şehir adı...',
                      prefixIcon: Icon(Icons.location_city, size: 20),
                    ),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 24),

                  // ══════════ DENEYİM ══════════
                  _buildSectionTitle('Deneyim Seviyesi'),
                  const SizedBox(height: 10),
                  _buildChipGroup<String>(
                    items: const [
                      'beginner',
                      'intermediate',
                      'advanced',
                      'professional'
                    ],
                    selected: _experienceLevel,
                    labelOf: (e) => _experienceLevelLabel(e),
                    onSelected: (e) => setState(() {
                      _experienceLevel = _experienceLevel == e ? null : e;
                    }),
                  ).animate().fadeIn(delay: 450.ms),

                  const SizedBox(height: 24),

                  // ══════════ YETENEKLER ══════════
                  _buildSectionTitle('Yetenekler'),
                  const SizedBox(height: 4),
                  Text(
                    'Seçtiğin tüm yeteneklere sahip oyuncular listelenir (AND mantığı)',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 12),
                  SkillsInputWidget(
                    skills: _selectedSkills,
                    onSkillsChanged: (updatedSkills) {
                      setState(() {
                        _selectedSkills = updatedSkills;
                      });
                    },
                    maxSkills: 10,
                  ),

                  const SizedBox(height: 24),

                  // ══════════ SADECE TAMAMLANMIŞ ══════════
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Sadece Tamamlanmış Profiller',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '%70 ve üzeri tamamlanma',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      value: _onlyComplete,
                      onChanged: (val) =>
                          setState(() => _onlyComplete = val),
                      activeThumbColor: AppTheme.accent,
                    ),
                  ).animate().fadeIn(delay: 550.ms),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Uygula butonu
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              border: Border(
                top: BorderSide(
                    color: AppTheme.border.withValues(alpha: 0.5)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search),
                  label: Text(
                    'Filtreleri Uygula',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.textOnAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // YARDIMCI WİDGET'LAR
  // ═══════════════════════════════════════

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildChipGroup<T>({
    required List<T> items,
    required T? selected,
    required String Function(T) labelOf,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = selected == item;
        return GestureDetector(
          onTap: () => onSelected(item),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accent.withValues(alpha: 0.15)
                  : AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accent
                    : AppTheme.border,
              ),
            ),
            child: Text(
              labelOf(item),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppTheme.accent
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRangeRow({
    required TextEditingController minController,
    required TextEditingController maxController,
    required String minHint,
    required String maxHint,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: minController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: minHint,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '–',
            style: GoogleFonts.inter(
                fontSize: 18, color: AppTheme.textTertiary),
          ),
        ),
        Expanded(
          child: TextField(
            controller: maxController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: maxHint,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }



  String _experienceLevelLabel(String level) {
    return switch (level) {
      'beginner' => 'Başlangıç',
      'intermediate' => 'Orta',
      'advanced' => 'İleri',
      'professional' => 'Profesyonel',
      _ => level,
    };
  }
}
