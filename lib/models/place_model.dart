class PlaceSummaryModel {
  final String placeId;
  final String name;
  final String vicinity;
  final double latitude;
  final double longitude;
  final double rating;
  final int userRatingsTotal;
  final bool openNow;
  final int priceLevel;
  final List<String> types;
  final String? photoReference;
  final int googlePulseScore;
  final int densityScore;
  final int trendScore;
  final int pulseScore;
  final int communityScore;
  final int liveSignalScore;
  final int ambassadorScore;
  final int syntheticDemandScore;
  final int seedConfidence;
  final int momentScore;
  final String densityLabel;
  final String trendLabel;
  final String distanceLabel;
  final double distanceMeters;
  final List<String> pulseDriverTags;
  final Map<String, int> seedSourceBreakdown;
  final String pulseReason;

  const PlaceSummaryModel({
    required this.placeId,
    required this.name,
    this.vicinity = '',
    required this.latitude,
    required this.longitude,
    this.rating = 0,
    this.userRatingsTotal = 0,
    this.openNow = false,
    this.priceLevel = 0,
    this.types = const [],
    this.photoReference,
    this.googlePulseScore = 0,
    this.densityScore = 0,
    this.trendScore = 0,
    this.pulseScore = 0,
    this.communityScore = 0,
    this.liveSignalScore = 0,
    this.ambassadorScore = 0,
    this.syntheticDemandScore = 0,
    this.seedConfidence = 0,
    this.momentScore = 0,
    this.densityLabel = '',
    this.trendLabel = '',
    this.distanceLabel = '',
    this.distanceMeters = 0,
    this.pulseDriverTags = const [],
    this.seedSourceBreakdown = const {},
    this.pulseReason = '',
  });

  factory PlaceSummaryModel.fromMap(Map<String, dynamic> map) {
    final breakdownRaw = map['seed_source_breakdown'] ?? map['seedSourceBreakdown'];
    final seedBreakdown = <String, int>{};
    if (breakdownRaw is Map) {
      for (final entry in breakdownRaw.entries) {
        seedBreakdown[entry.key.toString()] = _toInt(entry.value);
      }
    }

    return PlaceSummaryModel(
      placeId: _string(map['place_id'] ?? map['placeId']),
      name: _string(map['name']),
      vicinity: _string(map['vicinity']),
      latitude: _toDouble(map['lat'] ?? map['latitude']),
      longitude: _toDouble(map['lng'] ?? map['longitude']),
      rating: _toDouble(map['rating']),
      userRatingsTotal: _toInt(map['user_ratings_total'] ?? map['userRatingsTotal']),
      openNow: _toBool(map['open_now'] ?? map['openNow']),
      priceLevel: _toInt(map['price_level'] ?? map['priceLevel']),
      types: _toStringList(map['types']),
      photoReference: _stringOrNull(map['photo_reference'] ?? map['photoReference']),
      googlePulseScore: _toInt(map['google_pulse_score'] ?? map['googlePulseScore']),
      densityScore: _toInt(map['density_score'] ?? map['densityScore']),
      trendScore: _toInt(map['trend_score'] ?? map['trendScore']),
      pulseScore: _toInt(map['pulse_score'] ?? map['pulseScore']),
      communityScore: _toInt(map['community_score'] ?? map['communityScore']),
      liveSignalScore: _toInt(map['live_signal_score'] ?? map['liveSignalScore']),
      ambassadorScore: _toInt(map['ambassador_score'] ?? map['ambassadorScore']),
      syntheticDemandScore: _toInt(
        map['synthetic_demand_score'] ?? map['syntheticDemandScore'],
      ),
      seedConfidence: _toInt(map['seed_confidence'] ?? map['seedConfidence']),
      momentScore: _toInt(map['moment_score'] ?? map['momentScore']),
      densityLabel: _string(map['density_label'] ?? map['densityLabel']),
      trendLabel: _string(map['trend_label'] ?? map['trendLabel']),
      distanceLabel: _string(map['distance_label'] ?? map['distanceLabel']),
      distanceMeters: _toDouble(map['distance_meters'] ?? map['distanceMeters']),
      pulseDriverTags: _toStringList(
        map['pulse_driver_tags'] ?? map['pulseDriverTags'],
      ),
      seedSourceBreakdown: seedBreakdown,
      pulseReason: _string(map['pulse_reason'] ?? map['pulseReason']),
    );
  }
}

class PlaceReviewModel {
  final String author;
  final int rating;
  final String text;
  final String relativeTime;

