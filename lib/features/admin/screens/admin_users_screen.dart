import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/models/user_model.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/admin/screens/actor_filter_screen.dart';
import 'package:castelle/features/admin/screens/actor_detail_screen.dart';

/// Admin Kullanıcı Yönetim Ekranı
/// Tüm kullanıcıları listeler, rol ataması ve aktif/pasif yönetimi yapar

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserRole? _filterRole;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
        actions: [
          // Filtre popup
          PopupMenuButton<UserRole?>(
            icon: Icon(
              Icons.filter_list,
              color: _filterRole != null ? AppTheme.accent : AppTheme.textSecondary,
            ),
            onSelected: (role) {
              setState(() {
                _filterRole = _filterRole == role ? null : role;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Tümü'),
              ),
              ...UserRole.values.map((role) => PopupMenuItem(
                    value: role,
                    child: Row(
                      children: [
                        Icon(
                          _getRoleIcon(role),
                          size: 18,
                          color: _filterRole == role
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(role.displayName),
                      ],
                    ),
                  )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Gelişmiş Oyuncu Filtreleme Butonu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ActorFilterScreen()),
                  );
                },
                icon: const Icon(Icons.tune, size: 18),
                label: Text(
                  'Gelişmiş Oyuncu Filtreleme 🔍',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.textOnAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                ),
              ),
            ),
          ),

          // Arama çubuğu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'İsim, e-posta veya telefon ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),

          // Filtre badge
          if (_filterRole != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    'Filtre: ${_filterRole!.displayName}',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  deleteIcon:
                      const Icon(Icons.close, size: 16, color: AppTheme.accent),
                  onDeleted: () => setState(() => _filterRole = null),
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                  side: BorderSide(
                      color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
              ),
            ),

          // Kullanıcı listesi
          Expanded(
            child: _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    Query<Map<String, dynamic>> query =
        _firestore.collection(AppConstants.usersCollection);

    if (_filterRole != null) {
      query = query.where('role', isEqualTo: _filterRole!.value);
    }

    query = query.orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                Text(
                  'Bir hata oluştu',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot.error}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Arama filtresi (client-side)
        final filteredDocs = _searchQuery.isEmpty
            ? docs
            : docs.where((doc) {
                final data = doc.data();
                final name =
                    (data['fullName'] ?? '').toString().toLowerCase();
                final email =
                    (data['email'] ?? '').toString().toLowerCase();
                final query = _searchQuery.toLowerCase();
                return name.contains(query) || email.contains(query);
              }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 56,
                  color: AppTheme.textTertiary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Aramanızla eşleşen kullanıcı bulunamadı'
                      : 'Henüz kullanıcı yok',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final user = UserModel.fromMap(doc.data(), doc.id);

            return _buildUserCard(context, user, index);
          },
        );
      },
    );
  }

  Widget _buildUserCard(BuildContext context, UserModel user, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: Center(
              child: Text(
                _getInitials(user.fullName),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.fullName,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Aktif/Pasif badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: user.isActive
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.error.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        user.isActive ? 'Aktif' : 'Pasif',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color:
                              user.isActive ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Rol chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(
                      color: _getRoleColor(user.role).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    user.role.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getRoleColor(user.role),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Düzenleme butonu
          IconButton(
            icon: const Icon(Icons.more_vert,
                size: 20, color: AppTheme.textTertiary),
            onPressed: () => _showUserActions(context, user),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (100 + index * 50).ms)
        .slideX(begin: 0.03);
  }

  void _showUserActions(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Kullanıcı bilgisi
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(user.fullName),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        user.email,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 8),

            // Rol değiştir
            Text(
              'Rol Değiştir',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: UserRole.values.map((role) {
                final isCurrentRole = user.role == role;
                return ChoiceChip(
                  label: Text(role.displayName),
                  selected: isCurrentRole,
                  onSelected: isCurrentRole
                      ? null
                      : (_) {
                          Navigator.pop(ctx);
                          _changeUserRole(user, role);
                        },
                  selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                  avatar: Icon(
                    _getRoleIcon(role),
                    size: 16,
                    color: isCurrentRole
                        ? AppTheme.accent
                        : AppTheme.textTertiary,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 8),

            // Oyuncu Yönetim Aksiyonları
            if (user.role == UserRole.actor) ...[
              // Profili İncele / CV Gör
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_search_outlined, color: AppTheme.accent),
                title: Text(
                  'Oyuncu Profilini İncele (CV Gör)',
                  style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final doc = await _firestore.collection('users').doc(user.uid).get();
                    if (doc.exists && context.mounted) {
                      final actorProfile = ActorProfileModel.fromMap(doc.data()!, doc.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ActorDetailScreen(actor: actorProfile)),
                      );
                    }
                  } catch (e) {
                    debugPrint('Error loading actor profile: $e');
                  }
                },
              ),

              // Profil Onayla / Reddet
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined, color: AppTheme.success),
                title: Text(
                  'Oyuncuyu Onayla (Yayına Al)',
                  style: GoogleFonts.inter(color: AppTheme.success, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _approveActorProfile(user);
                },
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cancel_outlined, color: AppTheme.warning),
                title: Text(
                  'Profil Onayını Reddet / Not Ekle',
                  style: GoogleFonts.inter(color: AppTheme.warning, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _rejectActorProfileDialog(user);
                },
              ),
              const Divider(color: AppTheme.border),
            ],

            // Aktif/Pasif toggle
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                user.isActive
                    ? Icons.block
                    : Icons.check_circle_outline,
                color: user.isActive ? AppTheme.warning : AppTheme.success,
              ),
              title: Text(
                user.isActive ? 'Hesabı Devre Dışı Bırak (Pasife Çek)' : 'Hesabı Aktifleştir',
                style: GoogleFonts.inter(
                  color: user.isActive ? AppTheme.warning : AppTheme.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleUserActive(user);
              },
            ),

            // Kullanıcıyı Kalıcı Sil
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.error),
              title: Text(
                'Kullanıcıyı Kalıcı Olarak Sil',
                style: GoogleFonts.inter(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteUser(user);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _changeUserRole(UserModel user, UserRole newRole) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({
        'role': newRole.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${user.fullName} artık ${newRole.displayName} rolünde.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleUserActive(UserModel user) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user?.role == UserRole.moderator) {
      if (!authProvider.user!.hasModeratorPermission('oyuncuSilme')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oyuncu profilini silme/devre dışı bırakma yetkiniz bulunmamaktadır.'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({
        'isActive': !user.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.isActive
                  ? '${user.fullName} devre dışı bırakıldı.'
                  : '${user.fullName} aktifleştirildi.',
            ),
            backgroundColor:
                user.isActive ? AppTheme.warning : AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _approveActorProfile(UserModel user) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(user.uid).update({
        'approvalStatus': 'approved',
        'isActive': true,
        'isHidden': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} oyuncu profili onaylandı ve yayına alındı ✅'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Onaylama hatası: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _rejectActorProfileDialog(UserModel user) async {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text('Profil Onayını Reddet', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${user.fullName} oyuncusunun profili reddedilecek. Oyuncuya iletilecek admin notunu yazabilirsiniz:',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Örn: Lütfen vesikalık yerine net portfolio fotoğrafı yükleyin.',
                labelText: 'Admin Notu (Opsiyonel)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _firestore.collection(AppConstants.usersCollection).doc(user.uid).update({
                  'approvalStatus': 'rejected',
                  'adminNote': noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                  'isActive': false,
                  'isHidden': true,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.fullName} profili reddedildi ❌'),
                      backgroundColor: AppTheme.warning,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('İşlem hatası: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUser(UserModel user) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı hesabı silme yetkisi sadece Admin role aittir.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text('Kullanıcıyı Sil', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.error)),
        content: Text(
          '${user.fullName} (${user.email}) kullanıcısı ve tüm profil verileri Firestore veritabanından KALICI OLARAK silinecektir.\n\nBu işlem geri alınamaz!',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Kalıcı Olarak Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection(AppConstants.usersCollection).doc(user.uid).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.fullName} hesabı başarıyla silindi.'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Silme hatası: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  IconData _getRoleIcon(UserRole role) {
    return switch (role) {
      UserRole.admin => Icons.admin_panel_settings,
      UserRole.moderator => Icons.shield,
      UserRole.actor => Icons.person,
    };
  }

  Color _getRoleColor(UserRole role) {
    return switch (role) {
      UserRole.admin => AppTheme.error,
      UserRole.moderator => AppTheme.warning,
      UserRole.actor => AppTheme.success,
    };
  }
}
