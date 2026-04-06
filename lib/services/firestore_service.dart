import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/match_model.dart';
import '../models/post_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ══════════════════════════════════════
  // KULLANICI İŞLEMLERİ
  // ══════════════════════════════════════

  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String gender,
    required int age,
    required String purpose,
    required List<String> interests,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      final user = UserModel(
        uid: uid,
        email: email,
        gender: gender,
        age: age,
        purpose: purpose,
        interests: interests,
      );
      await userRef.set(user.toMap());
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!);
    });
  }

Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
  if (uid.isEmpty) {
    throw Exception('Geçersiz kullanıcı uid');
  }

  final cleanedData = <String, dynamic>{};

  data.forEach((key, value) {
    if (value is String) {
      cleanedData[key] = value.trim();
    } else {
      cleanedData[key] = value;
    }
  });

  await _db.collection('users').doc(uid).set(
    {
      ...cleanedData,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}

  Future<void> updateMode(String uid, String mode) async {
    await _db.collection('users').doc(uid).update({'mode': mode});
  }

  Future<void> updateVisibility(String uid, bool isVisible) async {
    await _db.collection('users').doc(uid).update({'isVisible': isVisible});
  }

  Future<void> updateLocation(String uid, double lat, double lng) async {
    if (uid.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).set({
        'location': GeoPoint(lat, lng),
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('updateLocation: $e\n$st');
    }
  }

  Future<void> setOnlineStatus(String uid, bool isOnline) async {
    await _db.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUserProfile(String uid) async {
    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(uid));

    final followers = await _db
        .collection('users')
        .doc(uid)
        .collection('followers')
        .get();
    for (final doc in followers.docs) {
      batch.delete(doc.reference);
    }

    final following = await _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .get();
    for (final doc in following.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ══════════════════════════════════════
  // YAKIN KULLANICILAR
  // ══════════════════════════════════════

  Stream<QuerySnapshot> getNearbyUsers(String uid) {
    return _db
        .collection('users')
        .where('isVisible', isEqualTo: true)
        .where('isOnline', isEqualTo: true)
        .snapshots();
  }

  Future<List<UserModel>> getNearbyUsersList(
    String uid,
    double lat,
    double lng, {
    double radiusKm = 1.0,
  }) async {
    final latRange = radiusKm / 111.0;
    final lngRange = radiusKm / (111.0 * 0.7);

    final query = await _db
        .collection('users')
        .where('isVisible', isEqualTo: true)
        .where('isOnline', isEqualTo: true)
        .get();

    final users = <UserModel>[];
    for (final doc in query.docs) {
      if (doc.id == uid) continue;

      final data = doc.data();
      final loc = data['location'] as GeoPoint?;
      if (loc == null) continue;

      if ((loc.latitude - lat).abs() <= latRange &&
          (loc.longitude - lng).abs() <= lngRange) {
        users.add(UserModel.fromMap(data));
      }
    }

    return users;
  }

  // ══════════════════════════════════════
  // TAKİP SİSTEMİ
  // ══════════════════════════════════════

  Future<void> followUser(String myUid, String targetUid) async {
    final batch = _db.batch();

    batch.set(
      _db.collection('users').doc(myUid).collection('following').doc(targetUid),
      {'uid': targetUid, 'createdAt': FieldValue.serverTimestamp()},
    );

    batch.set(
      _db.collection('users').doc(targetUid).collection('followers').doc(myUid),
      {'uid': myUid, 'createdAt': FieldValue.serverTimestamp()},
    );

    batch.update(_db.collection('users').doc(myUid), {
      'followingCount': FieldValue.increment(1),
    });
    batch.update(_db.collection('users').doc(targetUid), {
      'followersCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> unfollowUser(String myUid, String targetUid) async {
    final batch = _db.batch();

    batch.delete(
      _db.collection('users').doc(myUid).collection('following').doc(targetUid),
    );
    batch.delete(
      _db.collection('users').doc(targetUid).collection('followers').doc(myUid),
    );

    batch.update(_db.collection('users').doc(myUid), {
      'followingCount': FieldValue.increment(-1),
    });
    batch.update(_db.collection('users').doc(targetUid), {
      'followersCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  Future<bool> isFollowing(String myUid, String targetUid) async {
    final doc = await _db
        .collection('users')
        .doc(myUid)
        .collection('following')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  Stream<List<UserModel>> getFollowers(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('followers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final users = <UserModel>[];
      for (final doc in snapshot.docs) {
        final user = await getUser(doc.id);
        if (user != null) users.add(user);
      }
      return users;
    });
  }

  Stream<List<UserModel>> getFollowing(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final users = <UserModel>[];
      for (final doc in snapshot.docs) {
        final user = await getUser(doc.id);
        if (user != null) users.add(user);
      }
      return users;
    });
  }

  // ══════════════════════════════════════
  // ARKADAŞ SİSTEMİ
  // ══════════════════════════════════════

  Future<void> sendFriendRequest(String myUid, String targetUid) async {
    await _db.collection('friend_requests').add({
      'from': myUid,
      'to': targetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptFriendRequest(
    String requestId,
    String myUid,
    String fromUid,
  ) async {
    final batch = _db.batch();

    batch.update(_db.collection('friend_requests').doc(requestId), {
      'status': 'accepted',
    });

    batch.set(
      _db.collection('users').doc(myUid).collection('friends').doc(fromUid),
      {'uid': fromUid, 'since': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db.collection('users').doc(fromUid).collection('friends').doc(myUid),
      {'uid': myUid, 'since': FieldValue.serverTimestamp()},
    );

    batch.update(_db.collection('users').doc(myUid), {
      'friendsCount': FieldValue.increment(1),
    });
    batch.update(_db.collection('users').doc(fromUid), {
      'friendsCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).update({
      'status': 'declined',
    });
  }

  Stream<QuerySnapshot> getPendingFriendRequests(String uid) {
    return _db
        .collection('friend_requests')
        .where('to', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<bool> isFriend(String myUid, String targetUid) async {
    final doc = await _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  Future<List<UserModel>> getFriendsList(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .orderBy('since', descending: true)
        .get();

    final users = <UserModel>[];
    for (final doc in snapshot.docs) {
      final user = await getUser(doc.id);
      if (user != null) {
        users.add(user);
      }
    }
    return users;
  }

  // ══════════════════════════════════════
  // CHAT SİSTEMİ
  // ══════════════════════════════════════

  Future<ChatModel> createChat(
    String myUid,
    String otherUid, {
    bool isTemporary = true,
  }) async {
    final existing = await _db
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .get();

    for (final doc in existing.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(otherUid)) {
        return ChatModel.fromMap(doc.id, doc.data());
      }
    }

    final chatData = <String, dynamic>{
      'participants': [myUid, otherUid],
      'lastMessage': '',
      'lastSenderId': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'isTemporary': isTemporary,
      'isFriendChat': false,
      'unreadCount': {myUid: 0, otherUid: 0},
      'typing': {myUid: false, otherUid: false},
    };

    if (isTemporary) {
      chatData['expiresAt'] = Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      );
    }

    final docRef = await _db.collection('chats').add(chatData);
    final doc = await docRef.get();
    return ChatModel.fromMap(doc.id, doc.data()!);
  }

  Stream<List<ChatModel>> getChats(String uid) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> sendMessage(String chatId, MessageModel message) async {
    final batch = _db.batch();

    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    batch.set(msgRef, message.toMap());

    batch.update(_db.collection('chats').doc(chatId), {
      'lastMessage': message.text,
      'lastSenderId': message.senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> updateMessageStatus(
    String chatId,
    String messageId,
    MessageStatus status,
  ) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'status': status.name});
  }

  Future<void> addReaction(
    String chatId,
    String messageId,
    String? reaction,
  ) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'reaction': reaction});
  }

  Future<void> setTyping(String chatId, String uid, bool isTyping) async {
    await _db.collection('chats').doc(chatId).update({'typing.$uid': isTyping});
  }

  Future<void> markChatAsRead(String chatId, String uid) async {
    await _db.collection('chats').doc(chatId).update({'unreadCount.$uid': 0});
  }

  Future<void> convertToFriendChat(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'isTemporary': false,
      'isFriendChat': true,
      'expiresAt': null,
    });
  }

  Future<void> deleteChat(String chatId) async {
    final messages = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _db.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('chats').doc(chatId));

    await batch.commit();
  }

  // ══════════════════════════════════════
  // EŞLEŞME SİSTEMİ
  // ══════════════════════════════════════

  Future<MatchModel> createMatch(
    String userId1,
    String userId2,
    int compatibility,
    List<String> commonInterests,
  ) async {
    final matchData = MatchModel(
      id: '',
      userId1: userId1,
      userId2: userId2,
      compatibility: compatibility,
      commonInterests: commonInterests,
    );

    final docRef = await _db.collection('matches').add(matchData.toMap());
    final doc = await docRef.get();
    return MatchModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> respondToMatch(
    String matchId,
    MatchStatus status, {
    String? chatId,
  }) async {
    final data = <String, dynamic>{
      'status': status.name,
      'respondedAt': FieldValue.serverTimestamp(),
    };
    if (chatId != null) data['chatId'] = chatId;

    await _db.collection('matches').doc(matchId).update(data);
  }

  Stream<List<MatchModel>> getPendingMatches(String uid) {
    return _db
        .collection('matches')
        .where('userId2', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) => s.docs.map((d) => MatchModel.fromMap(d.id, d.data())).toList(),
        );
  }

  // ══════════════════════════════════════
  // PAYLAŞIM SİSTEMİ
  // ══════════════════════════════════════

  Future<void> createPost(PostModel post) async {
    await _db.collection('posts').add(post.toMap());
    await _db.collection('users').doc(post.userId).update({
      'vibeTagsCreated': FieldValue.increment(1),
    });
  }

  Stream<List<PostModel>> getFeedPosts({String? vibeTag}) {
    Query query = _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(20);

    if (vibeTag != null) {
      query = query.where('vibeTag', isEqualTo: vibeTag);
    }

    return query.snapshots().map(
          (s) => s.docs
              .map(
                (d) => PostModel.fromMap(
                  d.id,
                  d.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  Future<void> toggleLike(String postId, String uid) async {
    final postRef = _db.collection('posts').doc(postId);
    final doc = await postRef.get();
    if (!doc.exists) return;

    final likes = List<String>.from(doc.data()?['likes'] ?? []);
    if (likes.contains(uid)) {
      likes.remove(uid);
    } else {
      likes.add(uid);
    }

    await postRef.update({'likes': likes});
  }

  // ══════════════════════════════════════
  // PULSE SCORE
  // ══════════════════════════════════════

  Future<void> incrementPulseScore(String uid, int amount) async {
    await _db.collection('users').doc(uid).update({
      'pulseScore': FieldValue.increment(amount),
    });
  }

  Future<void> incrementPlacesVisited(String uid) async {
    await _db.collection('users').doc(uid).update({
      'placesVisited': FieldValue.increment(1),
    });
  }

  // ══════════════════════════════════════
  // ENGELLEME
  // ══════════════════════════════════════

  Future<void> blockUser(String myUid, String targetUid) async {
    final batch = _db.batch();

    batch.set(
      _db.collection('users').doc(myUid).collection('blocked').doc(targetUid),
      {'uid': targetUid, 'createdAt': FieldValue.serverTimestamp()},
    );

    batch.delete(
      _db.collection('users').doc(myUid).collection('friends').doc(targetUid),
    );
    batch.delete(
      _db.collection('users').doc(targetUid).collection('friends').doc(myUid),
    );

    batch.delete(
      _db.collection('users').doc(myUid).collection('following').doc(targetUid),
    );
    batch.delete(
      _db.collection('users').doc(targetUid).collection('followers').doc(myUid),
    );
    batch.delete(
      _db.collection('users').doc(myUid).collection('followers').doc(targetUid),
    );
    batch.delete(
      _db.collection('users').doc(targetUid).collection('following').doc(myUid),
    );

    await batch.commit();

    final chats = await _db
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .get();

    for (final doc in chats.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(targetUid)) {
        await deleteChat(doc.id);
      }
    }
  }

  Future<bool> isBlocked(String myUid, String targetUid) async {
    final doc = await _db
        .collection('users')
        .doc(myUid)
        .collection('blocked')
        .doc(targetUid)
        .get();
    return doc.exists;
  }
}