  const PlaceReviewModel({
    this.author = '',
    this.rating = 0,
    this.text = '',
    this.relativeTime = '',
  });

  factory PlaceReviewModel.fromMap(Map<String, dynamic> map) {
    return PlaceReviewModel(
      author: _string(map['author']),
      rating: _toInt(map['rating']),
      text: _string(map['text']),
      relativeTime: _string(map['time'] ?? map['relativeTime']),
    );
  }
}

class PlaceDetailModel {
  final String placeId;
  final String name;
  final String address;
  final String phone;
  final String website;
  final double latitude;
  final double longitude;
  final double rating;
  final int totalRatings;
  final bool isOpen;
  final int priceLevel;
  final List<String> weekdayText;
  final List<String> photoReferences;
  final List<PlaceReviewModel> reviews;
  final int googlePulseScore;
  final int densityScore;
  final int trendScore;
  final int pulseScore;
  final int communityScore;
  final int liveSignalScore;
  final int ambassadorScore;
  final int syntheticDemandScore;
  final int seedConfidence;
  final List<String> pulseDriverTags;
  final Map<String, int> seedSourceBreakdown;
  final String pulseReason;

  const PlaceDetailModel({
    required this.placeId,
    required this.name,
    this.address = '',
    this.phone = '',
    this.website = '',
    required this.latitude,
    required this.longitude,
    this.rating = 0,
    this.totalRatings = 0,
    this.isOpen = false,
    this.priceLevel = 0,
    this.weekdayText = const [],
    this.photoReferences = const [],
    this.reviews = const [],
    this.googlePulseScore = 0,
    this.densityScore = 0,
    this.trendScore = 0,
    this.pulseScore = 0,
    this.communityScore = 0,
    this.liveSignalScore = 0,
    this.ambassadorScore = 0,
    this.syntheticDemandScore = 0,
    this.seedConfidence = 0,
    this.pulseDriverTags = const [],
    this.seedSourceBreakdown = const {},
    this.pulseReason = '',
  });

  factory PlaceDetailModel.fromMap(Map<String, dynamic> map) {
    final breakdownRaw = map['seed_source_breakdown'] ?? map['seedSourceBreakdown'];
    final seedBreakdown = <String, int>{};
    if (breakdownRaw is Map) {
      for (final entry in breakdownRaw.entries) {
        seedBreakdown[entry.key.toString()] = _toInt(entry.value);
      }
    }

    return PlaceDetailModel(
      placeId: _string(map['place_id'] ?? map['placeId']),
      name: _string(map['name']),
      address: _string(map['address']),
      phone: _string(map['phone']),
      website: _string(map['website']),
      latitude: _toDouble(map['lat'] ?? map['latitude']),
      longitude: _toDouble(map['lng'] ?? map['longitude']),
      rating: _toDouble(map['rating']),
      totalRatings: _toInt(map['total_ratings'] ?? map['totalRatings']),
      isOpen: _toBool(map['is_open'] ?? map['isOpen']),
      priceLevel: _toInt(map['price_level'] ?? map['priceLevel']),
      weekdayText: _toStringList(map['weekday_text'] ?? map['weekdayText']),
      photoReferences: _toStringList(map['photos'] ?? map['photoReferences']),
      reviews: (map['reviews'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => PlaceReviewModel.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      googlePulseScore: _toInt(map['google_pulse_score'] ?? map['googlePulseScore']),
      densityScore: _toInt(map['density_score'] ?? map['densityScore']),
      trendScore: _toInt(map['trend_score'] ?? map['trendScore']),
      pulseScore: _toInt(map['pulse_score'] ?? map['pulseScore']),
      communityScore: _toInt(map['community_score'] ?? map['communityScore']),
      liveSignalScore: _toInt(map['live_signal_score'] ?? map['liveSignalScore']),
      ambassadorScore: _toInt(map['ambassador_score'] ?? map['ambassadorScore']),
      syntheticDemandScore: _toInt(
        map['synthetic_demand_score'] ?? map['syntheticDemandScore'],
      ),
      seedConfidence: _toInt(map['seed_confidence'] ?? map['seedConfidence']),
      pulseDriverTags: _toStringList(
        map['pulse_driver_tags'] ?? map['pulseDriverTags'],
      ),
      seedSourceBreakdown: seedBreakdown,
      pulseReason: _string(map['pulse_reason'] ?? map['pulseReason']),
    );
  }
}

String _string(dynamic value) => value?.toString().trim() ?? '';

String? _stringOrNull(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}

bool _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final raw = value?.toString().trim().toLowerCase();
  return raw == 'true' || raw == '1';
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

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}
