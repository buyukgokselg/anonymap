enum ActivityCategory {
  cesaret,
  anlik,
  sosyal,
  spor,
  sanat,
  egitim,
  doga,
  yemek,
  gece,
  seyahat,
  other,
}

enum ActivityVisibility { public, friends, mutualMatches, inviteOnly }

enum ActivityJoinPolicy { open, approvalRequired }

enum ActivityStatus { draft, published, cancelled, completed }

enum ActivityParticipationStatus { requested, approved, declined, cancelled }

/// Caller's relationship with the activity. Computed server-side from
/// host check + participation row. `none` means no relation.
enum ActivityViewerStatus {
  none,
  host,
  requested,
  approved,
  declined,
  cancelled,
}

ActivityCategory parseActivityCategory(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'cesaret':
      return ActivityCategory.cesaret;
    case 'anlik':
      return ActivityCategory.anlik;
    case 'sosyal':
      return ActivityCategory.sosyal;
    case 'spor':
      return ActivityCategory.spor;
    case 'sanat':
      return ActivityCategory.sanat;
    case 'egitim':
      return ActivityCategory.egitim;
    case 'doga':
      return ActivityCategory.doga;
    case 'yemek':
      return ActivityCategory.yemek;
    case 'gece':
      return ActivityCategory.gece;
    case 'seyahat':
      return ActivityCategory.seyahat;
    default:
      return ActivityCategory.other;
  }
}

String activityCategoryWireValue(ActivityCategory category) {
  switch (category) {
    case ActivityCategory.cesaret:
      return 'Cesaret';
    case ActivityCategory.anlik:
      return 'Anlik';
    case ActivityCategory.sosyal:
      return 'Sosyal';
    case ActivityCategory.spor:
      return 'Spor';
    case ActivityCategory.sanat:
      return 'Sanat';
    case ActivityCategory.egitim:
      return 'Egitim';
    case ActivityCategory.doga:
      return 'Doga';
    case ActivityCategory.yemek:
      return 'Yemek';
    case ActivityCategory.gece:
      return 'Gece';
    case ActivityCategory.seyahat:
      return 'Seyahat';
    case ActivityCategory.other:
      return 'Other';
  }
}

ActivityVisibility parseActivityVisibility(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'friends':
      return ActivityVisibility.friends;
    case 'mutualmatches':
      return ActivityVisibility.mutualMatches;
    case 'inviteonly':
      return ActivityVisibility.inviteOnly;
    default:
      return ActivityVisibility.public;
  }
}

String activityVisibilityWireValue(ActivityVisibility v) {
  switch (v) {
    case ActivityVisibility.public:
      return 'Public';
    case ActivityVisibility.friends:
      return 'Friends';
    case ActivityVisibility.mutualMatches:
      return 'MutualMatches';
    case ActivityVisibility.inviteOnly:
      return 'InviteOnly';
  }
}

ActivityJoinPolicy parseActivityJoinPolicy(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'approvalrequired':
      return ActivityJoinPolicy.approvalRequired;
    default:
      return ActivityJoinPolicy.open;
  }
}

String activityJoinPolicyWireValue(ActivityJoinPolicy p) =>
    p == ActivityJoinPolicy.approvalRequired ? 'ApprovalRequired' : 'Open';

ActivityStatus parseActivityStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'draft':
      return ActivityStatus.draft;
    case 'cancelled':
      return ActivityStatus.cancelled;
    case 'completed':
      return ActivityStatus.completed;
    default:
      return ActivityStatus.published;
  }
}

ActivityParticipationStatus parseActivityParticipationStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'approved':
      return ActivityParticipationStatus.approved;
    case 'declined':
      return ActivityParticipationStatus.declined;
    case 'cancelled':
      return ActivityParticipationStatus.cancelled;
    default:
      return ActivityParticipationStatus.requested;
  }
}

ActivityViewerStatus parseActivityViewerStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'host':
      return ActivityViewerStatus.host;
    case 'requested':
      return ActivityViewerStatus.requested;
    case 'approved':
      return ActivityViewerStatus.approved;
    case 'declined':
      return ActivityViewerStatus.declined;
    case 'cancelled':
      return ActivityViewerStatus.cancelled;
    default:
      return ActivityViewerStatus.none;
  }
}

