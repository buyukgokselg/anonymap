/// Build-time feature flags for the dating-app pivot.
///
/// Bu uygulama önceden mekân-keşfi / şehir-nabzı / alışveriş / shorts-feed gibi
/// çok amaçlı bir sosyal uygulamaydı. Dating/matching odağına geçerken hiçbir
/// ekranı silmeden flag'lerle gizledik — gelecekte tekrar açılabilecekler.
///
/// Kurallar:
/// - Bir özellik `false` ise ekran router'da görünmez, menülerden ve FAB'lardan
///   render edilmez.
/// - Runtime override için `UserProfile.EnabledFeatures` (backend) okunur;
///   sadece burası `true` olan özellikler kullanıcıya göstereilir.
/// - Yeni bir eski özellik açılacaksa önce build-time flag'i çevir, sonra
///   runtime JSON field üzerinden A/B test et.
class AppFeatures {
  AppFeatures._();

  // ── Ana Dating Akışı (her zaman açık) ──
  static const bool signalOrbit = true;
  static const bool discoverSwipeStack = true;
  static const bool directChats = true;

  // ── Map + Density (dating için tutuluyor) ──
  /// Haritayı dating uygulamasında da gösteriyoruz — çevredeki kalabalığın
  /// hangi modda olduğunu (flört/arkadaşlık/eğlence/keşif) renklerle anlatmak
  /// için. Kullanıcı asıl akışı değil ama map stays visible.
  static const bool mapHome = true;

  /// Dating uygulamasında da aktif: stories ile kişisel an paylaşımı
  /// (flört için "bugün şuradaydım" gibi sinyaller sağlıyor).
  static const bool stories = true;

  /// Shorts (video) şu an açık — kullanıcı kararı. İleride kapanabilir.
  static const bool shortsFeed = true;

  // ── Gizlenen Özellikler (false) ──

  /// Alışveriş tamamen off-theme. Ekran duruyor ama hiçbir yerden
  /// navigasyon yok.
  static const bool shopping = false;

  /// Global "post feed" (Twitter/Instagram benzeri akış). Dating'de
  /// önplanda değil — ileride tekrar açılabilir.
  static const bool publicPostsFeed = false;

  /// Eski "Discover places" ekranı (şehirdeki mekânlar akışı). Yeni
  /// Discover artık people swipe-stack. Eski ekran gizli.
  static const bool placesDiscoverFeed = false;

  /// Şehir nabzı / "pulse" analytics dashboard'u. Dating'de gereksiz.
  static const bool cityPulseDashboard = false;

  /// Highlights (öne çıkanlar) — stories'den türetilen eski özellik.
  /// Stories'le birlikte çalışıyor ama kullanıcı görünürlüğünü azaltıyoruz.
  static const bool highlightsFeed = false;

  // ── Dating'e Özel Yeni Özellikler ──
  static const bool datingPromptsInProfile = true;
  static const bool chemistryScoreOnDiscover = true;
  static const bool photoVerification = true;
  static const bool dealbreakersFilter = true;

  /// Tek satırda tüm flagler — debug UI/QA için
  static Map<String, bool> get asMap => const {
    'signalOrbit': signalOrbit,
    'discoverSwipeStack': discoverSwipeStack,
    'directChats': directChats,
    'mapHome': mapHome,
    'stories': stories,
    'shortsFeed': shortsFeed,
    'shopping': shopping,
    'publicPostsFeed': publicPostsFeed,
    'placesDiscoverFeed': placesDiscoverFeed,
    'cityPulseDashboard': cityPulseDashboard,
    'highlightsFeed': highlightsFeed,
    'datingPromptsInProfile': datingPromptsInProfile,
    'chemistryScoreOnDiscover': chemistryScoreOnDiscover,
    'photoVerification': photoVerification,
    'dealbreakersFilter': dealbreakersFilter,
  };
}

/// Runtime feature override — kullanıcı bazlı.
///
/// Build-time `AppFeatures` AND runtime `EnabledFeatures` = final visibility.
/// Backend `UserProfile.EnabledFeatures` JSON kolonundan doldurulur.
class UserFeatureOverrides {
  const UserFeatureOverrides(this._overrides);

  final Map<String, bool> _overrides;

  static const UserFeatureOverrides empty = UserFeatureOverrides({});

  factory UserFeatureOverrides.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return empty;
    final clean = <String, bool>{};
    map.forEach((key, value) {
      if (value is bool) clean[key] = value;
    });
    return UserFeatureOverrides(clean);
  }

  bool isEnabled(String key, bool buildTimeDefault) {
    if (!buildTimeDefault) return false;
    return _overrides[key] ?? true;
  }

  Map<String, bool> toJson() => Map.unmodifiable(_overrides);
}
