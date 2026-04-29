class SavedPlaceModel {
  final String placeId;
  final String placeName;
  final String vicinity;
  final double? latitude;
  final double? longitude;
  final bool saved;

  const SavedPlaceModel({
    required this.placeId,
    required this.placeName,
    this.vicinity = '',
    this.latitude,
    this.longitude,
    this.saved = false,
  });

  factory SavedPlaceModel.fromMap(Map<String, dynamic> map) {
    return SavedPlaceModel(
      placeId: (map['placeId'] ?? map['place_id'] ?? '').toString(),
      placeName: (map['placeName'] ?? map['name'] ?? '').toString(),
      vicinity: (map['vicinity'] ?? '').toString(),
      latitude: _toDoubleOrNull(map['latitude'] ?? map['lat']),
      longitude: _toDoubleOrNull(map['longitude'] ?? map['lng']),
      saved: map['saved'] == true,
    );
  }
}

double? _toDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
