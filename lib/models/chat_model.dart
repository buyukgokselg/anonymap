import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastMessageTime;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final bool isTemporary;
  final bool isFriendChat;
  final Map<String, int> unreadCount;
  final Map<String, bool> typing;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage = '',
    this.lastSenderId = '',
    this.lastMessageTime,
    this.createdAt,
    this.expiresAt,
    this.isTemporary = true,
    this.isFriendChat = false,
    this.unreadCount = const {},
    this.typing = const {},
  });

  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastSenderId: map['lastSenderId'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      isTemporary: map['isTemporary'] ?? true,
      isFriendChat: map['isFriendChat'] ?? false,
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      typing: Map<String, bool>.from(map['typing'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isTemporary': isTemporary,
      'isFriendChat': isFriendChat,
      'unreadCount': unreadCount,
      'typing': typing,
    };
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