import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/models/user_model.dart';

class AssignModeratorScreen extends StatefulWidget {
  const AssignModeratorScreen({super.key});

  @override
  State<AssignModeratorScreen> createState() => _AssignModeratorScreenState();
}

class _AssignModeratorScreenState extends State<AssignModeratorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  UserModel? _selectedUser;
  String _lastQuery = '';

  // Permission settings
  bool _tamYetki = false;
  bool _projeOlusturma = false;
  bool _duzenlemeYetkisi = false;
  bool _silmeYetkisi = false;
  bool _auditionToplama = false;
  bool _auditionDurumSecme = false;
  bool _oyuncuSilme = false;
  
  // Audition Permissions
  bool _auditionTamYetki = false;
  bool _auditionIndirme = false;
  bool _auditionSilme = false;
  bool _auditionCevaplama = false;
  bool _auditionOnaylama = false;
  bool _auditionRevizeIsteme = false;

  String _approvalMode = 'neutral';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _performSearch(String queryText) async {
    final cleanQuery = queryText.trim();
    if (cleanQuery == _lastQuery) return;
    _lastQuery = cleanQuery;

    if (cleanQuery.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final queryLower = cleanQuery.toLowerCase();
      final queryCapitalized = capitalizeWords(queryLower);

      final snapCapitalized = await _firestore
          .collection(AppConstants.usersCollection)
          .orderBy('fullName')
          .startAt([queryCapitalized])
          .endAt([queryCapitalized + '\uf8ff'])
          .limit(10)
          .get();

      final snapRaw = await _firestore
          .collection(AppConstants.usersCollection)
          .orderBy('fullName')
          .startAt([cleanQuery])
          .endAt([cleanQuery + '\uf8ff'])
          .limit(10)
          .get();

      final Map<String, UserModel> merged = {};
      for (var doc in snapCapitalized.docs) {
        final u = UserModel.fromMap(doc.data(), doc.id);
        merged[u.uid] = u;
      }
      for (var doc in snapRaw.docs) {
        final u = UserModel.fromMap(doc.data(), doc.id);
        merged[u.uid] = u;
      }

      final list = merged.values.toList();
      list.sort((a, b) => a.fullName.compareTo(b.fullName));

      if (mounted) {
        setState(() {
          _searchResults = list;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arama sırasında hata oluştu: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _assignAsModerator(UserModel user) async {
    if (_approvalMode == 'neutral') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen onay süreci modunu (Admin Onayı veya Otomatik Onay) seçin.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    try {
      final permissions = {
        'tamYetki': _tamYetki,
        'projeOlusturma': _tamYetki ? true : _projeOlusturma,
        'duzenlemeYetkisi': _tamYetki ? true : _duzenlemeYetkisi,
        'silmeYetkisi': _tamYetki ? true : _silmeYetkisi,
        'auditionToplama': _tamYetki ? true : _auditionToplama,
        'auditionDurumSecme': _tamYetki ? true : _auditionDurumSecme,
        'oyuncuSilme': _tamYetki ? true : _oyuncuSilme,
        
        // Audition permissions
        'auditionTamYetki': _auditionTamYetki,
        'auditionIndirme': _auditionTamYetki ? true : _auditionIndirme,
        'auditionSilme': _auditionTamYetki ? true : _auditionSilme,
        'auditionCevaplama': _auditionTamYetki ? true : _auditionCevaplama,
        'auditionOnaylama': _auditionTamYetki ? true : _auditionOnaylama,
        'auditionRevizeIsteme': _auditionTamYetki ? true : _auditionRevizeIsteme,
        
        'approvalMode': _approvalMode,
      };

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({
        'role': UserRole.moderator.value,
        'moderatorPermissions': permissions,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} artık Moderatör rolünde.'),
            backgroundColor: AppTheme.success,
          ),
        );
        setState(() {
          _selectedUser = null;
          _searchController.clear();
          _searchResults = [];
          _lastQuery = '';
          _resetPermissions();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Atama sırasında hata oluştu: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _resetPermissions() {
    _tamYetki = false;
    _projeOlusturma = false;
    _duzenlemeYetkisi = false;
    _silmeYetkisi = false;
    _auditionToplama = false;
    _auditionDurumSecme = false;
    _oyuncuSilme = false;
    
    _auditionTamYetki = false;
    _auditionIndirme = false;
    _auditionSilme = false;
    _auditionCevaplama = false;
    _auditionOnaylama = false;
    _auditionRevizeIsteme = false;
    
    _approvalMode = 'neutral';
  }

  Future<void> _removeModerator(UserModel user) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({
        'role': UserRole.actor.value,
        'moderatorPermissions': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} moderatörlük rolü geri alındı (Oyuncu yapıldı).'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rol geri alınırken hata oluştu: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _editPermissionsDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) {
        final existingPerms = user.moderatorPermissions ?? {};
        bool tamYetki = existingPerms['tamYetki'] == true;
        bool projeOlusturma = existingPerms['projeOlusturma'] == true;
        bool duzenlemeYetkisi = existingPerms['duzenlemeYetkisi'] == true;
        bool silmeYetkisi = existingPerms['silmeYetkisi'] == true;
        bool auditionToplama = existingPerms['auditionToplama'] == true;
        bool auditionDurumSecme = existingPerms['auditionDurumSecme'] == true;
        bool oyuncuSilme = existingPerms['oyuncuSilme'] == true;
        
        bool auditionTamYetki = existingPerms['auditionTamYetki'] == true;
        bool auditionIndirme = existingPerms['auditionIndirme'] == true;
        bool auditionSilme = existingPerms['auditionSilme'] == true;
        bool auditionCevaplama = existingPerms['auditionCevaplama'] == true;
        bool auditionOnaylama = existingPerms['auditionOnaylama'] == true;
        bool auditionRevizeIsteme = existingPerms['auditionRevizeIsteme'] == true;
        
        String approvalMode = existingPerms['approvalMode'] ?? 'neutral';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              title: Text(
                '${user.fullName} Yetkileri',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Projeler Yetkileri'),
                    _buildDialogSwitchTile('Tam Yetki (Admin gibi)', tamYetki, (val) {
                      setDialogState(() {
                        tamYetki = val;
                      });
                    }),
                    if (!tamYetki) ...[
                      _buildDialogSwitchTile('Proje Oluşturma', projeOlusturma, (val) => setDialogState(() => projeOlusturma = val)),
                      _buildDialogSwitchTile('Proje Düzenleme', duzenlemeYetkisi, (val) => setDialogState(() => duzenlemeYetkisi = val)),
                      _buildDialogSwitchTile('Proje Silme', silmeYetkisi, (val) => setDialogState(() => silmeYetkisi = val)),
                      _buildDialogSwitchTile('Audition Toplama Yetkisi', auditionToplama, (val) => setDialogState(() => auditionToplama = val)),
                    ],
                    const Divider(),
                    _buildSectionHeader('Audition Yetkileri'),
                    _buildDialogSwitchTile('Tam Yetki (Audition)', auditionTamYetki, (val) {
                      setDialogState(() {
                        auditionTamYetki = val;
                      });
                    }),
                    if (!auditionTamYetki) ...[
                      _buildDialogSwitchTile('Audition İndirme', auditionIndirme, (val) => setDialogState(() => auditionIndirme = val)),
                      _buildDialogSwitchTile('Audition Silme', auditionSilme, (val) => setDialogState(() => auditionSilme = val)),
                      _buildDialogSwitchTile('Audition Cevaplama & Mesaj Gönder', auditionCevaplama, (val) => setDialogState(() => auditionCevaplama = val)),
                      _buildDialogSwitchTile('Audition Onaylama / Reddetme', auditionOnaylama, (val) => setDialogState(() => auditionOnaylama = val)),
                      _buildDialogSwitchTile('Revize İsteme', auditionRevizeIsteme, (val) => setDialogState(() => auditionRevizeIsteme = val)),
                    ],
                    const Divider(),
                    _buildSectionHeader('Oyuncu Profili Yetkileri'),
                    _buildDialogSwitchTile('Oyuncu Silme', oyuncuSilme, (val) => setDialogState(() => oyuncuSilme = val)),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Onay Süreci Modu *',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: AppTheme.border, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => setDialogState(() => approvalMode = 'admin'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: approvalMode == 'admin' ? AppTheme.accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                child: Text(
                                  'Admin Onayı',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: approvalMode == 'admin' ? Colors.white : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setDialogState(() => approvalMode = 'neutral'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: approvalMode == 'neutral' ? Colors.grey : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                child: Text(
                                  'Seçim Yok',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: approvalMode == 'neutral' ? Colors.white : AppTheme.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setDialogState(() => approvalMode = 'auto'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: approvalMode == 'auto' ? AppTheme.success : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                child: Text(
                                  'Otomatik',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: approvalMode == 'auto' ? Colors.white : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: approvalMode == 'neutral'
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final permissions = {
                            'tamYetki': tamYetki,
                            'projeOlusturma': tamYetki ? true : projeOlusturma,
                            'duzenlemeYetkisi': tamYetki ? true : duzenlemeYetkisi,
                            'silmeYetkisi': tamYetki ? true : silmeYetkisi,
                            'auditionToplama': tamYetki ? true : auditionToplama,
                            'auditionDurumSecme': tamYetki ? true : auditionDurumSecme,
                            'oyuncuSilme': tamYetki ? true : oyuncuSilme,
                            
                            'auditionTamYetki': auditionTamYetki,
                            'auditionIndirme': auditionTamYetki ? true : auditionIndirme,
                            'auditionSilme': auditionTamYetki ? true : auditionSilme,
                            'auditionCevaplama': auditionTamYetki ? true : auditionCevaplama,
                            'auditionOnaylama': auditionTamYetki ? true : auditionOnaylama,
                            'auditionRevizeIsteme': auditionTamYetki ? true : auditionRevizeIsteme,
                            
                            'approvalMode': approvalMode,
                          };

                          await _firestore
                              .collection(AppConstants.usersCollection)
                              .doc(user.uid)
                              .update({
                            'moderatorPermissions': permissions,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Moderatör yetkileri güncellendi.'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                  child: const Text('Güncelle', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.accent,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.accent,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildDialogSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimary),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.accent,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Moderatör Atama & Yetkileri'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Arama Kutusu Başlığı
            Text(
              'Moderatör Atamak İstediğiniz Kişiyi Arayın',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            // Arama Textbox
            TextField(
              controller: _searchController,
              onChanged: _performSearch,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Kullanıcının adını yazmaya başlayın...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _selectedUser = null;
                            _lastQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 12),

            // Arama Sonuçları Listesi
            if (_isSearching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
              )
            else if (_searchResults.isNotEmpty && _selectedUser == null)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final isAlreadyMod = user.role == UserRole.moderator;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAlreadyMod
                            ? AppTheme.warning.withValues(alpha: 0.15)
                            : AppTheme.primary.withValues(alpha: 0.1),
                        child: Text(
                          _getInitials(user.fullName),
                          style: TextStyle(
                            color: isAlreadyMod ? AppTheme.warning : AppTheme.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        user.fullName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${user.email} • Rol: ${user.role.displayName}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                      ),
                      trailing: isAlreadyMod
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Zaten Moderatör',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warning,
                                ),
                              ),
                            )
                          : const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                      onTap: isAlreadyMod
                          ? null
                          : () {
                              setState(() {
                                _selectedUser = user;
                              });
                            },
                    );
                  },
                ),
              ),

            // Seçilen Kullanıcı Onay Kartı + Yetki Arayüzü
            if (_selectedUser != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                          child: Text(
                            _getInitials(_selectedUser!.fullName),
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedUser!.fullName,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                _selectedUser!.email,
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    
                    // Yetkiler Formu
                    _buildSectionHeader('Projeler Yetkileri'),
                    _buildSwitchTile('Tam Yetki (Admin Gibi)', _tamYetki, (val) {
                      setState(() {
                        _tamYetki = val;
                      });
                    }),
                    if (!_tamYetki) ...[
                      _buildSwitchTile('Proje Oluşturma', _projeOlusturma, (val) => setState(() => _projeOlusturma = val)),
                      _buildSwitchTile('Proje Düzenleme', _duzenlemeYetkisi, (val) => setState(() => _duzenlemeYetkisi = val)),
                      _buildSwitchTile('Proje Silme', _silmeYetkisi, (val) => setState(() => _silmeYetkisi = val)),
                      _buildSwitchTile('Audition Toplama Yetkisi', _auditionToplama, (val) => setState(() => _auditionToplama = val)),
                    ],
                    const Divider(),
                    _buildSectionHeader('Audition Yetkileri'),
                    _buildSwitchTile('Tam Yetki (Audition)', _auditionTamYetki, (val) {
                      setState(() {
                        _auditionTamYetki = val;
                      });
                    }),
                    if (!_auditionTamYetki) ...[
                      _buildSwitchTile('Audition İndirme', _auditionIndirme, (val) => setState(() => _auditionIndirme = val)),
                      _buildSwitchTile('Audition Silme', _auditionSilme, (val) => setState(() => _auditionSilme = val)),
                      _buildSwitchTile('Audition Cevaplama & Mesaj Gönderme', _auditionCevaplama, (val) => setState(() => _auditionCevaplama = val)),
                      _buildSwitchTile('Audition Onaylama / Reddetme', _auditionOnaylama, (val) => setState(() => _auditionOnaylama = val)),
                      _buildSwitchTile('Revize İsteme', _auditionRevizeIsteme, (val) => setState(() => _auditionRevizeIsteme = val)),
                    ],
                    const Divider(),
                    _buildSectionHeader('Oyuncu Profili Yetkileri'),
                    _buildSwitchTile('Oyuncu Silme', _oyuncuSilme, (val) => setState(() => _oyuncuSilme = val)),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Onay Süreci Modu Seçimi (ZORUNLU)
                    Text(
                      'Onay Süreci Modu *',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.border, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Sola Çek (Admin Onayı)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _approvalMode = 'admin';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _approvalMode == 'admin' ? AppTheme.accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                child: Text(
                                  '◀ Admin Onayı',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _approvalMode == 'admin' ? Colors.white : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            // Orta (Seçilmedi / Nötr)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _approvalMode = 'neutral';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _approvalMode == 'neutral' ? Colors.grey[400] : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                child: Text(
                                  '● Seçim Yok',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _approvalMode == 'neutral' ? Colors.white : AppTheme.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                            // Sağa Çek (Otomatik Onay)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _approvalMode = 'auto';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _approvalMode == 'auto' ? AppTheme.success : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                child: Text(
                                  'Otomatik ▶',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _approvalMode == 'auto' ? Colors.white : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedUser = null;
                              _resetPermissions();
                            });
                          },
                          child: const Text('Vazgeç'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _approvalMode == 'neutral'
                              ? null
                              : () => _assignAsModerator(_selectedUser!),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Kaydet ve Moderatör Yap'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: AppTheme.textOnAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.05),
            ],

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // Mevcut Moderatörler Bölümü
            Row(
              children: [
                const Icon(Icons.shield, color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Aktif Moderatörler',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Moderatör Listesi (StreamBuilder)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection(AppConstants.usersCollection)
                  .where('role', isEqualTo: UserRole.moderator.value)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: Center(
                      child: Text(
                        'Sistemde henüz moderatör bulunmuyor.',
                        style: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final user = UserModel.fromMap(doc.data(), doc.id);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                            child: Text(
                              _getInitials(user.fullName),
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  user.email,
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Onay Modu: ${user.moderatorPermissions?['approvalMode'] == 'auto' ? "Otomatik Onay" : "Admin Onayı"}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, color: AppTheme.accent, size: 20),
                            tooltip: 'Yetkileri Düzenle',
                            onPressed: () => _editPermissionsDialog(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 20),
                            tooltip: 'Moderatörlük Rolünü Kaldır',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Rolü Geri Al'),
                                  content: Text('${user.fullName} isimli kullanıcının moderatörlük rolünü kaldırmak istediğinize emin misiniz?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('İptal'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _removeModerator(user);
                                      },
                                      child: const Text('Evet, Kaldır', style: TextStyle(color: AppTheme.error)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
