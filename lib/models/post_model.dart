class PostModel {
  final String id;
  final String userId;
  final String userDisplayName;
  final String userProfilePhotoUrl;
  final String text;
  final String location;
  final String placeId;
  final double? lat;
  final double? lng;
  final List<String> photoUrls;
  final String? videoUrl;
  final double rating;
  final String vibeTag;
  final List<String> likes;
  final int likesCountValue;
  final int commentsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String type;
  final bool likedByCurrentUser;
  final bool savedByCurrentUser;
  final String userMode;
  final double? distanceMeters;

  PostModel({
    required this.id,
    required this.userId,
    this.userDisplayName = '',
    this.userProfilePhotoUrl = '',
    required this.text,
    this.location = '',
    this.placeId = '',
    this.lat,
    this.lng,
    this.photoUrls = const [],
    this.videoUrl,
    this.rating = 0,
    this.vibeTag = '',
    this.likes = const [],
    this.likesCountValue = 0,
    this.commentsCount = 0,
    this.createdAt,
    this.updatedAt,
    this.type = 'post',
    this.likedByCurrentUser = false,
    this.savedByCurrentUser = false,
    this.userMode = '',
    this.distanceMeters,
  });

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    final likesCount = _toInt(map['likesCount']);
    final likedByCurrentUser = map['likedByCurrentUser'] ?? false;
    final likesList = _toStringList(map['likes']);

    return PostModel(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      userDisplayName: (map['userDisplayName'] ?? '').toString(),
      userProfilePhotoUrl: (map['userProfilePhotoUrl'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      placeId: (map['placeId'] ?? '').toString(),
      lat: _toDoubleOrNull(map['lat'] ?? map['latitude']),
      lng: _toDoubleOrNull(map['lng'] ?? map['longitude']),
      photoUrls: _toStringList(map['photoUrls']),
      videoUrl: _nullableString(map['videoUrl']),
      rating: _toDouble(map['rating']),
      vibeTag: (map['vibeTag'] ?? '').toString(),
      likes: likesList.isNotEmpty
          ? likesList
          : const [],
      likesCountValue: likesCount,
      commentsCount: _toInt(map['commentsCount']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      type: (map['type'] ?? 'post').toString(),
      likedByCurrentUser: likedByCurrentUser,
      savedByCurrentUser: map['savedByCurrentUser'] ?? false,
      userMode: (map['userMode'] ?? '').toString(),
      distanceMeters: _toDoubleOrNull(map['distanceMeters']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userProfilePhotoUrl': userProfilePhotoUrl,
      'text': text,
      'location': location,
      'placeId': placeId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'photoUrls': photoUrls,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'rating': rating,
      'vibeTag': vibeTag,
      'likes': likes,
      'likesCount': likesCountValue,
      'commentsCount': commentsCount,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'type': type,
      'userMode': userMode,
      if (distanceMeters != null) 'distanceMeters': distanceMeters,
    };
  }

  bool isLikedBy(String uid) => likedByCurrentUser || likes.contains(uid);
  int get likesCount => likesCountValue;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }
  return const [];
}

String? _nullableString(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _toDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
