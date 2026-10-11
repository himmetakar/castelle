import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/models/actor_filter_model.dart';
import 'package:castelle/core/constants/app_constants.dart';

// Castelle - Actor Filter Provider
// Oyuncu filtreleme durum yönetimi — saf Firestore, yerel depolama yok

class ActorFilterProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ActorFilterModel _filter = const ActorFilterModel();
  List<ActorProfileModel> _results = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  DocumentSnapshot? _lastDoc;

  /// Oyuncular oyuncu havuzunda yalnızca herkese açık (gizli olmayan)
  /// profilleri görebilir. Firestore kuralları gizli profilleri (18 yaş altı /
  /// veli onayı bekleyen / kendini gizleyen) oyunculara kapatır; sorgu da
  /// bu yüzden filtrelenmelidir. Admin/moderatör için false.
  bool publicOnly = false;

  // Getters
  ActorFilterModel get filter => _filter;
  List<ActorProfileModel> get results => _results;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  bool? _isStaffCache;
  String? _isStaffUid;

  /// Oturumdaki kullanıcı admin/moderatör mü? (kullanıcı başına bir kez okunur)
  Future<bool> _isStaff() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    if (_isStaffUid == uid && _isStaffCache != null) return _isStaffCache!;
    try {
      final doc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
      _isStaffCache = ['admin', 'moderator'].contains(doc.data()?['role']);
    } catch (_) {
      _isStaffCache = false;
    }
    _isStaffUid = uid;
    return _isStaffCache!;
  }

  /// Filtreyi güncelle
  void updateFilter(ActorFilterModel newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  /// Filtreleri temizle
  void clearFilters() {
    _filter = const ActorFilterModel();
    _results = [];
    _hasMore = true;
    _lastDoc = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Arama yap — saf Firestore
  /// Yaş + cinsiyet: zorunlu Firestore filtresi
  /// Yetenekler: soft filtre — eşleşenler üste gelir, diğerleri altta görünür
  Future<void> search({bool loadMore = false}) async {
    if (_isLoading) return;
    if (loadMore && !_hasMore) return;

    _isLoading = true;
    _errorMessage = null;

    if (!loadMore) {
      _results = [];
      _lastDoc = null;
      _hasMore = true;
    }

    notifyListeners();

    try {
      // Eskiden yalnızca ilk 200 oyuncu çekilip filtre bunların üzerinde
      // uygulanıyordu; 200'ün dışında kalan uygun profiller (ör. 35 yaş /
      // 185 cm) sonuçlarda hiç görünmüyordu. Artık tüm onaylı oyuncular
      // sayfa sayfa çekilir ve filtre hepsine uygulanır.
      const limit = 500;

      Query<Map<String, dynamic>> query = _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: 'actor')
          // Yalnızca admin onaylı profiller — "onay bekleyen" / reddedilen
          // kullanıcılar veri tabanı sorgusunda elenir.
          .where('approvalStatus', isEqualTo: 'approved');

      // Admin/moderatör dışındakiler yalnızca gizli olmayan profilleri
      // listeleyebilir (Firestore kuralları); aksi halde permission-denied.
      if (publicOnly || !await _isStaff()) {
        query = query.where('isHidden', isEqualTo: false);
      }

      // Cinsiyet artık client-side (matchesActorHard) kontrol edilir: eski
      // kayıtlardaki 'Erkek' / 'Male' gibi yazımlar Firestore eşitlik
      // sorgusunda kaçıyordu.

      if (_filter.onlyComplete) {
        query = query.where('isProfileComplete', isEqualTo: true);
      }

      // Skills artık Firestore'da filtrelenmez — soft/bonus olarak client-side sıralanır

      // Tüm sayfaları sırayla çek (en fazla 20 × 500 = 10.000 oyuncu)
      for (var page = 0; page < 20; page++) {
        var pageQuery = query.limit(limit);
        if (_lastDoc != null) {
          pageQuery = pageQuery.startAfterDocument(_lastDoc!);
        }

        final snapshot = await pageQuery.get();
        if (snapshot.docs.isEmpty) break;
        _lastDoc = snapshot.docs.last;

        for (final doc in snapshot.docs) {
          ActorProfileModel actor;
          try {
            actor = ActorProfileModel.fromMap(doc.data(), doc.id);
          } catch (e) {
            // Tek bir bozuk kayıt tüm aramayı düşürmesin
            debugPrint('⚠️ [ActorFilterProvider] Oyuncu atlandı (${doc.id}): $e');
            continue;
          }
          // Client-side zorunlu filtreler (yaş, boy, kilo, göz, saç, şehir, deneyim, isim)
          if (!actor.isApproved || !_filter.matchesActorHard(actor)) continue;
          if (!_results.any((a) => a.uid == actor.uid)) {
            _results.add(actor);
          }
        }

        if (snapshot.docs.length < limit) break;
      }
      _hasMore = false;

      // ── SIRALAMA ──
      // 1. Skill eşleşme sayısına göre (çok → az)
      // 2. Eşit skill sayısında isme göre
      if (_filter.skills.isNotEmpty) {
        final querySkills = _filter.skills.map((s) => s.toLowerCase()).toSet();
        _results.sort((a, b) {
          final aMatch = a.skills
              .where((s) => querySkills.contains(s.toLowerCase()))
              .length;
          final bMatch = b.skills
              .where((s) => querySkills.contains(s.toLowerCase()))
              .length;
          if (bMatch != aMatch) return bMatch.compareTo(aMatch);
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        });
      } else {
        _results.sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [ActorFilterProvider.search Error]: $e');
      _hasMore = false;
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }
}

