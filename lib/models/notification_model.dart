enum AppNotificationType {
  system,
  friendRequestReceived,
  friendRequestAccepted,
  matchCreated,
  messageReceived,
  activityJoinRequested,
  activityJoinAccepted,
  activityJoinDeclined,
  activityCancelled,
  activityReminder,
  activityUpdated,
  activityNewParticipant,
  signalNearby,
  verificationApproved,
  verificationRejected,
}

AppNotificationType _parseType(String? raw) {
  switch (raw) {
    case 'FriendRequestReceived':
      return AppNotificationType.friendRequestReceived;
    case 'FriendRequestAccepted':
      return AppNotificationType.friendRequestAccepted;
    case 'MatchCreated':
      return AppNotificationType.matchCreated;
    case 'MessageReceived':
      return AppNotificationType.messageReceived;
    case 'ActivityJoinRequested':
      return AppNotificationType.activityJoinRequested;
    case 'ActivityJoinAccepted':
      return AppNotificationType.activityJoinAccepted;
    case 'ActivityJoinDeclined':
      return AppNotificationType.activityJoinDeclined;
    case 'ActivityCancelled':
      return AppNotificationType.activityCancelled;
    case 'ActivityReminder':
      return AppNotificationType.activityReminder;
    case 'ActivityUpdated':
      return AppNotificationType.activityUpdated;
    case 'ActivityNewParticipant':
      return AppNotificationType.activityNewParticipant;
    case 'SignalNearby':
      return AppNotificationType.signalNearby;
    case 'VerificationApproved':
      return AppNotificationType.verificationApproved;
    case 'VerificationRejected':
      return AppNotificationType.verificationRejected;
    default:
      return AppNotificationType.system;
  }
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.deepLink,
    this.relatedEntityType,
    this.relatedEntityId,
    this.actor,
    this.readAt,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final String? deepLink;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final Map<String, dynamic>? actor;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: (map['id'] ?? '').toString(),
      type: _parseType(map['type']?.toString()),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      deepLink: _nullableString(map['deepLink']),
      relatedEntityType: _nullableString(map['relatedEntityType']),
      relatedEntityId: _nullableString(map['relatedEntityId']),
      actor: map['actor'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['actor'] as Map)
          : (map['actor'] is Map
              ? Map<String, dynamic>.from(map['actor'] as Map)
              : null),
      isRead: map['isRead'] == true,
      readAt: _parseDate(map['readAt']),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead, DateTime? readAt}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      deepLink: deepLink,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      actor: actor,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String? _nullableString(dynamic value) {
  final s = value?.toString();
  if (s == null || s.isEmpty) return null;
  return s;
}
