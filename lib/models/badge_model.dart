/// Statik rozet kataloğu girdisi — UI tarafında ikon/renk haritalaması.
class BadgeDefinition {
  BadgeDefinition({
    required this.code,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.color,
    required this.tierThresholds,
  });

  final String code;
  final String title;
  final String description;

  /// Material icon key — UI tarafındaki ikon haritasından çözülür.
  final String iconKey;

  /// Hex renk (örn. "#E94560") — rozet aksanı.
  final String color;

  /// Tier eşikleri (ör. [1, 5, 25] → bronze, silver, gold için gereken aksiyon).
  final List<int> tierThresholds;

  factory BadgeDefinition.fromMap(Map<String, dynamic> map) {
    final thresholds = map['tierThresholds'];
    return BadgeDefinition(
      code: (map['code'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      iconKey: (map['iconKey'] ?? 'star').toString(),
      color: (map['color'] ?? '#E94560').toString(),
      tierThresholds: thresholds is List
          ? thresholds
                .map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0)
                .toList()
          : const [],
    );
  }

  /// Toplam tier sayısı — gri/dolu görselleme için kullanılır.
  int get tierCount => tierThresholds.length;
}

/// Bir kullanıcının rozet ilerlemesi — kazanılmamışsa earned=false, tier=0.
class UserBadge {
  UserBadge({
    required this.code,
    required this.earned,
    required this.tier,
    required this.progress,
    this.nextThreshold,
    this.earnedAt,
  });

  final String code;
  final bool earned;
  final int tier;
  final int progress;

  /// Bir sonraki tier eşiği — null ise maksimum tier'a ulaşılmış.
  final int? nextThreshold;
  final DateTime? earnedAt;

  factory UserBadge.fromMap(Map<String, dynamic> map) {
    return UserBadge(
      code: (map['code'] ?? '').toString(),
      earned: map['earned'] == true,
      tier: _toInt(map['tier']),
      progress: _toInt(map['progress']),
      nextThreshold: map['nextThreshold'] == null
          ? null
          : _toInt(map['nextThreshold']),
      earnedAt: DateTime.tryParse(map['earnedAt']?.toString() ?? ''),
    );
  }

  /// Tier 1..3 için sırasıyla "Bronze/Silver/Gold/Platinum"; aksi halde boş.
  String get tierLabel {
    switch (tier) {
      case 1:
        return 'Bronze';
      case 2:
        return 'Silver';
      case 3:
        return 'Gold';
      case 4:
        return 'Platinum';
    }
    return '';
  }

  /// 0..1 aralığında bir sonraki tier'a olan ilerleme oranı.
  /// Maksimum tier'a ulaşılmışsa 1 döner.
  double progressRatio(BadgeDefinition def) {
    if (nextThreshold == null) return 1.0;
    final prevThreshold = tier == 0 ? 0 : def.tierThresholds[tier - 1];
    final span = (nextThreshold! - prevThreshold).clamp(1, 1 << 20);
    final delta = (progress - prevThreshold).clamp(0, span);
    return (delta / span).clamp(0.0, 1.0);
  }
}

class UserBadgesResponse {
  UserBadgesResponse({
    required this.items,
    required this.earnedCount,
    required this.totalCount,
  });

  final List<UserBadge> items;
  final int earnedCount;
  final int totalCount;

  factory UserBadgesResponse.fromMap(Map<String, dynamic> map) {
    final list = map['items'];
    return UserBadgesResponse(
      items: list is List
          ? list
                .whereType<Map>()
                .map((m) => UserBadge.fromMap(Map<String, dynamic>.from(m)))
                .toList()
          : const [],
      earnedCount: _toInt(map['earnedCount']),
      totalCount: _toInt(map['totalCount']),
    );
  }

  static UserBadgesResponse empty() =>
      UserBadgesResponse(items: const [], earnedCount: 0, totalCount: 0);
}

class BadgeCatalogResponse {
  BadgeCatalogResponse({required this.items});

  final List<BadgeDefinition> items;

  factory BadgeCatalogResponse.fromMap(Map<String, dynamic> map) {
    final list = map['items'];
    return BadgeCatalogResponse(
      items: list is List
          ? list
                .whereType<Map>()
                .map(
                  (m) => BadgeDefinition.fromMap(Map<String, dynamic>.from(m)),
                )
                .toList()
          : const [],
    );
  }

  /// Code → definition map (sık erişim için cache).
  Map<String, BadgeDefinition> get byCode =>
      {for (final b in items) b.code: b};
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
