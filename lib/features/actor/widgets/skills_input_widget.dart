import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/actor_profile_model.dart';

/// Castelle - Skills Input Widget
/// Ucu açık dinamik yetenek ekleme/silme widget'ı
/// Chip tabanlı, autocomplete destekli, kategori önerili

class SkillsInputWidget extends StatefulWidget {
  final List<String> skills;
  final ValueChanged<List<String>> onSkillsChanged;
  final int maxSkills;

  const SkillsInputWidget({
    super.key,
    required this.skills,
    required this.onSkillsChanged,
    this.maxSkills = 50,
  });

  @override
  State<SkillsInputWidget> createState() => _SkillsInputWidgetState();
}

class _SkillsInputWidgetState extends State<SkillsInputWidget> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedCategory;
  bool _showSuggestions = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addSkill(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isEmpty) return;
    if (widget.skills.length >= widget.maxSkills) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('En fazla ${widget.maxSkills} yetenek ekleyebilirsin.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    // Tekrar kontrolü (case-insensitive)
    final exists = widget.skills
        .any((s) => s.toLowerCase() == trimmed.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu yetenek zaten ekli.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final updatedSkills = [...widget.skills, trimmed];
    widget.onSkillsChanged(updatedSkills);
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _removeSkill(String skill) {
    final updatedSkills = widget.skills.where((s) => s != skill).toList();
    widget.onSkillsChanged(updatedSkills);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mevcut yetenekler (chip'ler)
        if (widget.skills.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.skills.map((skill) {
              return _buildSkillChip(skill);
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Yetenek ekleme input
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Yetenek yaz... (ör: Eskrim, Piyano)',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    hintStyle: GoogleFonts.inter(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                    ),
                  ),
                  onSubmitted: _addSkill,
                  onChanged: (val) {
                    setState(() {
                      _showSuggestions = val.isNotEmpty;
                    });
                  },
                ),
              ),
              // Ekle butonu
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => _addSkill(_controller.text),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        const Icon(Icons.add, size: 20, color: AppTheme.accent),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Autocomplete önerileri
        if (_showSuggestions && _controller.text.isNotEmpty)
          _buildAutocompleteSuggestions(),

        const SizedBox(height: 16),

        // Sayaç
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.skills.length}/${widget.maxSkills} yetenek',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showSuggestions = false;
                  _selectedCategory = null;
                });
                _showCategorySuggestions();
              },
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 14, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Öneriler',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            skill,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _removeSkill(skill),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 12,
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutocompleteSuggestions() {
    final query = _controller.text.toLowerCase();
    final suggestions = SkillSuggestions.allSkills
        .where((s) =>
            s.toLowerCase().contains(query) &&
            !widget.skills.any(
                (existing) => existing.toLowerCase() == s.toLowerCase()))
        .take(5)
        .toList();

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: suggestions.map((suggestion) {
          return InkWell(
            onTap: () {
              _addSkill(suggestion);
              setState(() => _showSuggestions = false);
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline,
                      size: 16, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Text(
                    suggestion,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  void _showCategorySuggestions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Yetenek Önerileri',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kategoriden seç veya kendi yeteneğini yaz',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Kategori seçimi
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children:
                            SkillSuggestions.categories.keys.map((category) {
                          final isSelected = _selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  _selectedCategory =
                                      isSelected ? null : category;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accent.withValues(alpha: 0.15)
                                      : AppTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.accent
                                        : AppTheme.border,
                                  ),
                                ),
                                child: Text(
                                  category,
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
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Yetenek listesi
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: _getFilteredCategories()
                            .entries
                            .expand((entry) {
                          return [
                            // Kategori başlığı
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 12, bottom: 8),
                              child: Text(
                                entry.key,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            // Yetenekler
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entry.value.map((skill) {
                                final isAdded = widget.skills.any((s) =>
                                    s.toLowerCase() ==
                                    skill.toLowerCase());

                                return GestureDetector(
                                  onTap: isAdded
                                      ? null
                                      : () {
                                          _addSkill(skill);
                                          setSheetState(() {});
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isAdded
                                          ? AppTheme.success
                                              .withValues(alpha: 0.1)
                                          : AppTheme.surfaceElevated,
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusFull),
                                      border: Border.all(
                                        color: isAdded
                                            ? AppTheme.success
                                                .withValues(alpha: 0.3)
                                            : AppTheme.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isAdded)
                                          const Padding(
                                            padding:
                                                EdgeInsets.only(right: 4),
                                            child: Icon(
                                              Icons.check,
                                              size: 14,
                                              color: AppTheme.success,
                                            ),
                                          ),
                                        Text(
                                          skill,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: isAdded
                                                ? AppTheme.success
                                                : AppTheme.textPrimary,
                                            fontWeight: isAdded
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ];
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<String>> _getFilteredCategories() {
    if (_selectedCategory == null) {
      return SkillSuggestions.categories;
    }
    return {
      _selectedCategory!:
          SkillSuggestions.categories[_selectedCategory!] ?? [],
    };
  }
}
