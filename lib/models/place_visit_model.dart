/// Kullanıcının ziyaret ettiği bir mekanın özetlenmiş kaydı.
/// Backend post'lardan + PlaceSnapshot'tan türetir — client sadece tüketir.
class PlaceVisitModel {
  final String placeId;
  final String name;
  final String vicinity;
  final double? latitude;
  final double? longitude;
  final int visitCount;
  final DateTime lastVisitedAt;
  final String coverPhotoUrl;

  const PlaceVisitModel({
    required this.placeId,
    required this.name,
    required this.vicinity,
    required this.latitude,
    required this.longitude,
    required this.visitCount,
    required this.lastVisitedAt,
    required this.coverPhotoUrl,
  });

  factory PlaceVisitModel.fromMap(Map<String, dynamic> map) {
    return PlaceVisitModel(
      placeId: (map['placeId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      vicinity: (map['vicinity'] ?? '').toString(),
      latitude: _toNullableDouble(map['latitude']),
      longitude: _toNullableDouble(map['longitude']),
      visitCount: _toInt(map['visitCount']),
      lastVisitedAt:
          DateTime.tryParse((map['lastVisitedAt'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      coverPhotoUrl: (map['coverPhotoUrl'] ?? '').toString(),
    );
  }
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
