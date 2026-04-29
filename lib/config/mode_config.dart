import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ModeConfig {
  final String id;
  final String label;
  final String tagline;
  final IconData icon;
  final Color color;
  final String description;
  final String mapStyle;
  final List<String> matchesWith;
  final List<Map<String, dynamic>> suggestions;
  final List<String> poiCategories;

  const ModeConfig({
    required this.id,
    required this.label,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.description,
    required this.mapStyle,
    required this.matchesWith,
    required this.suggestions,
    required this.poiCategories,
  });

  static const String defaultId = 'chill';
  static const String _mapStyle = 'mapbox://styles/mapbox/dark-v11';

  static const Map<String, String> _legacyAliases = {
    'kesif': 'chill',
    'sakinlik': 'chill',
    'sosyal': 'friends',
    'uretkenlik': 'chill',
    'eglence': 'fun',
    'acik_alan': 'chill',
    'topluluk': 'friends',
    'aile': 'chill',
    'alisveris': 'chill',
    'ozel_cevre': 'chill',
  };

  static String normalizeId(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaultId;
    final id = raw.trim();
    if (_legacyAliases.containsKey(id)) return _legacyAliases[id]!;
    if (all.any((m) => m.id == id)) return id;
    return defaultId;
  }

  static ModeConfig byId(String? id) {
    final normalized = normalizeId(id);
    return all.firstWhere(
      (m) => m.id == normalized,
      orElse: () => all.first,
    );
  }

  bool matches(ModeConfig other) =>
      id == other.id || matchesWith.contains(other.id);

  static final List<ModeConfig> all = [
    ModeConfig(
      id: 'flirt',
      label: 'Flört',
      tagline: 'Kimya arıyorum',
      icon: Icons.favorite_rounded,
      color: AppColors.modeFlirt,
      description: 'Romantik ilgiye açığım — 1:1 kimya, yeni bir başlangıç.',
      mapStyle: _mapStyle,
      matchesWith: ['flirt', 'chill'],
      poiCategories: ['cafe', 'restaurant', 'cocktail_bar', 'rooftop'],
      suggestions: [
        {
          'title': 'Sternschanze',
          'subtitle': 'Samimi kafeler & gece ışıkları',
          'pulse': 82,
          'density': 'Yoğun',
          'icon': Icons.local_cafe_rounded,
          'color': AppColors.modeFlirt,
          'lat': 53.5633,
          'lng': 9.9617,
        },
        {
          'title': 'HafenCity',
          'subtitle': 'Manzaralı rooftop buluşmaları',
          'pulse': 68,
          'density': 'Orta',
          'icon': Icons.nightlife_rounded,
          'color': AppColors.modeFlirt,
          'lat': 53.5413,
          'lng': 9.9949,
        },
        {
          'title': 'Ottensen',
          'subtitle': 'Şarap barları & sıcak atmosfer',
          'pulse': 61,
          'density': 'Orta',
          'icon': Icons.wine_bar_rounded,
          'color': AppColors.modeFlirt,
          'lat': 53.5527,
          'lng': 9.9264,
        },
        {
          'title': 'Alster Kenarı',
          'subtitle': 'Sessiz yürüyüş, derin sohbet',
          'pulse': 45,
          'density': 'Düşük',
          'icon': Icons.water_rounded,
          'color': AppColors.modeFlirt,
          'lat': 53.5658,
          'lng': 9.9997,
        },
      ],
    ),
    ModeConfig(
      id: 'friends',
      label: 'Arkadaşlık',
      tagline: 'Yeni tanışmalar',
      icon: Icons.waving_hand_rounded,
      color: AppColors.modeFriends,
      description:
          'Platonik yeni arkadaşlar, takılacak insanlar, paylaşacak şeyler.',
      mapStyle: _mapStyle,
      matchesWith: ['friends', 'chill'],
      poiCategories: ['cafe', 'board_game', 'coworking', 'park', 'bookstore'],
      suggestions: [
        {
          'title': 'Karolinenviertel',
          'subtitle': 'Küçük kafe sohbetleri',
          'pulse': 58,
          'density': 'Orta',
          'icon': Icons.coffee_rounded,
          'color': AppColors.modeFriends,
          'lat': 53.5620,
          'lng': 9.9700,
        },
        {
          'title': 'Stadtpark',
          'subtitle': 'Piknik & frizbi grupları',
          'pulse': 52,
          'density': 'Orta',
          'icon': Icons.park_rounded,
          'color': AppColors.modeFriends,
          'lat': 53.5960,
          'lng': 10.0227,
        },
        {
          'title': 'betahaus',
          'subtitle': 'Coworking & networking',
          'pulse': 47,
          'density': 'Düşük',
          'icon': Icons.groups_rounded,
          'color': AppColors.modeFriends,
          'lat': 53.5633,
          'lng': 9.9617,
        },
        {
          'title': 'Zentralbibliothek',
          'subtitle': 'Sessiz ortak çalışma',
          'pulse': 34,
          'density': 'Düşük',
          'icon': Icons.local_library_rounded,
          'color': AppColors.modeFriends,
          'lat': 53.5507,
          'lng': 9.9918,
        },
      ],
    ),
    ModeConfig(
      id: 'fun',
      label: 'Eğlence',
      tagline: 'Dışarıdayım, kalabalığım',
      icon: Icons.celebration_rounded,
      color: AppColors.modeFun,
      description:
          'Grup, parti, etkinlik — şu an dışarıda enerji dolu insanlarla.',
      mapStyle: _mapStyle,
      matchesWith: ['fun', 'chill'],
      poiCategories: ['club', 'bar', 'concert_hall', 'event_venue'],
      suggestions: [
        {
          'title': 'Reeperbahn',
          'subtitle': 'Gece hayatının kalbi',
          'pulse': 94,
          'density': 'Çok Yoğun',
          'icon': Icons.nightlife_rounded,
          'color': AppColors.modeFun,
          'lat': 53.5497,
          'lng': 9.9637,
        },
        {
          'title': 'St. Pauli',
          'subtitle': 'Canlı konserler, dans',
          'pulse': 88,
          'density': 'Yoğun',
          'icon': Icons.local_fire_department_rounded,
          'color': AppColors.modeFun,
          'lat': 53.5508,
          'lng': 9.9588,
        },
        {
          'title': 'Schanzenviertel',
          'subtitle': 'Alternatif bar sahnesi',
          'pulse': 79,
          'density': 'Yoğun',
          'icon': Icons.local_bar_rounded,
          'color': AppColors.modeFun,
          'lat': 53.5633,
          'lng': 9.9617,
        },
        {
          'title': 'Große Freiheit',
          'subtitle': 'Kulüpler & geç saat',
          'pulse': 85,
          'density': 'Yoğun',
          'icon': Icons.music_note_rounded,
          'color': AppColors.modeFun,
          'lat': 53.5498,
          'lng': 9.9604,
        },
      ],
    ),
    ModeConfig(
      id: 'chill',
      label: 'Keşif',
      tagline: 'Baskısız takılıyorum',
      icon: Icons.bedtime_rounded,
      color: AppColors.modeChill,
      description:
          'Açığım ama aramıyorum — doğal akış, rahat tanışmalar.',
      mapStyle: _mapStyle,
      matchesWith: ['flirt', 'friends', 'fun', 'chill'],
      poiCategories: ['cafe', 'park', 'bookstore', 'gallery'],
      suggestions: [
        {
          'title': 'Elbstrand',
          'subtitle': 'Gün batımı, sessiz akış',
          'pulse': 42,
          'density': 'Düşük',
          'icon': Icons.waves_rounded,
          'color': AppColors.modeChill,
          'lat': 53.5439,
          'lng': 9.9135,
        },
        {
          'title': 'Planten un Blomen',
          'subtitle': 'Huzurlu park yürüyüşü',
          'pulse': 38,
          'density': 'Düşük',
          'icon': Icons.eco_rounded,
          'color': AppColors.modeChill,
          'lat': 53.5573,
          'lng': 9.9834,
        },
        {
          'title': 'Speicherstadt',
          'subtitle': 'Tarihi köşe, yavaş tempo',
          'pulse': 48,
          'density': 'Orta',
          'icon': Icons.account_balance_rounded,
          'color': AppColors.modeChill,
          'lat': 53.5437,
          'lng': 9.9897,
        },
        {
          'title': 'Altonaer Balkon',
          'subtitle': 'Manzaralı sakin nokta',
          'pulse': 32,
          'density': 'Düşük',
          'icon': Icons.landscape_rounded,
          'color': AppColors.modeChill,
          'lat': 53.5455,
          'lng': 9.9384,
        },
      ],
    ),
  ];
}
