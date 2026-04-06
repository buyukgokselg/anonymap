import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String bio;
  final String city;
  final String website;
  final String gender;
  final int age;
  final String purpose;
  final List<String> interests;
  final String mode;
  final String privacyLevel;
  final bool isVisible;
  final bool isOnline;
  final String profilePhotoUrl;
  final List<String> photoUrls;
  final GeoPoint? location;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final int followersCount;
  final int followingCount;
  final int friendsCount;
  final int pulseScore;
  final int placesVisited;
  final int vibeTagsCreated;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.bio = '',
    this.city = '',
    this.website = '',
    this.gender = '',
    this.age = 0,
    this.purpose = '',
    this.interests = const [],
    this.mode = 'kesif',
    this.privacyLevel = 'full',
    this.isVisible = true,
    this.isOnline = false,
    this.profilePhotoUrl = '',
    this.photoUrls = const [],
    this.location,
    this.lastSeen,
    this.createdAt,
    this.followersCount = 0,
    this.followingCount = 0,
    this.friendsCount = 0,
    this.pulseScore = 0,
    this.placesVisited = 0,
    this.vibeTagsCreated = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      bio: map['bio'] ?? '',
      city: map['city'] ?? '',
      website: map['website'] ?? '',
      gender: map['gender'] ?? '',
      age: map['age'] ?? 0,
      purpose: map['purpose'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      mode: map['mode'] ?? 'kesif',
      privacyLevel: map['privacyLevel'] ?? 'full',
      isVisible: map['isVisible'] ?? true,
      isOnline: map['isOnline'] ?? false,
      profilePhotoUrl: map['profilePhotoUrl'] ?? '',
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      location: map['location'],
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      friendsCount: map['friendsCount'] ?? 0,
      pulseScore: map['pulseScore'] ?? 0,
      placesVisited: map['placesVisited'] ?? 0,
      vibeTagsCreated: map['vibeTagsCreated'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'bio': bio,
      'city': city,
      'website': website,
      'gender': gender,
      'age': age,
      'purpose': purpose,
      'interests': interests,
      'mode': mode,
      'privacyLevel': privacyLevel,
      'isVisible': isVisible,
      'isOnline': isOnline,
      'profilePhotoUrl': profilePhotoUrl,
      'photoUrls': photoUrls,
      'location': location,
      'lastSeen': FieldValue.serverTimestamp(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'followersCount': followersCount,
      'followingCount': followingCount,
      'friendsCount': friendsCount,
      'pulseScore': pulseScore,
      'placesVisited': placesVisited,
      'vibeTagsCreated': vibeTagsCreated,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? bio,
    String? city,
    String? website,
    String? mode,
    String? privacyLevel,
    bool? isVisible,
    bool? isOnline,
    String? profilePhotoUrl,
    List<String>? photoUrls,
    GeoPoint? location,
    int? followersCount,
    int? followingCount,
    int? friendsCount,
    int? pulseScore,
    int? placesVisited,
    int? vibeTagsCreated,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      website: website ?? this.website,
      gender: gender,
      age: age,
      purpose: purpose,
      interests: interests,
      mode: mode ?? this.mode,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      isVisible: isVisible ?? this.isVisible,
      isOnline: isOnline ?? this.isOnline,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      location: location ?? this.location,
      lastSeen: lastSeen,
      createdAt: createdAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      friendsCount: friendsCount ?? this.friendsCount,
      pulseScore: pulseScore ?? this.pulseScore,
      placesVisited: placesVisited ?? this.placesVisited,
      vibeTagsCreated: vibeTagsCreated ?? this.vibeTagsCreated,
    );
  }

  String get username => email.split('@').first;
  bool get hasProfile => displayName.isNotEmpty;
  bool get isGhostMode => privacyLevel == 'ghost';
}