import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Getters
  ActorFilterModel get filter => _filter;
  List<ActorProfileModel> get results => _results;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

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
      const limit = 200; // geniş çek, sıralama client-side

      Query<Map<String, dynamic>> query = _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: 'actor');

      // ── ZORUNLU FİLTRELER (Firestore tarafı) ──
      if (_filter.gender != null) {
        query = query.where('gender', isEqualTo: _filter.gender!.value);
      }

      if (_filter.onlyComplete) {
        query = query.where('isProfileComplete', isEqualTo: true);
      }

      // Skills artık Firestore'da filtrelenmez — soft/bonus olarak client-side sıralanır

      query = query.limit(limit);

      if (loadMore && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMore = false;
      } else {
        _lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < limit) {
          _hasMore = false;
        }

        final actors = snapshot.docs
            .map((doc) => ActorProfileModel.fromMap(doc.data(), doc.id))
            .toList();

        // Client-side zorunlu filtreler (yaş, boy, kilo, göz, saç, şehir, deneyim, isim)
        final filtered = actors.where((actor) => _filter.matchesActorHard(actor)).toList();

        // Tekilleştirerek ekle
        for (final actor in filtered) {
          if (!_results.any((a) => a.uid == actor.uid)) {
            _results.add(actor);
          }
        }
      }

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

