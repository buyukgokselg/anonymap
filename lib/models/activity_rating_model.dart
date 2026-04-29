import 'activity_model.dart';

class ActivityRatingUser {
  ActivityRatingUser({
    required this.id,
    required this.displayName,
    required this.userName,
    this.profilePhotoUrl,
    this.ratingAverage = 0,
    this.ratingCount = 0,
  });

  final String id;
  final String displayName;
  final String userName;
  final String? profilePhotoUrl;
  final double ratingAverage;
  final int ratingCount;

  factory ActivityRatingUser.fromMap(Map<String, dynamic> map) {
    final raw = (map['profilePhotoUrl'] ?? '').toString();
    return ActivityRatingUser(
      id: (map['id'] ?? '').toString(),
      displayName: (map['displayName'] ?? '').toString(),
      userName: (map['userName'] ?? '').toString(),
      profilePhotoUrl: raw.isEmpty ? null : raw,
      ratingAverage: _toDouble(map['activityRatingAverage']),
      ratingCount: _toInt(map['activityRatingCount']),
    );
  }
}

class ActivityRatingModel {
  ActivityRatingModel({
    required this.id,
    required this.activityId,
    required this.rater,
    required this.rated,
    required this.score,
    this.comment,
    required this.createdAt,
  });

  final String id;
  final String activityId;
  final ActivityRatingUser rater;
  final ActivityRatingUser rated;
  final int score;
  final String? comment;
  final DateTime createdAt;

  factory ActivityRatingModel.fromMap(Map<String, dynamic> map) {
    return ActivityRatingModel(
      id: (map['id'] ?? '').toString(),
      activityId: (map['activityId'] ?? '').toString(),
      rater: ActivityRatingUser.fromMap(
        Map<String, dynamic>.from(map['rater'] as Map? ?? const {}),
      ),
      rated: ActivityRatingUser.fromMap(
        Map<String, dynamic>.from(map['rated'] as Map? ?? const {}),
      ),
      score: _toInt(map['score']),
      comment: _nullableString(map['comment']),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ActivityRatingListResponse {
  ActivityRatingListResponse({
    required this.items,
    required this.average,
    required this.count,
  });

  final List<ActivityRatingModel> items;
  final double average;
  final int count;

  factory ActivityRatingListResponse.fromMap(Map<String, dynamic> map) {
    final list = map['items'];
    return ActivityRatingListResponse(
      items: list is List
          ? list
                .whereType<Map>()
                .map(
                  (m) => ActivityRatingModel.fromMap(
                    Map<String, dynamic>.from(m),
                  ),
                )
                .toList()
          : const [],
      average: _toDouble(map['average']),
      count: _toInt(map['count']),
    );
  }
}

class PendingRatingItem {
  PendingRatingItem({required this.activity, required this.rateableUsers});

  final ActivityModel activity;
  final List<ActivityRatingUser> rateableUsers;

  factory PendingRatingItem.fromMap(Map<String, dynamic> map) {
    final activityRaw = map['activity'];
    final usersRaw = map['rateableUsers'];
    return PendingRatingItem(
      activity: ActivityModel.fromMap(
        Map<String, dynamic>.from(activityRaw as Map? ?? const {}),
      ),
      rateableUsers: usersRaw is List
          ? usersRaw
                .whereType<Map>()
                .map(
                  (m) =>
                      ActivityRatingUser.fromMap(Map<String, dynamic>.from(m)),
                )
                .toList()
          : const [],
    );
  }
}

class PendingRatingListResponse {
  PendingRatingListResponse({required this.items});

  final List<PendingRatingItem> items;

  factory PendingRatingListResponse.fromMap(Map<String, dynamic> map) {
    final list = map['items'];
    return PendingRatingListResponse(
      items: list is List
          ? list
                .whereType<Map>()
                .map(
                  (m) =>
                      PendingRatingItem.fromMap(Map<String, dynamic>.from(m)),
                )
                .toList()
          : const [],
    );
  }
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

String? _nullableString(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}
