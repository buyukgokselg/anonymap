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
  final Map<String, dynamic>? user1;
  final Map<String, dynamic>? user2;
  final bool initiator1AnonymousInChat;
  final bool responder2AnonymousInChat;

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
    this.user1,
    this.user2,
    this.initiator1AnonymousInChat = false,
    this.responder2AnonymousInChat = false,
  });

  factory MatchModel.fromMap(String id, Map<String, dynamic> map) {
    return MatchModel(
      id: id,
      userId1: (map['userId1'] ?? '').toString(),
      userId2: (map['userId2'] ?? '').toString(),
      compatibility: _toInt(map['compatibility']),
      commonInterests: _toStringList(map['commonInterests']),
      status: MatchStatus.values.firstWhere(
        (item) =>
            item.name.toLowerCase() ==
            (map['status'] ?? 'pending').toString().toLowerCase(),
        orElse: () => MatchStatus.pending,
      ),
      createdAt: _parseDate(map['createdAt']),
      respondedAt: _parseDate(map['respondedAt']),
      chatId: _nullableString(map['chatId']),
      user1: map['user1'] is Map<String, dynamic> ? map['user1'] : null,
      user2: map['user2'] is Map<String, dynamic> ? map['user2'] : null,
      initiator1AnonymousInChat: map['initiator1AnonymousInChat'] == true,
      responder2AnonymousInChat: map['responder2AnonymousInChat'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId1': userId1,
      'userId2': userId2,
      'compatibility': compatibility,
      'commonInterests': commonInterests,
      'status': status.name,
      'createdAt': createdAt?.toIso8601String(),
      if (respondedAt != null) 'respondedAt': respondedAt!.toIso8601String(),
      if (chatId != null) 'chatId': chatId,
      if (user1 != null) 'user1': user1,
      if (user2 != null) 'user2': user2,
      'initiator1AnonymousInChat': initiator1AnonymousInChat,
      'responder2AnonymousInChat': responder2AnonymousInChat,
    };
  }

  String otherUser(String myUid) {
    return userId1 == myUid ? userId2 : userId1;
  }

  Map<String, dynamic>? otherUserData(String myUid) {
    return userId1 == myUid ? user2 : user1;
  }

  bool get isInitiatorAnonymous => initiator1AnonymousInChat;
  bool get isResponderAnonymous => responder2AnonymousInChat;

  /// Returns true if the *other* user (not me) is anonymous in chat.
  bool isOtherAnonymous(String myUid) {
    return userId1 == myUid
        ? responder2AnonymousInChat
        : initiator1AnonymousInChat;
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

String? _nullableString(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}