class ActivityModel {
  ActivityModel({
    required this.id,
    required this.host,
    required this.title,
    required this.description,
    required this.category,
    required this.mode,
    this.coverImageUrl,
    required this.locationName,
    this.locationAddress,
    required this.latitude,
    required this.longitude,
    required this.city,
    this.placeId,
    required this.startsAt,
    this.endsAt,
    this.maxParticipants,
    required this.currentParticipantCount,
    required this.visibility,
    required this.joinPolicy,
    required this.requiresVerification,
    required this.interests,
    this.minAge,
    this.maxAge,
    required this.preferredGender,
    required this.status,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
    required this.viewerStatus,
    required this.viewerIsHost,
    required this.sampleParticipants,
    this.recurrenceRule = '',
    this.recurrenceUntil,
  });

  final String id;
  final Map<String, dynamic> host;
  final String title;
  final String description;
  final ActivityCategory category;
  final String mode;
  final String? coverImageUrl;
  final String locationName;
  final String? locationAddress;
  final double latitude;
  final double longitude;
  final String city;
  final String? placeId;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? maxParticipants;
  final int currentParticipantCount;
  final ActivityVisibility visibility;
  final ActivityJoinPolicy joinPolicy;
  final bool requiresVerification;
  final List<String> interests;
  final int? minAge;
  final int? maxAge;
  final String preferredGender;
  final ActivityStatus status;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ActivityViewerStatus viewerStatus;
  final bool viewerIsHost;
  final List<Map<String, dynamic>> sampleParticipants;

  /// "" = tek seferlik. "weekly" | "biweekly" | "monthly".
  final String recurrenceRule;

  /// Tekrar bitiş tarihi — null = süresiz.
  final DateTime? recurrenceUntil;

  bool get isRecurring => recurrenceRule.isNotEmpty;

  String get hostUserId => (host['id'] ?? host['uid'] ?? '').toString();
  String get hostDisplayName =>
      (host['displayName'] ?? host['userName'] ?? '').toString();
  String? get hostPhotoUrl {
    final raw = (host['profilePhotoUrl'] ?? host['photoUrl'] ?? '').toString();
    return raw.isEmpty ? null : raw;
  }

  /// Host kullanıcının aldığı aktivite puan ortalaması (0..5).
  double get hostRatingAverage => _toDouble(host['activityRatingAverage']);

  /// Host kullanıcının aldığı toplam aktivite puanı sayısı.
  int get hostRatingCount => _toInt(host['activityRatingCount']);

  bool get isFull =>
      maxParticipants != null && currentParticipantCount >= maxParticipants!;
  bool get isCancelled => status == ActivityStatus.cancelled;
  bool get isPast => startsAt.isBefore(DateTime.now());
  bool get viewerIsParticipant =>
      viewerStatus == ActivityViewerStatus.approved ||
      viewerStatus == ActivityViewerStatus.requested;

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    final hostMap = map['host'];
    return ActivityModel(
      id: (map['id'] ?? '').toString(),
      host: hostMap is Map
          ? Map<String, dynamic>.from(hostMap)
          : <String, dynamic>{},
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      category: parseActivityCategory(map['category']?.toString()),
      mode: (map['mode'] ?? 'chill').toString(),
      coverImageUrl: _nullableString(map['coverImageUrl']),
      locationName: (map['locationName'] ?? '').toString(),
      locationAddress: _nullableString(map['locationAddress']),
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      city: (map['city'] ?? '').toString(),
      placeId: _nullableString(map['placeId']),
      startsAt: _parseDate(map['startsAt']) ?? DateTime.now(),
      endsAt: _parseDate(map['endsAt']),
      maxParticipants: _toNullableInt(map['maxParticipants']),
      currentParticipantCount: _toInt(map['currentParticipantCount']),
      visibility: parseActivityVisibility(map['visibility']?.toString()),
      joinPolicy: parseActivityJoinPolicy(map['joinPolicy']?.toString()),
      requiresVerification: map['requiresVerification'] == true,
      interests: _toStringList(map['interests']),
      minAge: _toNullableInt(map['minAge']),
      maxAge: _toNullableInt(map['maxAge']),
      preferredGender: (map['preferredGender'] ?? 'any').toString(),
      status: parseActivityStatus(map['status']?.toString()),
      cancellationReason: _nullableString(map['cancellationReason']),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
      viewerStatus: parseActivityViewerStatus(
        map['viewerParticipationStatus']?.toString(),
      ),
      viewerIsHost: map['viewerIsHost'] == true,
      sampleParticipants: (map['sampleParticipants'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
      recurrenceRule: (map['recurrenceRule'] ?? '').toString(),
      recurrenceUntil: _parseDate(map['recurrenceUntil']),
    );
  }

  ActivityModel copyWith({
    int? currentParticipantCount,
    ActivityViewerStatus? viewerStatus,
    ActivityStatus? status,
    String? cancellationReason,
  }) {
    return ActivityModel(
      id: id,
      host: host,
      title: title,
      description: description,
      category: category,
      mode: mode,
      coverImageUrl: coverImageUrl,
      locationName: locationName,
      locationAddress: locationAddress,
      latitude: latitude,
      longitude: longitude,
      city: city,
      placeId: placeId,
      startsAt: startsAt,
      endsAt: endsAt,
      maxParticipants: maxParticipants,
      currentParticipantCount:
          currentParticipantCount ?? this.currentParticipantCount,
      visibility: visibility,
      joinPolicy: joinPolicy,
      requiresVerification: requiresVerification,
      interests: interests,
      minAge: minAge,
      maxAge: maxAge,
      preferredGender: preferredGender,
      status: status ?? this.status,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
      viewerStatus: viewerStatus ?? this.viewerStatus,
      viewerIsHost: viewerIsHost,
      sampleParticipants: sampleParticipants,
      recurrenceRule: recurrenceRule,
      recurrenceUntil: recurrenceUntil,
    );
  }
}

class ActivityParticipationModel {
  ActivityParticipationModel({
    required this.id,
    required this.activityId,
    required this.user,
    required this.status,
    this.joinMessage,
    this.responseNote,
    required this.requestedAt,
    this.respondedAt,
  });

