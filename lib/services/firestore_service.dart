import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Kullanıcı profili oluştur
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String gender,
    required int age,
    required String purpose,
    required List<String> interests,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'gender': gender,
      'age': age,
      'purpose': purpose,
      'interests': interests,
      'mode': 'Sosyal',
      'isVisible': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Kullanıcı profilini getir
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // Modu güncelle
  Future<void> updateMode(String uid, String mode) async {
    await _db.collection('users').doc(uid).update({'mode': mode});
  }

  // Görünürlüğü güncelle
  Future<void> updateVisibility(String uid, bool isVisible) async {
    await _db.collection('users').doc(uid).update({'isVisible': isVisible});
  }

  // Konumu güncelle (belge yoksa update patlamasın diye merge set)
  Future<void> updateLocation(String uid, double lat, double lng) async {
    if (uid.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).set(
        {
          'location': GeoPoint(lat, lng),
          'lastSeen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, st) {
      debugPrint('FirestoreService.updateLocation: $e\n$st');
    }
  }

  // Bölgedeki aktif kullanıcıları getir
  Stream<QuerySnapshot> getNearbyUsers(String uid) {
  return _db
      .collection('users')
      .where('isVisible', isEqualTo: true)
      .where('uid', isNotEqualTo: uid)
      .snapshots();
}

  // Profili güncelle
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // Hesabı sil
  Future<void> deleteUserProfile(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }
}