import '../config/mode_config.dart';

class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint(this.latitude, this.longitude);

  factory GeoPoint.fromMap(Map<String, dynamic> map) {
    return GeoPoint(
      _toDouble(map['latitude'] ?? map['lat']),
      _toDouble(map['longitude'] ?? map['lng']),
    );
  }

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}

class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String userName;
  final String displayName;
  final String bio;
  final String city;
  final String website;
  final String gender;
  final DateTime? birthDate;
  final int age;
  final String purpose;
  final String matchPreference;
  final List<String> interests;
  final String mode;
  final String privacyLevel;
  final String preferredLanguage;
  final String locationGranularity;
  final bool enableDifferentialPrivacy;
  final int kAnonymityLevel;
  final bool allowAnalytics;
  final bool isVisible;
  final bool isOnline;
  final bool isSignalActive;
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

  /// Aktivite sonrası katılımcılardan aldığı puan ortalaması (0..5).
  final double activityRatingAverage;
  final int activityRatingCount;
  final String? pinnedPostId;
  final DateTime? pinnedAt;

  // ── Dating fields (Phase 2 pivot) ──
  final String orientation;
  final String relationshipIntent;
  final int? heightCm;
  final String drinkingStatus;
  final String smokingStatus;
  final bool isPhotoVerified;
  final Map<String, String> datingPrompts;
  final List<String> lookingForModes;
  final List<String> dealbreakers;
  final Map<String, bool> enabledFeatures;

  UserModel({
    required this.uid,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.userName = '',
    this.displayName = '',
    this.bio = '',
    this.city = '',
    this.website = '',
    this.gender = '',
    this.birthDate,
    this.age = 0,
    this.purpose = '',
    this.matchPreference = 'auto',
    this.interests = const [],
    this.mode = ModeConfig.defaultId,
    this.privacyLevel = 'full',
    this.preferredLanguage = 'tr',
    this.locationGranularity = 'nearby',
    this.enableDifferentialPrivacy = true,
    this.kAnonymityLevel = 3,
    this.allowAnalytics = true,
    this.isVisible = true,
    this.isOnline = false,
    this.isSignalActive = false,
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
    this.activityRatingAverage = 0,
    this.activityRatingCount = 0,
    this.pinnedPostId,
    this.pinnedAt,
    this.orientation = '',
    this.relationshipIntent = '',
    this.heightCm,
    this.drinkingStatus = '',
    this.smokingStatus = '',
    this.isPhotoVerified = false,
    this.datingPrompts = const {},
    this.lookingForModes = const [],
    this.dealbreakers = const [],
    this.enabledFeatures = const {},
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final locationMap = _extractLocation(map);
    final email = (map['email'] ?? '').toString();
    final resolvedUserName = (map['userName'] ?? map['username'] ?? '')
        .toString();

    return UserModel(
      uid: (map['uid'] ?? map['id'] ?? '').toString(),
      email: email,
      firstName: (map['firstName'] ?? '').toString(),
      lastName: (map['lastName'] ?? '').toString(),
      userName: resolvedUserName,
      displayName: (map['displayName'] ?? '').toString(),
      bio: (map['bio'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      website: (map['website'] ?? '').toString(),
      gender: (map['gender'] ?? '').toString(),
      birthDate: _parseDate(map['birthDate']),
      age: _toInt(map['age']),
      purpose: (map['purpose'] ?? '').toString(),
      matchPreference: (map['matchPreference'] ?? 'auto').toString(),
      interests: _toStringList(map['interests']),
      mode: ModeConfig.normalizeId(map['mode']?.toString()),
      privacyLevel: (map['privacyLevel'] ?? 'full').toString(),
      preferredLanguage: (map['preferredLanguage'] ?? 'tr').toString(),
      locationGranularity: (map['locationGranularity'] ?? 'nearby').toString(),
      enableDifferentialPrivacy: map['enableDifferentialPrivacy'] ?? true,
      kAnonymityLevel: _toInt(map['kAnonymityLevel']) == 0
          ? 3
          : _toInt(map['kAnonymityLevel']),
      allowAnalytics: map['allowAnalytics'] ?? true,
      isVisible: map['isVisible'] ?? true,
      isOnline: map['isOnline'] ?? false,
      isSignalActive: map['isSignalActive'] ?? false,
      profilePhotoUrl: (map['profilePhotoUrl'] ?? '').toString(),
      photoUrls: _toStringList(map['photoUrls']),
      location: locationMap == null ? null : GeoPoint.fromMap(locationMap),
      lastSeen: _parseDate(map['lastSeen'] ?? map['lastSeenAt']),
      createdAt: _parseDate(map['createdAt']),
      followersCount: _toInt(map['followersCount']),
      followingCount: _toInt(map['followingCount']),
      friendsCount: _toInt(map['friendsCount']),
      pulseScore: _toInt(map['pulseScore']),
      placesVisited: _toInt(map['placesVisited']),
      vibeTagsCreated: _toInt(map['vibeTagsCreated']),
      activityRatingAverage: _toDouble(map['activityRatingAverage']),
      activityRatingCount: _toInt(map['activityRatingCount']),
      pinnedPostId: _nullableString(map['pinnedPostId']),
      pinnedAt: _parseDate(map['pinnedAt']),
      orientation: (map['orientation'] ?? '').toString(),
      relationshipIntent: (map['relationshipIntent'] ?? '').toString(),
      heightCm: _toIntOrNull(map['heightCm']),
      drinkingStatus: (map['drinkingStatus'] ?? '').toString(),
      smokingStatus: (map['smokingStatus'] ?? '').toString(),
      isPhotoVerified: map['isPhotoVerified'] ?? false,
      datingPrompts: _toStringMap(map['datingPrompts']),
      lookingForModes: _toStringList(map['lookingForModes']),
      dealbreakers: _toStringList(map['dealbreakers']),
      enabledFeatures: _toBoolMap(map['enabledFeatures']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'userName': userName,
      'displayName': displayName,
      'bio': bio,
      'city': city,
      'website': website,
      'gender': gender,
      'birthDate': birthDate?.toIso8601String(),
      'age': age,
      'purpose': purpose,
      'matchPreference': matchPreference,
      'interests': interests,
      'mode': mode,
      'privacyLevel': privacyLevel,
      'preferredLanguage': preferredLanguage,
      'locationGranularity': locationGranularity,
      'enableDifferentialPrivacy': enableDifferentialPrivacy,
      'kAnonymityLevel': kAnonymityLevel,
      'allowAnalytics': allowAnalytics,
      'isVisible': isVisible,
      'isOnline': isOnline,
      'isSignalActive': isSignalActive,
      'profilePhotoUrl': profilePhotoUrl,
      'photoUrls': photoUrls,
      'location': location?.toMap(),
      'lastSeen': lastSeen?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'followersCount': followersCount,
      'followingCount': followingCount,
      'friendsCount': friendsCount,
      'pulseScore': pulseScore,
      'placesVisited': placesVisited,
      'vibeTagsCreated': vibeTagsCreated,
      'activityRatingAverage': activityRatingAverage,
      'activityRatingCount': activityRatingCount,
      'orientation': orientation,
      'relationshipIntent': relationshipIntent,
      'heightCm': heightCm,
      'drinkingStatus': drinkingStatus,
      'smokingStatus': smokingStatus,
      'isPhotoVerified': isPhotoVerified,
      'datingPrompts': datingPrompts,
      'lookingForModes': lookingForModes,
      'dealbreakers': dealbreakers,
      'enabledFeatures': enabledFeatures,
      'pinnedPostId': pinnedPostId,
      'pinnedAt': pinnedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? userName,
    String? firstName,
    String? lastName,
    String? displayName,
    String? bio,
    String? city,
    String? website,
    String? gender,
    DateTime? birthDate,
    int? age,
    String? purpose,
    String? matchPreference,
    List<String>? interests,
    String? mode,
    String? privacyLevel,
    String? preferredLanguage,
    String? locationGranularity,
    bool? enableDifferentialPrivacy,
    int? kAnonymityLevel,
    bool? allowAnalytics,
    bool? isVisible,
    bool? isOnline,
    bool? isSignalActive,
    String? profilePhotoUrl,
    List<String>? photoUrls,
    GeoPoint? location,
    int? followersCount,
    int? followingCount,
    int? friendsCount,
    int? pulseScore,
    int? placesVisited,
    int? vibeTagsCreated,
    double? activityRatingAverage,
    int? activityRatingCount,
    String? pinnedPostId,
    DateTime? pinnedAt,
    bool clearPinned = false,
    String? orientation,
    String? relationshipIntent,
    int? heightCm,
    bool clearHeight = false,
    String? drinkingStatus,
    String? smokingStatus,
    bool? isPhotoVerified,
    Map<String, String>? datingPrompts,
    List<String>? lookingForModes,
    List<String>? dealbreakers,
    Map<String, bool>? enabledFeatures,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      userName: userName ?? this.userName,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      website: website ?? this.website,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      purpose: purpose ?? this.purpose,
      matchPreference: matchPreference ?? this.matchPreference,
      interests: interests ?? this.interests,
      mode: mode ?? this.mode,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      locationGranularity: locationGranularity ?? this.locationGranularity,
      enableDifferentialPrivacy:
          enableDifferentialPrivacy ?? this.enableDifferentialPrivacy,
      kAnonymityLevel: kAnonymityLevel ?? this.kAnonymityLevel,
      allowAnalytics: allowAnalytics ?? this.allowAnalytics,
      isVisible: isVisible ?? this.isVisible,
      isOnline: isOnline ?? this.isOnline,
      isSignalActive: isSignalActive ?? this.isSignalActive,
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
      activityRatingAverage:
          activityRatingAverage ?? this.activityRatingAverage,
      activityRatingCount: activityRatingCount ?? this.activityRatingCount,
      pinnedPostId: clearPinned ? null : (pinnedPostId ?? this.pinnedPostId),
      pinnedAt: clearPinned ? null : (pinnedAt ?? this.pinnedAt),
      orientation: orientation ?? this.orientation,
      relationshipIntent: relationshipIntent ?? this.relationshipIntent,
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      drinkingStatus: drinkingStatus ?? this.drinkingStatus,
      smokingStatus: smokingStatus ?? this.smokingStatus,
      isPhotoVerified: isPhotoVerified ?? this.isPhotoVerified,
      datingPrompts: datingPrompts ?? this.datingPrompts,
      lookingForModes: lookingForModes ?? this.lookingForModes,
      dealbreakers: dealbreakers ?? this.dealbreakers,
      enabledFeatures: enabledFeatures ?? this.enabledFeatures,
    );
  }

  String get username {
    final raw = userName.isNotEmpty
        ? userName
        : (email.contains('@') ? email.split('@').first : email);
    if (raw.isNotEmpty) return raw;
    return uid;
  }

  bool get hasProfile => displayName.isNotEmpty;
  bool get isGhostMode => privacyLevel == 'ghost';

  static Map<String, dynamic>? _extractLocation(Map<String, dynamic> map) {
    final location = map['location'];
    if (location is Map) {
      return Map<String, dynamic>.from(location);
    }

    final lat = map['latitude'] ?? map['lat'];
    final lng = map['longitude'] ?? map['lng'];
    if (lat == null || lng == null) return null;
    return {'latitude': lat, 'longitude': lng};
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.isEmpty) return null;
  return text;
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int? _toIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value.toString());
  return parsed;
}

Map<String, String> _toStringMap(dynamic value) {
  if (value is Map) {
    final result = <String, String>{};
    value.forEach((k, v) {
      if (k == null) return;
      result[k.toString()] = v?.toString() ?? '';
    });
    return result;
  }
  return const {};
}

Map<String, bool> _toBoolMap(dynamic value) {
  if (value is Map) {
    final result = <String, bool>{};
    value.forEach((k, v) {
      if (k == null) return;
      if (v is bool) {
        result[k.toString()] = v;
      }
    });
    return result;
  }
  return const {};
}
