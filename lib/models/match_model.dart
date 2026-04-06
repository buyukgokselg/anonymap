import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus { pending, accepted, declined, expired }

class MatchModel {
  final String id;
  final String userId1;
  final String userId2;
  final int compatibility;
  final List<String> commonInterests;
  final MatchStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final String? chatId;

  MatchModel({
    required this.id,
    required this.userId1,
    required this.userId2,
    this.compatibility = 0,
    this.commonInterests = const [],
    this.status = MatchStatus.pending,
    this.createdAt,
    this.respondedAt,
    this.chatId,
  });

  factory MatchModel.fromMap(String id, Map<String, dynamic> map) {
    return MatchModel(
      id: id,
      userId1: map['userId1'] ?? '',
      userId2: map['userId2'] ?? '',
      compatibility: map['compatibility'] ?? 0,
      commonInterests: List<String>.from(map['commonInterests'] ?? []),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => MatchStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
      chatId: map['chatId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId1': userId1,
      'userId2': userId2,
      'compatibility': compatibility,
      'commonInterests': commonInterests,
      'status': status.name,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      if (chatId != null) 'chatId': chatId,
    };
  }

  String otherUser(String myUid) {
    return userId1 == myUid ? userId2 : userId1;
  }
}