  final String id;
  final String activityId;
  final Map<String, dynamic> user;
  final ActivityParticipationStatus status;
  final String? joinMessage;
  final String? responseNote;
  final DateTime requestedAt;
  final DateTime? respondedAt;

  String get userId => (user['id'] ?? user['uid'] ?? '').toString();
  String get userDisplayName =>
      (user['displayName'] ?? user['userName'] ?? '').toString();
  String? get userPhotoUrl {
    final raw = (user['profilePhotoUrl'] ?? user['photoUrl'] ?? '').toString();
    return raw.isEmpty ? null : raw;
  }

  factory ActivityParticipationModel.fromMap(Map<String, dynamic> map) {
    final userMap = map['user'];
    return ActivityParticipationModel(
      id: (map['id'] ?? '').toString(),
      activityId: (map['activityId'] ?? '').toString(),
      user: userMap is Map
          ? Map<String, dynamic>.from(userMap)
          : <String, dynamic>{},
      status: parseActivityParticipationStatus(map['status']?.toString()),
      joinMessage: _nullableString(map['joinMessage']),
      responseNote: _nullableString(map['responseNote']),
      requestedAt: _parseDate(map['requestedAt']) ?? DateTime.now(),
      respondedAt: _parseDate(map['respondedAt']),
    );
  }
}

class ActivityListResponse {
  ActivityListResponse({required this.items, required this.hasMore});

  final List<ActivityModel> items;
  final bool hasMore;

  factory ActivityListResponse.fromMap(Map<String, dynamic> map) {
    final list = map['items'];
    return ActivityListResponse(
      items: list is List
          ? list
                .whereType<Map>()
                .map((m) => ActivityModel.fromMap(Map<String, dynamic>.from(m)))
                .toList()
          : const [],
      hasMore: map['hasMore'] == true,
    );
  }
}

class ActivityListQueryParams {
  ActivityListQueryParams({
    this.category,
    this.mode,
    this.city,
    this.when,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusKm,
    this.limit = 20,
    this.after,
    this.hostUserId,
  });

  final ActivityCategory? category;
  final String? mode;
  final String? city;

  /// "today" | "tomorrow" | "this-week" | "weekend"
  final String? when;
  final double? centerLatitude;
  final double? centerLongitude;
  final double? radiusKm;
  final int limit;
  final DateTime? after;
  final String? hostUserId;

  Map<String, String> toQuery() {
    final q = <String, String>{};
    if (category != null) q['category'] = activityCategoryWireValue(category!);
    if (mode != null && mode!.isNotEmpty) q['mode'] = mode!;
    if (city != null && city!.isNotEmpty) q['city'] = city!;
    if (when != null && when!.isNotEmpty) q['when'] = when!;
    if (centerLatitude != null) q['centerLatitude'] = centerLatitude.toString();
    if (centerLongitude != null) {
      q['centerLongitude'] = centerLongitude.toString();
    }
    if (radiusKm != null) q['radiusKm'] = radiusKm.toString();
    q['limit'] = limit.toString();
    if (after != null) q['after'] = after!.toUtc().toIso8601String();
    if (hostUserId != null && hostUserId!.isNotEmpty) {
      q['hostUserId'] = hostUserId!;
    }
    return q;
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
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
