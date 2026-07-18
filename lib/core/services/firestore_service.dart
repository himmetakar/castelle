import 'package:cloud_firestore/cloud_firestore.dart';

/// Castelle - Firestore Service
/// Genel Firestore CRUD operasyonları

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseFirestore get instance => _firestore;

  /// Belge oluştur
  Future<void> createDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection(collection).doc(docId).set(data);
  }

  /// Belge oku
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument({
    required String collection,
    required String docId,
  }) async {
    return await _firestore.collection(collection).doc(docId).get();
  }

  /// Belge güncelle
  Future<void> updateDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection(collection).doc(docId).update(data);
  }

  /// Belge sil
  Future<void> deleteDocument({
    required String collection,
    required String docId,
  }) async {
    await _firestore.collection(collection).doc(docId).delete();
  }

  /// Koleksiyon sorgulama
  Future<QuerySnapshot<Map<String, dynamic>>> queryCollection({
    required String collection,
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);

    // Filtreleri uygula
    if (filters != null) {
      for (final filter in filters) {
        switch (filter.operator) {
          case FilterOperator.isEqualTo:
            query = query.where(filter.field, isEqualTo: filter.value);
            break;
          case FilterOperator.isNotEqualTo:
            query = query.where(filter.field, isNotEqualTo: filter.value);
            break;
          case FilterOperator.isLessThan:
            query = query.where(filter.field, isLessThan: filter.value);
            break;
          case FilterOperator.isLessThanOrEqualTo:
            query =
                query.where(filter.field, isLessThanOrEqualTo: filter.value);
            break;
          case FilterOperator.isGreaterThan:
            query = query.where(filter.field, isGreaterThan: filter.value);
            break;
          case FilterOperator.isGreaterThanOrEqualTo:
            query = query.where(filter.field,
                isGreaterThanOrEqualTo: filter.value);
            break;
          case FilterOperator.arrayContains:
            query = query.where(filter.field, arrayContains: filter.value);
            break;
          case FilterOperator.arrayContainsAny:
            query = query.where(filter.field, arrayContainsAny: filter.value);
            break;
          case FilterOperator.whereIn:
            query = query.where(filter.field, whereIn: filter.value);
            break;
        }
      }
    }

    // Sıralama
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    // Pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Limit
    if (limit != null) {
      query = query.limit(limit);
    }

    return await query.get();
  }

  /// Koleksiyon stream
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection({
    required String collection,
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);

    if (filters != null) {
      for (final filter in filters) {
        switch (filter.operator) {
          case FilterOperator.isEqualTo:
            query = query.where(filter.field, isEqualTo: filter.value);
            break;
          case FilterOperator.isNotEqualTo:
            query = query.where(filter.field, isNotEqualTo: filter.value);
            break;
          case FilterOperator.isLessThan:
            query = query.where(filter.field, isLessThan: filter.value);
            break;
          case FilterOperator.isLessThanOrEqualTo:
            query =
                query.where(filter.field, isLessThanOrEqualTo: filter.value);
            break;
          case FilterOperator.isGreaterThan:
            query = query.where(filter.field, isGreaterThan: filter.value);
            break;
          case FilterOperator.isGreaterThanOrEqualTo:
            query = query.where(filter.field,
                isGreaterThanOrEqualTo: filter.value);
            break;
          case FilterOperator.arrayContains:
            query = query.where(filter.field, arrayContains: filter.value);
            break;
          case FilterOperator.arrayContainsAny:
            query = query.where(filter.field, arrayContainsAny: filter.value);
            break;
          case FilterOperator.whereIn:
            query = query.where(filter.field, whereIn: filter.value);
            break;
        }
      }
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }

  /// Belge stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDocument({
    required String collection,
    required String docId,
  }) {
    return _firestore.collection(collection).doc(docId).snapshots();
  }

  /// Batch yazma
  Future<void> batchWrite(
      List<BatchOperation> operations) async {
    final batch = _firestore.batch();

    for (final op in operations) {
      final docRef = _firestore.collection(op.collection).doc(op.docId);
      switch (op.type) {
        case BatchType.set:
          batch.set(docRef, op.data!);
          break;
        case BatchType.update:
          batch.update(docRef, op.data!);
          break;
        case BatchType.delete:
          batch.delete(docRef);
          break;
      }
    }

    await batch.commit();
  }
}

/// Filtre operatörleri
enum FilterOperator {
  isEqualTo,
  isNotEqualTo,
  isLessThan,
  isLessThanOrEqualTo,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  arrayContains,
  arrayContainsAny,
  whereIn,
}

/// Sorgu filtresi
class QueryFilter {
  final String field;
  final FilterOperator operator;
  final dynamic value;

  const QueryFilter({
    required this.field,
    required this.operator,
    required this.value,
  });
}

/// Batch operasyon tipleri
enum BatchType { set, update, delete }

/// Batch operasyonu
class BatchOperation {
  final String collection;
  final String docId;
  final BatchType type;
  final Map<String, dynamic>? data;

  const BatchOperation({
    required this.collection,
    required this.docId,
    required this.type,
    this.data,
  });
}
