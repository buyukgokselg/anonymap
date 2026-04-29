/// Profil hero'sundaki "son sinyal N önce" + özet kart için kullanılır.
/// Backend SignalCrossings tablosundan üretir.
class SignalCrossingModel {
  final String id;
  final DateTime crossedAt;
  final String placeId;
  final String locationLabel;
  final double? approxLatitude;
  final double? approxLongitude;

  const SignalCrossingModel({
    required this.id,
    required this.crossedAt,
    required this.placeId,
    required this.locationLabel,
    required this.approxLatitude,
    required this.approxLongitude,
  });

  factory SignalCrossingModel.fromMap(Map<String, dynamic> map) {
    return SignalCrossingModel(
      id: (map['id'] ?? '').toString(),
      crossedAt: DateTime.tryParse((map['crossedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      placeId: (map['placeId'] ?? '').toString(),
      locationLabel: (map['locationLabel'] ?? '').toString(),
      approxLatitude: _toNullableDouble(map['approxLatitude']),
      approxLongitude: _toNullableDouble(map['approxLongitude']),
    );
  }
}

class SignalCrossingSummaryModel {
  final int totalCount;
  final DateTime? lastCrossedAt;
  final List<SignalCrossingModel> recent;

  const SignalCrossingSummaryModel({
    required this.totalCount,
    required this.lastCrossedAt,
    required this.recent,
  });

  const SignalCrossingSummaryModel.empty()
      : totalCount = 0,
        lastCrossedAt = null,
        recent = const [];

  factory SignalCrossingSummaryModel.fromMap(Map<String, dynamic> map) {
    final recentRaw = map['recent'];
    final recent = <SignalCrossingModel>[];
    if (recentRaw is List) {
      for (final entry in recentRaw) {
        if (entry is Map) {
          recent.add(
            SignalCrossingModel.fromMap(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }
    return SignalCrossingSummaryModel(
      totalCount: _toInt(map['totalCount']),
      lastCrossedAt: DateTime.tryParse(
        (map['lastCrossedAt'] ?? '').toString(),
      ),
      recent: recent,
    );
  }

  bool get hasAny => totalCount > 0;
}

double? _toNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
