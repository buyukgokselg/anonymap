import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/places_config.dart';
import 'app_locale_service.dart';
import 'pulse_api_service.dart';

class PlacesService {
  static const _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  // Dating niyet modları → Google Places kategorileri
  static const Map<String, List<String>> modeTypes = {
    'flirt': ['cafe', 'restaurant', 'bar', 'art_gallery'],
    'friends': ['cafe', 'park', 'bookstore', 'community_center'],
    'fun': ['bar', 'night_club', 'movie_theater', 'concert_hall'],
    'chill': ['cafe', 'park', 'bookstore', 'art_gallery'],
  };

  static const List<String> _positiveReviewWords = [
    'harika',
    'mükemmel',
    'güzel',
    'keyifli',
    'hızlı',
    'temiz',
    'samimi',
    'lezzetli',
    'rahat',
    'öneririm',
    'great',
    'amazing',
    'excellent',
    'friendly',
    'clean',
    'cozy',
    'perfect',
  ];

  static const List<String> _negativeReviewWords = [
    'kötü',
    'berbat',
    'yavaş',
    'kirli',
    'pahalı',
    'kalabalık',
    'gürültülü',
    'soğuk',
    'disappoint',
    'bad',
    'slow',
    'dirty',
    'expensive',
    'crowded',
    'noisy',
    'rude',
  ];

  static const Map<String, List<int>> _modePeakHours = {
    'flirt': [18, 19, 20, 21, 22, 23],
    'friends': [12, 13, 14, 15, 16, 17, 18, 19],
    'fun': [20, 21, 22, 23, 0, 1, 2],
    'chill': [11, 12, 13, 14, 15, 16, 17],
  };

