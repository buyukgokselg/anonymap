class ChatModel {
  final String id;
  final List<String> participants;
  final String createdByUserId;
  final String directMessageKey;
  final bool isArchived;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastMessageTime;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final bool isTemporary;
  final bool isFriendChat;
  final Map<String, int> unreadCount;
  final Map<String, bool> typing;
  final String? pendingFriendRequestFromUserId;

  /// "direct" = 1:1 chat, "activity" = aktivite grup sohbeti.
  final String kind;

  /// Activity grup sohbeti için kaynak aktivite id'si.
  final String? activityId;

  /// Activity grup sohbeti için başlık (yoksa boş).
  final String title;

  bool get isActivityGroup => kind == 'activity' && activityId != null;

  ChatModel({
    required this.id,
    required this.participants,
    this.createdByUserId = '',
    this.directMessageKey = '',
    this.isArchived = false,
    this.lastMessage = '',
    this.lastSenderId = '',
    this.lastMessageTime,
    this.createdAt,
    this.expiresAt,
    this.isTemporary = true,
    this.isFriendChat = false,
    this.unreadCount = const {},
    this.typing = const {},
    this.pendingFriendRequestFromUserId,
    this.kind = 'direct',
    this.activityId,
    this.title = '',
  });

  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    final participantMaps = (map['participants'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final participantIds = participantMaps.isNotEmpty
        ? participantMaps
              .map((item) => (item['userId'] ?? item['uid'] ?? '').toString())
              .where((item) => item.isNotEmpty)
              .toList()
        : (map['participants'] as List? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList();

    final unreadMap = <String, int>{};
    final typingMap = <String, bool>{};

    if (participantMaps.isNotEmpty) {
      for (final participant in participantMaps) {
        final userId = (participant['userId'] ?? '').toString();
        if (userId.isEmpty) continue;
        unreadMap[userId] = _toInt(participant['unreadCount']);
        typingMap[userId] = participant['isTyping'] ?? false;
      }
    } else {
      final unread = map['unreadCount'];
      if (unread is Map) {
        unreadMap.addAll(
          unread.map(
            (key, value) => MapEntry(key.toString(), _toInt(value)),
          ),
        );
      }
      final typing = map['typing'];
      if (typing is Map) {
        typingMap.addAll(
          typing.map(
            (key, value) => MapEntry(key.toString(), value == true),
          ),
        );
      }
    }

    return ChatModel(
      id: id,
      participants: participantIds,
      createdByUserId: (map['createdByUserId'] ?? '').toString(),
      directMessageKey: (map['directMessageKey'] ?? '').toString(),
      isArchived: map['currentUserIsArchived'] == true || map['isArchived'] == true,
      lastMessage: (map['lastMessage'] ?? '').toString(),
      lastSenderId: (map['lastSenderId'] ?? '').toString(),
      lastMessageTime: _parseDate(map['lastMessageTime']),
      createdAt: _parseDate(map['createdAt']),
      expiresAt: _parseDate(map['expiresAt']),
      isTemporary: map['isTemporary'] ?? true,
      isFriendChat: map['isFriendChat'] ?? false,
      unreadCount: unreadMap,
      typing: typingMap,
      pendingFriendRequestFromUserId: map['pendingFriendRequestFromUserId']?.toString(),
      kind: (map['kind'] ?? 'direct').toString(),
      activityId: () {
        final raw = map['activityId']?.toString();
        return raw == null || raw.isEmpty ? null : raw;
      }(),
      title: (map['title'] ?? '').toString(),
    );
  }

  String otherParticipant(String myUid) {
    return participants.firstWhere((p) => p != myUid, orElse: () => '');
  }

  int myUnread(String myUid) => unreadCount[myUid] ?? 0;

  bool get isExpired {
    if (!isTemporary || expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Duration get timeRemaining {
    if (expiresAt == null) return Duration.zero;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
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
