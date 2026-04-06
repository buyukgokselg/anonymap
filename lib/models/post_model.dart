import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String text;
  final String location;
  final double? lat;
  final double? lng;
  final List<String> photoUrls;
  final String? videoUrl;
  final double rating;
  final String vibeTag;
  final List<String> likes;
  final int commentsCount;
  final DateTime? createdAt;
  final String type; // 'post' veya 'short'

  PostModel({
    required this.id,
    required this.userId,
    required this.text,
    this.location = '',
    this.lat,
    this.lng,
    this.photoUrls = const [],
    this.videoUrl,
    this.rating = 0,
    this.vibeTag = '',
    this.likes = const [],
    this.commentsCount = 0,
    this.createdAt,
    this.type = 'post',
  });

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    return PostModel(
      id: id,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      location: map['location'] ?? '',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      videoUrl: map['videoUrl'],
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      vibeTag: map['vibeTag'] ?? '',
      likes: List<String>.from(map['likes'] ?? []),
      commentsCount: map['commentsCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      type: map['type'] ?? 'post',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      'location': location,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'photoUrls': photoUrls,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'rating': rating,
      'vibeTag': vibeTag,
      'likes': likes,
      'commentsCount': commentsCount,
      'createdAt': FieldValue.serverTimestamp(),
      'type': type,
    };
  }

  bool isLikedBy(String uid) => likes.contains(uid);
  int get likesCount => likes.length;
}