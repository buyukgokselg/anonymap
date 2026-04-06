import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ModeConfig {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String description;
  final String mapStyle;
  final List<Map<String, dynamic>> suggestions;
  final List<String> poiCategories;

  const ModeConfig({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
    required this.mapStyle,
    required this.suggestions,
    required this.poiCategories,
  });

  static final List<ModeConfig> all = [
    ModeConfig(
      id: 'kesif',
      label: 'Keşif',
      icon: Icons.explore_rounded,
      color: AppColors.modeKesif,
      description: 'Yeni yerler ve gizli köşeler keşfet',
      mapStyle: 'mapbox://styles/mapbox/dark-v11',
      poiCategories: ['cafe', 'restaurant', 'museum', 'gallery', 'park', 'bar'],
      suggestions: [
        {'title': 'Sternschanze', 'subtitle': 'Keşfedilecek çok yer', 'pulse': 78, 'density': 'Yoğun', 'icon': Icons.explore_rounded, 'color': AppColors.pulseHigh, 'lat': 53.5633, 'lng': 9.9617},
        {'title': 'Ottensen', 'subtitle': 'Butik dükkanlar & kafeler', 'pulse': 62, 'density': 'Orta', 'icon': Icons.storefront_rounded, 'color': AppColors.pulseMedium, 'lat': 53.5527, 'lng': 9.9264},
        {'title': 'Speicherstadt', 'subtitle': 'Tarihi depo bölgesi', 'pulse': 55, 'density': 'Orta', 'icon': Icons.account_balance_rounded, 'color': AppColors.pulseMedium, 'lat': 53.5437, 'lng': 9.9897},
        {'title': 'Karolinenviertel', 'subtitle': 'Sokak sanatı & kültür', 'pulse': 48, 'density': 'Düşük', 'icon': Icons.palette_rounded, 'color': AppColors.pulseLow, 'lat': 53.5620, 'lng': 9.9700},
      ],
    ),
    ModeConfig(
      id: 'sakinlik',
      label: 'Sakinlik',
      icon: Icons.spa_rounded,
      color: AppColors.modeSakinlik,
      description: 'Huzurlu ve sakin ortamlar bul',
      mapStyle: 'mapbox://styles/mapbox/dark-v11',
      poiCategories: ['park', 'garden', 'library', 'spa', 'yoga'],
      suggestions: [
        {'title': 'Planten un Blomen', 'subtitle': 'Huzurlu park & bahçe', 'pulse': 28, 'density': 'Çok Düşük', 'icon': Icons.park_rounded, 'color': AppColors.modeSakinlik, 'lat': 53.5573, 'lng': 9.9834},
        {'title': 'Altonaer Balkon', 'subtitle': 'Sakin manzara noktası', 'pulse': 22, 'density': 'Çok Düşük', 'icon': Icons.landscape_rounded, 'color': AppColors.modeSakinlik, 'lat': 53.5455, 'lng': 9.9384},
        {'title': 'Innocentiapark', 'subtitle': 'Gizli cennet', 'pulse': 15, 'density': 'Boş', 'icon': Icons.nature_rounded, 'color': AppColors.pulseLow, 'lat': 53.5785, 'lng': 9.9856},
        {'title': 'Elbstrand Övelgönne', 'subtitle': 'Nehir kenarı huzur', 'pulse': 32, 'density': 'Düşük', 'icon': Icons.water_rounded, 'color': AppColors.pulseLow, 'lat': 53.5439, 'lng': 9.9135},
      ],
    ),
    ModeConfig(
      id: 'sosyal',
      label: 'Sosyal',
      icon: Icons.people_rounded,
      color: AppColors.modeSosyal,
      description: 'Yeni insanlarla tanış, sosyal ortamlar',
      mapStyle: 'mapbox://styles/mapbox/dark-v11',
      poiCategories: ['bar', 'cafe', 'club', 'event_venue', 'coworking'],
      suggestions: [
        {'title': 'Schanzenviertel', 'subtitle': 'Sosyal merkez', 'pulse': 85, 'density': 'Yoğun', 'icon': Icons.groups_rounded, 'color': AppColors.pulseVeryHigh, 'lat': 53.5633, 'lng': 9.9617},
        {'title': 'Jungfernstieg', 'subtitle': 'Buluşma noktası', 'pulse': 72, 'density': 'Yoğun', 'icon': Icons.people_rounded, 'color': AppColors.pulseHigh, 'lat': 53.5519, 'lng': 9.9935},
        {'title': 'St. Georg', 'subtitle': 'Kültürel çeşitlilik', 'pulse': 68, 'density': 'Orta', 'icon': Icons.diversity_3_rounded, 'color': AppColors.pulseMedium, 'lat': 53.5557, 'lng': 10.0097},
        {'title': 'Winterhude', 'subtitle': 'Genç & dinamik', 'pulse': 58, 'density': 'Orta', 'icon': Icons.emoji_people_rounded, 'color': AppColors.pulseMedium, 'lat': 53.5870, 'lng': 10.0005},
      ],
    ),
    ModeConfig(
      id: 'uretkenlik',
      label: 'Üretkenlik',
      icon: Icons.laptop_mac_rounded,
      color: AppColors.modeUretkenlik,
      description: 'Sessiz çalışma ortamları & hızlı Wi-Fi',
      mapStyle: 'mapbox://styles/mapbox/dark-v11',
      poiCategories: ['cafe', 'coworking', 'library'],
      suggestions: [
        {'title': 'elbgold Ottensen', 'subtitle': 'Hızlı Wi-Fi & sessiz', 'pulse': 42, 'density': 'Düşük', 'icon': Icons.wifi_rounded, 'color': AppColors.modeUretkenlik, 'lat': 53.5527, 'lng': 9.9264},
        {'title': 'Zentralbibliothek', 'subtitle': 'Kütüphane & çalışma', 'pulse': 38, 'density': 'Düşük', 'icon': Icons.local_library_rounded, 'color': AppColors.pulseLow, 'lat': 53.5507, 'lng': 9.9918},
        {'title': 'betahaus', 'subtitle': 'Coworking space', 'pulse': 55, 'density': 'Orta', 'icon': Icons.business_center_rounded, 'color': AppColors.pulseMedium, 'lat': 53.5633, 'lng': 9.9617},
        {'title': 'Café Treibgut', 'subtitle': 'Sakin kafe & prize', 'pulse': 35, 'density': 'Düşük', 'icon': Icons.coffee_rounded, 'color': AppColors.pulseLow, 'lat': 53.5455, 'lng': 9.9384},
      ],
    ),
    ModeConfig(
      id: 'eglence',
      label: 'Eğlence',
      icon: Icons.celebration_rounded,
      color: AppColors.modeEglence,
      description: 'Enerji dolu gece hayatı & etkinlikler',
      mapStyle: 'mapbox://styles/mapbox/dark-v11',
      poiCategories: ['club', 'bar', 'concert_hall', 'event_venue'],
      suggestions: [
        {'title': 'Reeperbahn', 'subtitle': 'Gece hayatının kalbi', 'pulse': 94, 'density': 'Çok Yoğun', 'icon': Icons.nightlife_rounded, 'color': AppColors.pulseVeryHigh, 'lat': 53.5497, 'lng': 9.9637},
        {'title': 'St. Pauli', 'subtitle': 'Enerji patlıyor', 'pulse': 91, 'density': 'Çok Yoğun', 'icon': Icons.local_fire_department_rounded, 'color': AppColors.pulseVeryHigh, 'lat': 53.5508, 'lng': 9.9588},
        {'title': 'Große Freiheit', 'subtitle': 'Canlı müzik & dans', 'pulse': 86, 'density': 'Yoğun', 'icon': Icons.music_note_rounded, 'color': AppColors.pulseHigh, 'lat': 53.5498, 'lng': 9.9604},
        {'title': 'Sternschanze Bars', 'subtitle': 'Alternatif bar sahne', 'pulse': 78, 'density': 'Yoğun', 'icon': Icons.local_bar_rounded, 'color': AppColors.pulseHigh, 'lat': 53.5633, 'lng': 9.9617},
      ],
    ),
    ModeConfig(
      id: 'acik_alan',
      label: 'Açık Alan',
      icon: Icons.park_rounded,
      color: AppColors.modeAcikAlan,
      description: 'Parklar, doğa & dış mekan aktiviteleri',
      mapStyle: 'mapbox://styles/mapbox/dark-v11',
      poiCategories: ['park', 'beach', 'garden', 'playground', 'trail'],
      suggestions: [
        {'title': 'Stadtpark', 'subtitle': 'Hamburg\'un yeşil kalbi', 'pulse': 48, 'density': 'Orta', 'icon': Icons.forest_rounded, 'color': AppColors.modeAcikAlan, 'lat': 53.5960, 'lng': 10.0227},
        {'title': 'Elbstrand', 'subtitle': 'Nehir plajı & gün batımı', 'pulse': 42, 'density': 'Düşük', 'icon': Icons.beach_access_rounded, 'color': AppColors.pulseLow, 'lat': 53.5439, 'lng': 9.9135},
        {'title': 'Jenischpark', 'subtitle': 'Tarihi park & yürüyüş', 'pulse': 28, 'density': 'Çok Düşük', 'icon': Icons.nature_people_rounded, 'color': AppColors.pulseLow, 'lat': 53.5549, 'lng': 9.8887},
        {'title': 'Alster Bisiklet', 'subtitle': 'Göl çevresi rotası', 'pulse': 55, 'density': 'Orta', 'icon': Icons.directions_bike_rounded, 'color': AppColors.pulseMedium, 'lat': 53.5658, 'lng': 9.9997},
      ],
    ),
    ModeConfig(
      id: 'topluluk',
      label: 'Topluluk',
      icon: Icons.group_work_rounded,
      color: AppColors.modeTopluluk,
      description: 'Benzer ilgi alanlarına sahip insanlar',
      mapStyle: 'mapbox://styles/mapbox/dark-v11',
      poiCategories: ['community_center', 'event_venue', 'cafe', 'coworking'],
      suggestions: [
        {'title': 'Kulturhaus 73', 'subtitle': 'Topluluk etkinlikleri', 'pulse': 62, 'density': 'Orta', 'icon': Icons.groups_rounded, 'color': AppColors.modeTopluluk, 'lat': 53.5633, 'lng': 9.9617},
        {'title': 'Fabrique', 'subtitle': 'Yaratıcı atölyeler', 'pulse': 55, 'density': 'Orta', 'icon': Icons.handshake_rounded, 'color': AppColors.pulseMedium, 'lat': 53.5497, 'lng': 9.9637},
        {'title': 'Gängeviertel', 'subtitle': 'Sanat kolektifi', 'pulse': 48, 'density': 'Düşük', 'icon': Icons.palette_rounded, 'color': AppColors.pulseLow, 'lat': 53.5544, 'lng': 9.9797},
        {'title': 'Knust', 'subtitle': 'Müzik & buluşma', 'pulse': 65, 'density': 'Orta', 'icon': Icons.music_note_rounded, 'color': AppColors.pulseMedium, 'lat': 53.5612, 'lng': 9.9634},
      ],
    ),
    ModeConfig(
      id: 'aile',
      label: 'Aile',
      icon: Icons.family_restroom_rounded,
      color: AppColors.modeAcikAlan,
      description: 'Çocuk dostu & güvenli ortamlar',
      mapStyle: 'mapbox://styles/mapbox/dark-v11',
      poiCategories: ['playground', 'park', 'family_restaurant', 'zoo', 'museum'],
      suggestions: [
        {'title': 'Tierpark Hagenbeck', 'subtitle': 'Hayvanat bahçesi', 'pulse': 65, 'density': 'Orta', 'icon': Icons.pets_rounded, 'color': AppColors.modeAcikAlan, 'lat': 53.5953, 'lng': 9.9399},
        {'title': 'Miniatur Wunderland', 'subtitle': 'Çocuklar bayılır', 'pulse': 78, 'density': 'Yoğun', 'icon': Icons.train_rounded, 'color': AppColors.pulseHigh, 'lat': 53.5437, 'lng': 9.9887},
        {'title': 'Spielplatz Stadtpark', 'subtitle': 'Büyük oyun alanı', 'pulse': 45, 'density': 'Düşük', 'icon': Icons.child_care_rounded, 'color': AppColors.pulseLow, 'lat': 53.5960, 'lng': 10.0227},
        {'title': 'Botanischer Garten', 'subtitle': 'Eğitici & eğlenceli', 'pulse': 35, 'density': 'Düşük', 'icon': Icons.local_florist_rounded, 'color': AppColors.pulseLow, 'lat': 53.5604, 'lng': 9.8682},
      ],
    ),
  ];
}