import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, photo, location, disappearing, photoRequest, system }
enum MessageStatus { sent, delivered, read }

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final MessageStatus status;
  final DateTime? createdAt;
  final String? photoUrl;
  final double? latitude;
  final double? longitude;
  final bool? photoApproved;
  final String? reaction;
  final int? disappearSeconds;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.createdAt,
    this.photoUrl,
    this.latitude,
    this.longitude,
    this.photoApproved,
    this.reaction,
    this.disappearSeconds,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      photoUrl: map['photoUrl'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      photoApproved: map['photoApproved'],
      reaction: map['reaction'],
      disappearSeconds: map['disappearSeconds'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type.name,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (photoApproved != null) 'photoApproved': photoApproved,
      if (reaction != null) 'reaction': reaction,
      if (disappearSeconds != null) 'disappearSeconds': disappearSeconds,
    };
  }

  bool get isMe => false; // Ekranda uid ile karşılaştırılacak
  bool get isPhoto => type == MessageType.photo;
  bool get isLocation => type == MessageType.location;
  bool get isDisappearing => type == MessageType.disappearing;
  bool get isPhotoRequest => type == MessageType.photoRequest;
  bool get isSystem => type == MessageType.system;
}