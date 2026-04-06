import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/places_config.dart';

class PlacesService {
  static const _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  // Mod bazlı mekan tipleri
  static const Map<String, List<String>> modeTypes = {
    'kesif': ['restaurant', 'cafe', 'museum', 'art_gallery', 'tourist_attraction'],
    'sakinlik': ['park', 'library', 'spa', 'church'],
    'sosyal': ['bar', 'cafe', 'night_club', 'restaurant'],
    'uretkenlik': ['cafe', 'library'],
    'eglence': ['night_club', 'bar', 'movie_theater', 'bowling_alley', 'amusement_park'],
    'acik_alan': ['park', 'campground', 'stadium'],
    'topluluk': ['community_center', 'cafe', 'art_gallery'],
    'aile': ['park', 'zoo', 'aquarium', 'museum', 'amusement_park'],
  };

  // Yakındaki mekanları getir
  Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required double lat,
    required double lng,
    required String modeId,
    int radius = 1500,
  }) async {
    final types = modeTypes[modeId] ?? ['restaurant', 'cafe'];
    final allPlaces = <Map<String, dynamic>>[];

    // Her tip için ayrı istek (Google API tek tip kabul ediyor)
    for (final type in types.take(3)) {
      try {
        final url = '$_baseUrl/nearbysearch/json'
            '?location=$lat,$lng'
            '&radius=$radius'
            '&type=$type'
            '&key=$kGooglePlacesApiKey'
            '&language=tr';

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
              'photo_reference': (place['photos'] != null && (place['photos'] as List).isNotEmpty)
                  ? place['photos'][0]['photo_reference']
                  : null,
            });
          }
        }
      } catch (e) {
        debugPrint('Places API hata ($type): $e');
      }
    }

    // Puana göre sırala
    allPlaces.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));

    return allPlaces.take(20).toList();
  }

  // Mekan detayı
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final url = '$_baseUrl/details/json'
          '?place_id=$placeId'
          '&fields=name,formatted_address,formatted_phone_number,website,rating,reviews,opening_hours,photos,geometry,types,price_level,user_ratings_total'
          '&key=$kGooglePlacesApiKey'
          '&language=tr';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
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
            'weekday_text': List<String>.from(result['opening_hours']?['weekday_text'] ?? []),
            'reviews': (result['reviews'] as List?)?.map((r) => {
              'author': r['author_name'] ?? '',
              'rating': r['rating'] ?? 0,
              'text': r['text'] ?? '',
              'time': r['relative_time_description'] ?? '',
            }).toList() ?? [],
            'photos': (result['photos'] as List?)?.map((p) => p['photo_reference']).toList() ?? [],
          };
        }
      }
    } catch (e) {
      debugPrint('Place details hata: $e');
    }
    return null;
  }

  // Fotoğraf URL'i oluştur
  static String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return '$_baseUrl/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=$kGooglePlacesApiKey';
  }
}