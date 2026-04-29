class StoryViewerModel {
  final String userId;
  final String userName;
  final String displayName;
  final String profilePhotoUrl;
  final DateTime? viewedAt;

  const StoryViewerModel({
    required this.userId,
    required this.userName,
    required this.displayName,
    required this.profilePhotoUrl,
    required this.viewedAt,
  });

  factory StoryViewerModel.fromMap(Map<String, dynamic> map) {
    return StoryViewerModel(
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? '').toString(),
      displayName: (map['displayName'] ?? '').toString(),
      profilePhotoUrl: (map['profilePhotoUrl'] ?? '').toString(),
      viewedAt: _parseDate(map['viewedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'displayName': displayName,
      'profilePhotoUrl': profilePhotoUrl,
      'viewedAt': viewedAt?.toIso8601String(),
    };
  }
}

class HighlightModel {
  final String id;
  final String userId;
  final String title;
  final String coverUrl;
  final List<String> mediaUrls;
  final String type;
  final String textColorHex;
  final double textOffsetX;
  final double textOffsetY;
  final String modeTag;
  final String locationLabel;
  final String placeId;
  final bool showModeOverlay;
  final bool showLocationOverlay;
  final String entryKind;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final bool seenByCurrentUser;
  final int viewCount;
  final List<StoryViewerModel> viewers;

  const HighlightModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.coverUrl,
    this.mediaUrls = const [],
    this.type = 'image',
    this.textColorHex = '#FFFFFF',
    this.textOffsetX = 0,
    this.textOffsetY = 0,
    this.modeTag = '',
    this.locationLabel = '',
    this.placeId = '',
    this.showModeOverlay = false,
    this.showLocationOverlay = false,
    this.entryKind = 'highlight',
    this.expiresAt,
    this.createdAt,
    this.seenByCurrentUser = false,
    this.viewCount = 0,
    this.viewers = const [],
  });

  factory HighlightModel.fromMap(String id, Map<String, dynamic> map) {
    return HighlightModel(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      coverUrl: (map['coverUrl'] ?? '').toString(),
      mediaUrls: _toStringList(map['mediaUrls']),
      type: (map['type'] ?? 'image').toString(),
      textColorHex: (map['textColorHex'] ?? '#FFFFFF').toString(),
      textOffsetX: _toDouble(map['textOffsetX']),
      textOffsetY: _toDouble(map['textOffsetY']),
      modeTag: (map['modeTag'] ?? '').toString(),
      locationLabel: (map['locationLabel'] ?? '').toString(),
      placeId: (map['placeId'] ?? '').toString(),
      showModeOverlay: map['showModeOverlay'] == true,
      showLocationOverlay: map['showLocationOverlay'] == true,
      entryKind: (map['entryKind'] ?? 'highlight').toString(),
      expiresAt: _parseDate(map['expiresAt']),
      createdAt: _parseDate(map['createdAt']),
      seenByCurrentUser: map['seenByCurrentUser'] == true,
      viewCount: _toInt(map['viewCount']),
      viewers: _toViewerList(map['viewers']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'coverUrl': coverUrl,
      'mediaUrls': mediaUrls,
      'type': type,
      'textColorHex': textColorHex,
      'textOffsetX': textOffsetX,
      'textOffsetY': textOffsetY,
      'modeTag': modeTag,
      'locationLabel': locationLabel,
      'placeId': placeId,
      'showModeOverlay': showModeOverlay,
      'showLocationOverlay': showLocationOverlay,
      'entryKind': entryKind,
      'expiresAt': expiresAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'seenByCurrentUser': seenByCurrentUser,
      'viewCount': viewCount,
      'viewers': viewers.map((entry) => entry.toMap()).toList(),
    };
  }

  List<String> get storyMedia =>
      mediaUrls.isNotEmpty
          ? mediaUrls.where((entry) => entry.isNotEmpty).toList()
          : (coverUrl.isNotEmpty ? [coverUrl] : const []);

  bool get isStory => entryKind == 'story';
  bool get isHighlight => entryKind == 'highlight';
  bool get isActiveStory =>
      isStory && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

List<String> _toStringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

List<StoryViewerModel> _toViewerList(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((item) => StoryViewerModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
  return const [];
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