  // Yakındaki mekanları getir
  Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required double lat,
    required double lng,
    required String modeId,
    int radius = 1500,
    String sortBy = 'moment',
  }) async {
    final backendPlaces = await PulseApiService.instance.getNearbyPlaces(
      lat: lat,
      lng: lng,
      modeId: modeId,
      radius: radius,
      sortBy: sortBy,
    );
    if (backendPlaces.isNotEmpty) {
      return backendPlaces;
    }

    if (!kHasGooglePlacesApiKey) {
      debugPrint('Google Places key missing. Nearby places request skipped.');
      return [];
    }

    final types = modeTypes[modeId] ?? ['restaurant', 'cafe'];
    final allPlaces = <Map<String, dynamic>>[];
    final languageCode = AppLocaleService.instance.languageCode;

    // Her tip için ayrı istek (Google API tek tip kabul ediyor)
    for (final type in types.take(3)) {
      try {
        final url =
            '$_baseUrl/nearbysearch/json'
            '?location=$lat,$lng'
            '&radius=$radius'
            '&type=$type'
            '&key=$kGooglePlacesApiKey'
            '&language=$languageCode';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List? ?? [];

          for (final place in results) {
            // Duplikat kontrolü
            final placeId = place['place_id'];
            if (allPlaces.any((p) => p['place_id'] == placeId)) continue;

            allPlaces.add({
              'place_id': placeId,
              'name': place['name'] ?? '',
              'lat': place['geometry']?['location']?['lat'] ?? 0.0,
              'lng': place['geometry']?['location']?['lng'] ?? 0.0,
              'rating': (place['rating'] ?? 0).toDouble(),
              'user_ratings_total': place['user_ratings_total'] ?? 0,
              'vicinity': place['vicinity'] ?? '',
              'types': List<String>.from(place['types'] ?? []),
              'open_now': place['opening_hours']?['open_now'] ?? false,
              'price_level': place['price_level'] ?? 0,
              'icon': place['icon'] ?? '',
              'photo_reference':
                  (place['photos'] != null &&
                      (place['photos'] as List).isNotEmpty)
                  ? place['photos'][0]['photo_reference']
                  : null,
              'google_pulse_score': _calculateGooglePulseScore(place),
              'density_score': _calculateDensityScore(place),
              'trend_score': _calculateTrendScore(place),
            });
          }
        }
      } catch (e) {
        debugPrint('Places API hata ($type): $e');
      }
    }

    if (sortBy == 'popular') {
      allPlaces.sort(
        (a, b) => _fallbackPopularScore(b).compareTo(_fallbackPopularScore(a)),
      );
      return allPlaces.take(30).toList();
    }

    allPlaces.sort(
      (a, b) => ((b['rating'] as num?)?.toDouble() ?? 0.0).compareTo(
        (a['rating'] as num?)?.toDouble() ?? 0.0,
      ),
    );

    return allPlaces.take(20).toList();
  }

  // Mekan detayı
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    final backendDetail = await PulseApiService.instance.getPlaceDetails(
      placeId,
    );
    if (backendDetail != null) {
      return backendDetail;
    }

    if (!kHasGooglePlacesApiKey) {
      debugPrint('Google Places key missing. Place details request skipped.');
      return null;
    }

    try {
      final languageCode = AppLocaleService.instance.languageCode;
      final url =
          '$_baseUrl/details/json'
          '?place_id=$placeId'
          '&fields=name,formatted_address,formatted_phone_number,website,rating,reviews,opening_hours,photos,geometry,types,price_level,user_ratings_total'
          '&key=$kGooglePlacesApiKey'
          '&language=$languageCode';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final reviews =
              (result['reviews'] as List?)
                  ?.map(
                    (r) => {
                      'author': r['author_name'] ?? '',
                      'rating': r['rating'] ?? 0,
                      'text': r['text'] ?? '',
                      'time': r['relative_time_description'] ?? '',
                    },
                  )
                  .toList() ??
              [];

          return {
            'name': result['name'] ?? '',
            'address': result['formatted_address'] ?? '',
            'phone': result['formatted_phone_number'] ?? '',
            'website': result['website'] ?? '',
            'rating': (result['rating'] ?? 0).toDouble(),
            'total_ratings': result['user_ratings_total'] ?? 0,
            'price_level': result['price_level'] ?? 0,
            'lat': result['geometry']?['location']?['lat'] ?? 0.0,
            'lng': result['geometry']?['location']?['lng'] ?? 0.0,
            'is_open': result['opening_hours']?['open_now'] ?? false,
            'weekday_text': List<String>.from(
              result['opening_hours']?['weekday_text'] ?? [],
            ),
            'reviews': reviews,
            'photos':
                (result['photos'] as List?)
                    ?.map((p) => p['photo_reference'])
                    .toList() ??
                [],
            'review_sentiment_score': _calculateReviewSentimentScore(reviews),
            'google_pulse_score': _calculateGooglePulseScore(result),
            'density_score': _calculateDensityScore(result),
            'trend_score': _calculateTrendScore(result, reviews: reviews),
          };
        }
      }
    } catch (e) {
      debugPrint('Place details hata: $e');
    }
    return null;
  }

  // Alışveriş kategorisine göre yakın mekanları getir
  Future<List<Map<String, dynamic>>> getShoppingPlaces({
    required double lat,
    required double lng,
    String category = 'all',
    int radius = 5000,
  }) async {
    if (!kHasGooglePlacesApiKey) return [];

    final categoryTypes = <String, List<String>>{
      'all': ['shopping_mall', 'clothing_store', 'electronics_store', 'furniture_store', 'supermarket'],
      'giyim': ['clothing_store'],
      'teknoloji': ['electronics_store'],
      'ev': ['furniture_store', 'home_goods_store'],
      'market': ['supermarket', 'grocery_or_supermarket'],
      'kozmetik': ['beauty_salon', 'drugstore'],
      'spor': ['sporting_goods_store'],
      'kitap': ['book_store'],
      'avm': ['shopping_mall'],
      'bahce': ['hardware_store'],
      'aksesuar': ['jewelry_store'],
    };

    final types = categoryTypes[category] ?? categoryTypes['all']!;
    final allPlaces = <Map<String, dynamic>>[];
    final languageCode = AppLocaleService.instance.languageCode;
    final seen = <String>{};

    for (final type in types.take(3)) {
      try {
        final url =
            '$_baseUrl/nearbysearch/json'
            '?location=$lat,$lng'
            '&radius=$radius'
            '&type=$type'
            '&key=$kGooglePlacesApiKey'
            '&language=$languageCode';

        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) continue;

        final data = json.decode(response.body);
        final results = data['results'] as List? ?? [];

        for (final place in results) {
          final placeId = place['place_id'] as String? ?? '';
          if (placeId.isEmpty || seen.contains(placeId)) continue;
          seen.add(placeId);

          final photoRef = (place['photos'] != null && (place['photos'] as List).isNotEmpty)
              ? place['photos'][0]['photo_reference'] as String? ?? ''
              : '';

          allPlaces.add({
            'place_id': placeId,
            'name': place['name'] ?? '',
            'lat': place['geometry']?['location']?['lat'] ?? 0.0,
            'lng': place['geometry']?['location']?['lng'] ?? 0.0,
            'rating': (place['rating'] ?? 0).toDouble(),
            'user_ratings_total': place['user_ratings_total'] ?? 0,
            'vicinity': place['vicinity'] ?? '',
            'types': List<String>.from(place['types'] ?? []),
            'open_now': place['opening_hours']?['open_now'] ?? false,
            'price_level': place['price_level'] ?? 0,
            'photo_reference': photoRef,
            'category': type,
          });
        }
      } catch (e) {
        debugPrint('Shopping places error ($type): $e');
      }
    }

    // Önce açık olanlar, sonra rating'e göre sırala
    allPlaces.sort((a, b) {
      final aOpen = a['open_now'] as bool ? 1 : 0;
      final bOpen = b['open_now'] as bool ? 1 : 0;
      if (aOpen != bOpen) return bOpen - aOpen;
      return ((b['rating'] as double) * 100).toInt() -
          ((a['rating'] as double) * 100).toInt();
    });

    return allPlaces.take(40).toList();
  }

  // Fotoğraf URL'i oluştur
  static String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    if (!kHasGooglePlacesApiKey || photoReference.isEmpty) return '';
    return '$_baseUrl/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=$kGooglePlacesApiKey';
  }

  List<Map<String, dynamic>> mergePulseSignals(
    List<Map<String, dynamic>> places, {
    Map<String, Map<String, dynamic>> communitySignals = const {},
  }) {
    return places.map((place) {
      final placeId = place['place_id']?.toString() ?? '';
      final community = communitySignals[placeId] ?? const <String, dynamic>{};
      final googlePulse =
          (place['google_pulse_score'] as num?)?.toDouble() ??
          _calculateGooglePulseScore(place).toDouble();
      final densityScore =
          (place['density_score'] as num?)?.toDouble() ??
          _calculateDensityScore(place).toDouble();
      final trendScore =
          (place['trend_score'] as num?)?.toDouble() ??
          _calculateTrendScore(place).toDouble();
      final communityScore = _calculateCommunityScore(community);
      final finalScore = _calculateBlendedPulseScore(
        googlePulse: googlePulse,
        densityScore: densityScore,
        trendScore: trendScore,
        communityScore: communityScore.toDouble(),
      );

      return {
        ...place,
        'community_signals': community,
        'community_score': communityScore,
        'pulse_score': finalScore,
        'density_label': _densityLabelFromScore(densityScore),
        'trend_label': _trendLabelFromScore(trendScore),
      };
    }).toList()..sort(
      (a, b) => ((b['pulse_score'] as num?) ?? 0).compareTo(
        (a['pulse_score'] as num?) ?? 0,
      ),
    );
  }

  List<Map<String, dynamic>> rankPlacesForMoment(
    List<Map<String, dynamic>> places, {
    required String modeId,
    required double userLat,
    required double userLng,
    DateTime? at,
    bool requireOpenNow = false,
  }) {
    final targetTime = at ?? DateTime.now();

    final ranked =
        places
            .where((place) => !requireOpenNow || place['open_now'] == true)
            .map((place) {
              final distanceMeters = _distanceMeters(
                userLat,
                userLng,
                (place['lat'] as num?)?.toDouble() ?? userLat,
                (place['lng'] as num?)?.toDouble() ?? userLng,
              );
              final pulse = (place['pulse_score'] as num?)?.toDouble() ?? 0;
              final trend = (place['trend_score'] as num?)?.toDouble() ?? 0;
              final density = (place['density_score'] as num?)?.toDouble() ?? 0;
              final openBoost = place['open_now'] == true ? 16.0 : 0.0;
              final distanceScore = (100 - (distanceMeters / 18))
                  .clamp(0, 100)
                  .toDouble();
              final modeFit = _calculateModeFit(
                modeId,
                List<String>.from(place['types'] ?? const []),
              );
              final timeFit = _calculateTimeFit(
                modeId,
                List<String>.from(place['types'] ?? const []),
                targetTime,
              );

              final momentScore =
                  (pulse * 0.50) +
                  (trend * 0.12) +
                  (density * 0.08) +
                  (distanceScore * 0.14) +
                  (modeFit * 0.08) +
                  (timeFit * 0.08) +
                  openBoost;

              return {
                ...place,
                'distance_meters': distanceMeters,
                'distance_label': _formatDistance(distanceMeters),
                'mode_fit_score': modeFit.round(),
                'time_fit_score': timeFit.round(),
                'moment_score': momentScore.round().clamp(0, 100),
              };
            })
            .toList()
          ..sort(
            (a, b) => ((b['moment_score'] as num?) ?? 0).compareTo(
              (a['moment_score'] as num?) ?? 0,
            ),
          );

    return ranked;
  }

  List<Map<String, dynamic>> buildHourlyForecast(
    List<Map<String, dynamic>> places, {
    required String modeId,
    required double userLat,
    required double userLng,
    DateTime? now,
    List<int> hourOffsets = const [0, 1, 2, 4, 6],
  }) {
    final baseTime = now ?? DateTime.now();
    final results = <Map<String, dynamic>>[];

    for (final offset in hourOffsets) {
      final slotTime = baseTime.add(Duration(hours: offset));
      final ranked = rankPlacesForMoment(
        places,
        modeId: modeId,
        userLat: userLat,
        userLng: userLng,
        at: slotTime,
      );
      if (ranked.isEmpty) continue;

      final topPlace = ranked.first;
      final score = (topPlace['moment_score'] as num?)?.toInt() ?? 0;
      final confidence = _calculateForecastConfidence(topPlace, offset);

      results.add({
        'offset_hours': offset,
        'time': slotTime,
        'label': offset == 0 ? 'Su an' : '+${offset}s',
        'place': topPlace,
        'score': score,
        'confidence': confidence,
      });
    }

    return results;
  }

  int _calculateGooglePulseScore(Map<String, dynamic> place) {
    final rating = (place['rating'] as num?)?.toDouble() ?? 0;
    final totalRatings = (place['user_ratings_total'] as num?)?.toInt() ?? 0;
    final isOpen = place['open_now'] == true || place['is_open'] == true;
    final priceLevel = (place['price_level'] as num?)?.toInt() ?? 0;

    final ratingComponent = (rating / 5) * 42;
    final volumeComponent = (math.log(totalRatings + 1) / math.log(5000)) * 28;
    final availabilityComponent = isOpen ? 10.0 : 3.0;
    final priceComponent = switch (priceLevel) {
      0 => 5.0,
      1 => 7.0,
      2 => 9.0,
      3 => 6.0,
      _ => 4.0,
    };

    return (ratingComponent +
            volumeComponent +
            availabilityComponent +
            priceComponent)
        .clamp(0, 100)
        .round();
  }

  int _calculateDensityScore(Map<String, dynamic> place) {
    final totalRatings = (place['user_ratings_total'] as num?)?.toInt() ?? 0;
    final rating = (place['rating'] as num?)?.toDouble() ?? 0;
    final weighted =
        ((math.log(totalRatings + 1) / math.log(5000)) * 70) +
        ((rating / 5) * 30);
    return weighted.clamp(0, 100).round();
  }

  int _calculateTrendScore(
    Map<String, dynamic> place, {
    List<dynamic> reviews = const [],
  }) {
    final isOpen = place['open_now'] == true || place['is_open'] == true;
    final reviewMomentum = reviews.isEmpty
        ? 0
        : _calculateReviewRecencyScore(reviews);
    final ratingVolume =
        (place['user_ratings_total'] as num?)?.toInt() ??
        (place['total_ratings'] as num?)?.toInt() ??
        0;
    final base = (math.log(ratingVolume + 1) / math.log(5000)) * 55;
    final openBoost = isOpen ? 20 : 0;
    return (base + reviewMomentum + openBoost).clamp(0, 100).round();
  }

  int _calculateReviewSentimentScore(List<dynamic> reviews) {
    if (reviews.isEmpty) return 50;

    var positive = 0;
    var negative = 0;
    for (final review in reviews) {
      final text = (review['text']?.toString() ?? '').toLowerCase();
      for (final word in _positiveReviewWords) {
        if (text.contains(word)) positive++;
      }
      for (final word in _negativeReviewWords) {
        if (text.contains(word)) negative++;
      }
    }

    final total = positive + negative;
    if (total == 0) return 55;
    final normalized = ((positive - negative) / total + 1) * 50;
    return normalized.clamp(0, 100).round();
  }

  int _calculateReviewRecencyScore(List<dynamic> reviews) {
    var score = 0;
    for (final review in reviews) {
      final time = (review['time']?.toString() ?? '').toLowerCase();
      if (time.contains('gün') || time.contains('day')) {
        score += 14;
      } else if (time.contains('hafta') || time.contains('week')) {
        score += 10;
      } else if (time.contains('ay') || time.contains('month')) {
        score += 6;
      } else if (time.contains('saat') || time.contains('hour')) {
        score += 18;
      }
    }
    return score.clamp(0, 25);
  }

  int _calculateCommunityScore(Map<String, dynamic> community) {
    final posts = (community['posts'] as num?)?.toInt() ?? 0;
    final shorts = (community['shorts'] as num?)?.toInt() ?? 0;
    final likes = (community['likes'] as num?)?.toInt() ?? 0;
    final comments = (community['comments'] as num?)?.toInt() ?? 0;
    final creators = (community['creators'] as num?)?.toInt() ?? 0;

    final score =
        (posts * 8) +
        (shorts * 10) +
        (likes * 1.4) +
        (comments * 2.5) +
        (creators * 6);
    return score.clamp(0, 100).round();
  }

  int _calculateBlendedPulseScore({
    required double googlePulse,
    required double densityScore,
    required double trendScore,
    required double communityScore,
  }) {
    final score =
        (googlePulse * 0.44) +
        (densityScore * 0.18) +
        (trendScore * 0.18) +
        (communityScore * 0.20);
    return score.clamp(0, 100).round();
  }

  double _fallbackPopularScore(Map<String, dynamic> place) {
    final pulse = (place['google_pulse_score'] as num?)?.toDouble() ?? 0;
    final rating = (place['rating'] as num?)?.toDouble() ?? 0;
    final trend = (place['trend_score'] as num?)?.toDouble() ?? 0;
    final density = (place['density_score'] as num?)?.toDouble() ?? 0;
    final totalRatings =
        (place['user_ratings_total'] as num?)?.toDouble() ?? 0.0;
    final reviewVolume = (totalRatings / 20).clamp(0, 100).toDouble();
    final openBoost = place['open_now'] == true ? 12.0 : 0.0;

    return (pulse * 0.42) +
        (rating * 10.0) +
        (reviewVolume * 0.22) +
        (density * 0.16) +
        (trend * 0.08) +
        openBoost;
  }

  double _calculateModeFit(String modeId, List<String> types) {
    if (types.isEmpty) return 45;
    final desiredTypes = modeTypes[modeId] ?? const <String>[];
    final matches = types.where(desiredTypes.contains).length;
    return (matches * 22 + 35).clamp(0, 100).toDouble();
  }

  double _calculateTimeFit(String modeId, List<String> types, DateTime at) {
    final peakHours = _modePeakHours[modeId] ?? const <int>[];
    final hour = at.hour;
    var score = peakHours.contains(hour) ? 82.0 : 52.0;

    final nightlife = types.contains('bar') || types.contains('night_club');
    final cafeLike = types.contains('cafe') || types.contains('library');
    final parkLike = types.contains('park') || types.contains('campground');

    if (nightlife && (hour >= 20 || hour <= 2)) score += 16;
    if (nightlife && hour < 17) score -= 24;

    if (cafeLike && hour >= 8 && hour <= 17) score += 14;
    if (cafeLike && hour >= 22) score -= 20;

    if (parkLike && hour >= 9 && hour <= 18) score += 12;
    if (parkLike && (hour <= 6 || hour >= 22)) score -= 22;

    return score.clamp(0, 100);
  }

  int _calculateForecastConfidence(
    Map<String, dynamic> place,
    int offsetHours,
  ) {
    final pulse = (place['pulse_score'] as num?)?.toDouble() ?? 0;
    final google = (place['google_pulse_score'] as num?)?.toDouble() ?? 0;
    final ratings = (place['user_ratings_total'] as num?)?.toInt() ?? 0;
    final community = (place['community_score'] as num?)?.toDouble() ?? 0;

    final dataStrength =
        ((pulse * 0.35) +
                (google * 0.25) +
                ((math.log(ratings + 1) / math.log(5000)) * 100 * 0.20) +
                (community * 0.20))
            .round();
    final horizonPenalty = offsetHours * 4;
    return (dataStrength - horizonPenalty).clamp(48, 96);
  }

  double _distanceMeters(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(startLat)) *
            math.cos(_toRadians(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _densityLabelFromScore(double score) {
    if (score >= 82) return 'Çok Yoğun';
    if (score >= 64) return 'Yoğun';
    if (score >= 42) return 'Orta';
    if (score >= 20) return 'Düşük';
    return 'Çok Düşük';
  }

  String _trendLabelFromScore(double score) {
    if (score >= 78) return 'Patlıyor';
    if (score >= 58) return 'Yükseliyor';
    if (score >= 38) return 'Sabit';
    return 'Sakin';
  }

  int calculateVelocityScore(Map<String, dynamic> place) {
    final trend = (place['trend_score'] as num?)?.toDouble() ?? 0;
    final google = (place['google_pulse_score'] as num?)?.toDouble() ?? 0;
    final totalRatings =
        (place['user_ratings_total'] as num?)?.toInt() ??
        (place['total_ratings'] as num?)?.toInt() ??
        0;
    final reviewVolume = ((math.log(totalRatings + 1) / math.log(5000)) * 100)
        .clamp(0, 100);

    final rawCommunity = place['community_signals'];
    final community = rawCommunity is Map
        ? rawCommunity.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    final communityScore =
        (place['community_score'] as num?)?.toDouble() ??
        _calculateCommunityScore(community).toDouble();

    final openBoost = place['open_now'] == true || place['is_open'] == true
        ? 10.0
        : 0.0;

    return ((trend * 0.45) +
            (communityScore * 0.30) +
            (reviewVolume * 0.15) +
            (google * 0.10) +
            openBoost)
        .clamp(0, 100)
        .round();
  }

  Map<String, double> buildPulseBreakdown(Map<String, dynamic> place) {
    final density =
        ((place['density_score'] as num?)?.toDouble() ?? 0).clamp(0, 100) / 100;
    final trend =
        ((place['trend_score'] as num?)?.toDouble() ?? 0).clamp(0, 100) / 100;
    final velocity = calculateVelocityScore(place) / 100;
    final pulse =
        ((place['pulse_score'] as num?)?.toDouble() ?? 0).clamp(0, 100) / 100;
    final rating = (place['rating'] as num?)?.toDouble() ?? 0;
    final totalRatings =
        (place['user_ratings_total'] as num?)?.toInt() ??
        (place['total_ratings'] as num?)?.toInt() ??
        0;
    final ratingScore = ((rating / 5) * 100).clamp(0, 100);
    final reviewVolume = ((math.log(totalRatings + 1) / math.log(5000)) * 100)
        .clamp(0, 100);
    final distanceMeters =
        (place['distance_meters'] as num?)?.toDouble() ?? 1200.0;
    final proximity = (100 - (distanceMeters / 20)).clamp(0, 100) / 100;

    final rawCommunity = place['community_signals'];
    final community = rawCommunity is Map
        ? rawCommunity.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    final communityScore =
        ((place['community_score'] as num?)?.toDouble() ??
                _calculateCommunityScore(community).toDouble())
            .clamp(0, 100) /
        100;

    final freshness =
        ((velocity * 0.58) +
                (communityScore * 0.24) +
                ((place['open_now'] == true || place['is_open'] == true)
                    ? 0.18
                    : 0.06))
            .clamp(0, 1)
            .toDouble();
    final reliability =
        (((ratingScore / 100) * 0.58) + ((reviewVolume / 100) * 0.42))
            .clamp(0, 1)
            .toDouble();
    final energy = ((trend * 0.62) + (communityScore * 0.22) + (pulse * 0.16))
        .clamp(0, 1)
        .toDouble();

    return {
      'density': density,
      'energy': energy,
      'freshness': freshness,
      'reliability': reliability,
      'proximity': proximity,
      'momentum': velocity,
    };
  }

  List<String> buildPulseDriverTags(Map<String, dynamic> place) {
    final tags = <String>[];
    final isOpen = place['open_now'] == true || place['is_open'] == true;
    final trend = (place['trend_score'] as num?)?.toDouble() ?? 0;
    final rating = (place['rating'] as num?)?.toDouble() ?? 0;
    final totalRatings =
        (place['user_ratings_total'] as num?)?.toInt() ??
        (place['total_ratings'] as num?)?.toInt() ??
        0;
    final distanceMeters =
        (place['distance_meters'] as num?)?.toDouble() ?? 9999.0;
    final communityScore =
        (place['community_score'] as num?)?.toDouble() ?? 0.0;

    if (isOpen) tags.add('su an acik');
    if (trend >= 65) tags.add('ivme kazaniyor');
    if (communityScore >= 35) tags.add('topluluktan sinyal aliyor');
    if (distanceMeters <= 350) tags.add('yuruyerek yakin');
    if (rating >= 4.4) tags.add('puan ortalamasi guclu');
    if (totalRatings >= 150) tags.add('yorum hacmi yuksek');

    if (tags.isEmpty) {
      tags.add('veri dengesi guclu');
    }

    return tags.take(3).toList();
  }

  String explainPulseDrivers(Map<String, dynamic> place, {String? modeLabel}) {
    final placeName = place['name']?.toString() ?? 'Bu mekan';
    final tags = buildPulseDriverTags(place);
    if (tags.isEmpty) return '$placeName hakkinda yeterli veri yok.';

    final context = modeLabel == null || modeLabel.isEmpty
        ? ''
        : ' $modeLabel modu icin';

    if (tags.length == 1) {
      return '$placeName$context ${tags.first} oldugu icin one cikiyor.';
    }

    final first = tags.first;
    final second = tags.length > 1 ? tags[1] : '';
    final third = tags.length > 2 ? tags[2] : '';

    if (third.isEmpty) {
      return '$placeName$context $first ve $second sayesinde yukseliyor.';
    }

    return '$placeName$context $first, $second ve $third sayesinde yukseliyor.';
  }
}
