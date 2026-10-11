import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle — Zorunlu güncelleme kapısı + sürüm damgası
///
/// Neden: Sahada herkes farklı sürüm kullanınca "bende oluyor onda olmuyor"
/// şikâyetleri çıkıyor ve hangi sürümde hata olduğu anlaşılamıyor.
///
/// 1) Firestore `config/app` belgesi:
///      minBuildNumber : int    — bundan küçük build açılamaz (örn. 25)
///      updateMessage  : String — (isteğe bağlı) kullanıcıya gösterilecek metin
///      androidStoreUrl: String — (isteğe bağlı) Play Store linki
///      iosStoreUrl    : String — (isteğe bağlı) App Store linki
///    Belge yoksa / okunamazsa kapı kapalı kalır (uygulama normal açılır).
///
/// 2) Giriş yapmış kullanıcının `users/{uid}` belgesine appVersion / appBuild /
///    appPlatform / lastSeenAt yazılır; admin panelinde kartta görünür.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  PackageInfo? _info;
  int? _minBuild;
  String? _message;
  String? _storeUrl;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _cfgSub;
  StreamSubscription<User?>? _authSub;
  String? _stampedUid;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _info = await PackageInfo.fromPlatform();
    } catch (e) {
      debugPrint('⚠️ [UpdateGate] PackageInfo okunamadı: $e');
    }
    if (!mounted) return;
    setState(() {});

    // Web'de mağaza güncellemesi yok; sadece sürüm damgası.
    if (!kIsWeb) {
      _cfgSub = FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .snapshots()
          .listen((snap) {
        final d = snap.data();
        if (!mounted) return;
        setState(() {
          _minBuild = (d?['minBuildNumber'] as num?)?.toInt();
          final msg = d?['updateMessage'];
          _message = msg is String ? msg : null;
          final iosUrl = d?['iosStoreUrl'];
          final androidUrl = d?['androidStoreUrl'];
          final picked = Platform.isIOS ? iosUrl : androidUrl;
          _storeUrl = picked is String ? picked : null;
        });
      }, onError: (e) {
        // Kural henüz yayınlanmamış olabilir (permission-denied) → kapı kapalı.
        debugPrint('⚠️ [UpdateGate] config/app okunamadı: $e');
      });
    }

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.uid != _stampedUid) {
        _stampedUid = user.uid;
        _stampVersion(user.uid);
      }
    });
  }

  Future<void> _stampVersion(String uid) async {
    final info = _info;
    if (info == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({
        'appVersion': info.version,
        'appBuild': int.tryParse(info.buildNumber) ?? info.buildNumber,
        'appPlatform': kIsWeb
            ? 'Web'
            : Platform.isIOS
                ? 'iOS'
                : Platform.isAndroid
                    ? 'Android'
                    : Platform.operatingSystem,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Kullanıcı belgesi henüz yoksa (kayıt akışı) ya da kural izin vermiyorsa sessiz geç.
      debugPrint('⚠️ [UpdateGate] Sürüm damgası yazılamadı: $e');
    }
  }

  @override
  void dispose() {
    _cfgSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  int get _currentBuild => int.tryParse(_info?.buildNumber ?? '') ?? 0;

  bool get _mustUpdate {
    if (kIsWeb) return false;
    final min = _minBuild;
    if (min == null || _info == null) return false;
    return _currentBuild < min;
  }

  String get _defaultStoreUrl {
    if (!kIsWeb && Platform.isIOS) {
      return 'https://apps.apple.com/app/castelle/id0';
    }
    return 'https://play.google.com/store/apps/details?id=${_info?.packageName ?? 'com.castelleapp.castle48'}';
  }

  Future<void> _openStore() async {
    final url = (_storeUrl != null && _storeUrl!.isNotEmpty) ? _storeUrl! : _defaultStoreUrl;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('⚠️ [UpdateGate] Mağaza açılamadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_mustUpdate) return widget.child;

    return Material(
      color: AppTheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update, size: 64, color: AppTheme.accent),
                const SizedBox(height: 20),
                Text(
                  'Güncelleme Gerekli',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _message ??
                      'Castelle\'in yeni bir sürümü yayınlandı. Devam etmek için '
                          'lütfen uygulamayı güncelleyin.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Yüklü sürüm: ${_info?.version ?? '?'} ($_currentBuild) · Gerekli: $_minBuild+',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openStore,
                    icon: const Icon(Icons.download),
                    label: Text('Mağazadan Güncelle',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
