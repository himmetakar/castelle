import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:castelle/core/constants/app_constants.dart';

/// Castelle - Hassas Profil Alanları
///
/// Telefon, veli telefonu ve banka bilgileri `users/{uid}` kök dokümanında tutulmaz.
/// Kök doküman oyuncu havuzu listelenebilsin diye tüm oturumlu kullanıcılara
/// okunabilir; bu alanlar `users/{uid}/private/contact` alt dokümanında durur
/// ve sadece sahibine + admin/moderatöre açıktır (bkz. firestore.rules).
///
/// Modeller değişmedi — ayrıştırma yalnızca Firestore sınırında yapılır.

const List<String> kPrivateProfileFields = [
  'phone',
  'guardianPhone',
  'bankIban',
  'bankAccountHolder',
];

DocumentReference<Map<String, dynamic>> privateProfileRef(
  FirebaseFirestore db,
  String uid,
) {
  return db
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.privateCollection)
      .doc(AppConstants.privateContactDoc);
}

/// [data] içinden hassas alanları söker ve ayrı map olarak döndürür.
/// Kök dokümanda kalmış eski kopyaları [migratePrivateFields] temizler.
Map<String, dynamic> takePrivateFields(Map<String, dynamic> data) {
  final private = <String, dynamic>{};
  for (final key in kPrivateProfileFields) {
    if (data.containsKey(key)) private[key] = data.remove(key);
  }
  return private;
}

/// Hassas alanları okur. Yetki yoksa boş map döner — başka bir oyuncunun
/// profilini görüntülemek bu yüzden hata vermez, alanlar sadece boş gelir.
Future<Map<String, dynamic>> readPrivateFields(
  FirebaseFirestore db,
  String uid,
) async {
  try {
    final doc = await privateProfileRef(db, uid).get();
    return doc.data() ?? const <String, dynamic>{};
  } catch (e) {
    debugPrint('ℹ️ [PrivateFields] $uid okunamadı: $e');
    return const <String, dynamic>{};
  }
}

Future<void> writePrivateFields(
  FirebaseFirestore db,
  String uid,
  Map<String, dynamic> fields,
) async {
  if (fields.isEmpty) return;
  await privateProfileRef(db, uid).set(fields, SetOptions(merge: true));
}

/// Kök dokümandaki eski kopyaları alt dokümana taşır ve kökten siler.
/// Sadece kullanıcının kendi oturumu için çağrılır; ilk açılışta bir kez
/// çalışır, sonrasında taşınacak alan kalmadığı için no-op olur.
Future<void> migratePrivateFields(
  FirebaseFirestore db,
  String uid,
  Map<String, dynamic> rootData,
) async {
  final legacy = <String, dynamic>{};
  for (final key in kPrivateProfileFields) {
    final value = rootData[key];
    if (value != null && value != '') legacy[key] = value;
  }
  if (legacy.isEmpty) return;

  try {
    await writePrivateFields(db, uid, legacy);
    await db.collection(AppConstants.usersCollection).doc(uid).update({
      for (final key in legacy.keys) key: FieldValue.delete(),
    });
    debugPrint('✅ [PrivateFields] $uid taşındı: ${legacy.keys.join(", ")}');
  } catch (e) {
    debugPrint('⚠️ [PrivateFields] $uid taşınamadı: $e');
  }
}
