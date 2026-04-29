enum MessageType {
  text,
  photo,
  video,
  location,
  postShare,
  disappearing,
  photoRequest,
  system,
}

enum MessageStatus { sent, delivered, read }

class MessageModel {
  final String id;
  final String senderId;
  final String senderDisplayName;
  final String senderProfilePhotoUrl;
  final String text;
  final MessageType type;
  final MessageStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool deletedForEveryone;
  final String? photoUrl;
  final String? videoUrl;
  final double? latitude;
  final double? longitude;
  final bool? photoApproved;
  final String? reaction;
  final int? disappearSeconds;
  final String? sharedPostId;
  final String? sharedPostAuthor;
  final String? sharedPostLocation;
  final String? sharedPostVibe;
  final String? sharedPostMediaUrl;

  /// Backend-issued activity id when this message is an "etkinliğe davet".
  /// Cache fields below let chat render a rich pill without round-tripping
  /// to the activities API on every render.
  final String? activityInviteId;
  final String? activityTitle;
  final String? activityLocationName;
  final DateTime? activityStartsAt;
  final String? activityCategory;

  MessageModel({
    required this.id,
    required this.senderId,
    this.senderDisplayName = '',
    this.senderProfilePhotoUrl = '',
    required this.text,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.deletedForEveryone = false,
    this.photoUrl,
    this.videoUrl,
    this.latitude,
    this.longitude,
    this.photoApproved,
    this.reaction,
    this.disappearSeconds,
    this.sharedPostId,
    this.sharedPostAuthor,
    this.sharedPostLocation,
    this.sharedPostVibe,
    this.sharedPostMediaUrl,
    this.activityInviteId,
    this.activityTitle,
    this.activityLocationName,
    this.activityStartsAt,
    this.activityCategory,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: (map['senderId'] ?? '').toString(),
      senderDisplayName: (map['senderDisplayName'] ?? '').toString(),
      senderProfilePhotoUrl: (map['senderProfilePhotoUrl'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      type: _parseType(map['type']),
      status: _parseStatus(map['status']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      deletedAt: _parseDate(map['deletedAt']),
      deletedForEveryone: map['deletedForEveryone'] == true,
      photoUrl: _nullableString(map['photoUrl']),
      videoUrl: _nullableString(map['videoUrl']),
      latitude: _toDoubleOrNull(map['latitude']),
      longitude: _toDoubleOrNull(map['longitude']),
      photoApproved: map['photoApproved'] is bool ? map['photoApproved'] : null,
      reaction: _nullableString(map['reaction']),
      disappearSeconds: _toIntOrNull(map['disappearSeconds']),
      sharedPostId: _nullableString(map['sharedPostId']),
      sharedPostAuthor: _nullableString(map['sharedPostAuthor']),
      sharedPostLocation: _nullableString(map['sharedPostLocation']),
      sharedPostVibe: _nullableString(map['sharedPostVibe']),
      sharedPostMediaUrl: _nullableString(map['sharedPostMediaUrl']),
      activityInviteId: _nullableString(map['activityInviteId']),
      activityTitle: _nullableString(map['activityTitle']),
      activityLocationName: _nullableString(map['activityLocationName']),
      activityStartsAt: _parseDate(map['activityStartsAt']),
      activityCategory: _nullableString(map['activityCategory']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderDisplayName': senderDisplayName,
      'senderProfilePhotoUrl': senderProfilePhotoUrl,
      'text': text,
      'type': type.name,
      'status': status.name,
      'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt?.toIso8601String(),
      'deletedForEveryone': deletedForEveryone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (photoApproved != null) 'photoApproved': photoApproved,
      if (reaction != null) 'reaction': reaction,
      if (disappearSeconds != null) 'disappearSeconds': disappearSeconds,
      if (sharedPostId != null) 'sharedPostId': sharedPostId,
      if (sharedPostAuthor != null) 'sharedPostAuthor': sharedPostAuthor,
      if (sharedPostLocation != null) 'sharedPostLocation': sharedPostLocation,
      if (sharedPostVibe != null) 'sharedPostVibe': sharedPostVibe,
      if (sharedPostMediaUrl != null) 'sharedPostMediaUrl': sharedPostMediaUrl,
      if (activityInviteId != null) 'activityInviteId': activityInviteId,
      if (activityTitle != null) 'activityTitle': activityTitle,
      if (activityLocationName != null)
        'activityLocationName': activityLocationName,
      if (activityStartsAt != null)
        'activityStartsAt': activityStartsAt!.toIso8601String(),
      if (activityCategory != null) 'activityCategory': activityCategory,
    };
  }

  bool get isMe => false;
  bool get isPhoto => type == MessageType.photo;
  bool get isVideo => type == MessageType.video;
  bool get isLocation => type == MessageType.location;
  bool get isPostShare => type == MessageType.postShare;
  bool get isDisappearing => type == MessageType.disappearing;
  bool get isPhotoRequest => type == MessageType.photoRequest;
  bool get isSystem => type == MessageType.system;
  bool get isActivityInvite =>
      activityInviteId != null && activityInviteId!.isNotEmpty;
  bool get isDeleted => deletedForEveryone || deletedAt != null;
}

MessageType _parseType(dynamic value) {
  final raw = value?.toString().trim() ?? 'text';
  return MessageType.values.firstWhere(
    (item) => item.name.toLowerCase() == raw.toLowerCase(),
    orElse: () => MessageType.text,
  );
}

MessageStatus _parseStatus(dynamic value) {
  final raw = value?.toString().trim() ?? 'sent';
  return MessageStatus.values.firstWhere(
    (item) => item.name.toLowerCase() == raw.toLowerCase(),
    orElse: () => MessageStatus.sent,
  );
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String? _nullableString(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}

double? _toDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _toIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
