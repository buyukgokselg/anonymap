import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'home_shell_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  int _currentPage = 0;
  bool _isLoading = false;
  AppLocalizations get _l10n => context.l10n;

  // Sayfa 1: Gizlilik
  String? _privacyLevel;

  // Sayfa 2: İlgi alanları
  final List<String> _selectedInterests = [];

  // Sayfa 3: Dating context
  String? _orientation;
  String? _relationshipIntent;

  // ── Gizlilik Seçenekleri ──
  final List<Map<String, dynamic>> _privacyOptions = [
    {
      'id': 'full',
      'icon': Icons.visibility_rounded,
      'title': 'Tam Katılım',
      'desc':
          'Konum verilerinle şehrin nabzına katkı yap. Diğer kullanıcılar seni bireysel olarak göremez.',
      'color': AppColors.success,
    },
    {
      'id': 'partial',
      'icon': Icons.visibility_off_rounded,
      'title': 'Kısmi Katılım',
      'desc':
          'Mahalle seviyesinde veri paylaş. Daha düşük hassasiyet, daha fazla gizlilik.',
      'color': AppColors.warning,
    },
    {
      'id': 'ghost',
      'icon': Icons.shield_rounded,
      'title': 'Ghost Mode',
      'desc':
          'Hiçbir veri paylaşma. Sadece şehri izle. İstediğin zaman değiştirebilirsin.',
      'color': AppColors.modeOzelCevre,
    },
  ];

  // ── İlgi Alanları ──
  final List<Map<String, dynamic>> _interests = [
    // Yeme-İçme
    {'label': 'Kafeler', 'icon': '☕'},
    {'label': 'Restoranlar', 'icon': '🍽️'},
    {'label': 'Street Food', 'icon': '🌮'},
    {'label': 'Barlar & Gece', 'icon': '🍸'},
    // Kültür & Sanat
    {'label': 'Müzik & Konser', 'icon': '🎵'},
    {'label': 'Sanat & Müze', 'icon': '🎨'},
    {'label': 'Tiyatro & Sinema', 'icon': '🎭'},
    {'label': 'Kitap & Okuma', 'icon': '📚'},
    // Spor & Doğa
    {'label': 'Fitness & Spor', 'icon': '💪'},
    {'label': 'Koşu & Yürüyüş', 'icon': '🏃'},
    {'label': 'Parklar & Doğa', 'icon': '🌳'},
    {'label': 'Bisiklet', 'icon': '🚴'},
    {'label': 'Su Sporları', 'icon': '🏄'},
    {'label': 'Yoga & Meditasyon', 'icon': '🧘'},
    // Sosyal & Eğlence
    {'label': 'Board Game', 'icon': '🎲'},
    {'label': 'Oyun & E-Spor', 'icon': '🎮'},
    {'label': 'Dans', 'icon': '💃'},
    {'label': 'Fotoğrafçılık', 'icon': '📷'},
    {'label': 'Seyahat', 'icon': '✈️'},
    {'label': 'Alışveriş', 'icon': '🛍️'},
    // Üretkenlik
    {'label': 'Teknoloji', 'icon': '💻'},
    {'label': 'Startup & İş', 'icon': '🚀'},
    {'label': 'Dil Öğrenme', 'icon': '🗣️'},
    // Aile & Çocuk
    {'label': 'Çocuk Aktiviteleri', 'icon': '🧒'},
    {'label': 'Oyun Alanları', 'icon': '🎠'},
    {'label': 'Aile Gezileri', 'icon': '👨‍👩‍👧‍👦'},
    // Yaşam
    {'label': 'Evcil Hayvan', 'icon': '🐕'},
    {'label': 'Yemek Yapma', 'icon': '👨‍🍳'},
    {'label': 'Bahçe & Bitki', 'icon': '🌱'},
    {'label': 'El Sanatları', 'icon': '🎨'},
  ];

  // ── Cinsel Yönelim Seçenekleri ──
  final List<Map<String, String>> _orientationOptions = const [
    {'id': 'straight', 'icon': '⚥'},
    {'id': 'gay', 'icon': '🌈'},
    {'id': 'lesbian', 'icon': '🌸'},
    {'id': 'bi', 'icon': '💗'},
    {'id': 'pan', 'icon': '🌀'},
    {'id': 'queer', 'icon': '✨'},
    {'id': 'asexual', 'icon': '🪐'},
    {'id': 'none', 'icon': '⚪'},
  ];

  // ── İlişki Niyeti Seçenekleri ──
  final List<Map<String, String>> _intentOptions = const [
    {'id': 'casual', 'icon': '💫'},
    {'id': 'relationship', 'icon': '💞'},
    {'id': 'friendship', 'icon': '🤝'},
    {'id': 'open', 'icon': '🌊'},
    {'id': 'unsure', 'icon': '🌤️'},
  ];

  String _orientationLabel(String id) {
    return switch (id) {
      'straight' => _copy(tr: 'Heteroseksüel', en: 'Straight', de: 'Hetero'),
      'gay' => _copy(tr: 'Gey', en: 'Gay', de: 'Schwul'),
      'lesbian' => _copy(tr: 'Lezbiyen', en: 'Lesbian', de: 'Lesbisch'),
      'bi' => _copy(tr: 'Biseksüel', en: 'Bisexual', de: 'Bisexuell'),
      'pan' => _copy(tr: 'Panseksüel', en: 'Pansexual', de: 'Pansexuell'),
      'queer' => 'Queer',
      'asexual' => _copy(tr: 'Aseksüel', en: 'Asexual', de: 'Asexuell'),
      'none' => _copy(tr: 'Belirtmek istemiyorum', en: 'Prefer not to say', de: 'Keine Angabe'),
      _ => '',
    };
  }

  String _intentLabel(String id) {
    return switch (id) {
      'casual' => _copy(tr: 'Rahat / kısa süreli', en: 'Casual', de: 'Locker'),
      'relationship' => _copy(tr: 'Uzun ilişki', en: 'Relationship', de: 'Beziehung'),
      'friendship' => _copy(tr: 'Sadece arkadaşlık', en: 'Friendship', de: 'Freundschaft'),
      'open' => _copy(tr: 'Açığım, görelim', en: 'Open to anything', de: 'Offen'),
      'unsure' => _copy(tr: 'Henüz emin değilim', en: 'Still figuring out', de: 'Noch unsicher'),
      _ => '',
    };
  }

  String _copy({
    required String tr,
    required String en,
    required String de,
  }) {
    return switch (_l10n.languageCode) {
      'en' => en,
      'de' => de,
      _ => tr,
    };
  }

  String _privacyTitle(String id) {
    return switch (id) {
      'full' => _copy(
        tr: 'Tam Katılım',
        en: 'Full Participation',
        de: 'Volle Teilnahme',
      ),
      'partial' => _copy(
        tr: 'Kısmi Katılım',
        en: 'Partial Participation',
        de: 'Teilweise Teilnahme',
      ),
      'ghost' => 'Ghost Mode',
      _ => '',
    };
  }

  String _privacyDescription(String id) {
    return switch (id) {
      'full' => _copy(
        tr: 'Konum verilerinle şehrin nabzına katkı yap. Diğer kullanıcılar seni bireysel olarak göremez.',
        en: 'Contribute to your city pulse with location data. Other users cannot see you individually.',
        de: 'Trage mit deinen Standortdaten zum Puls der Stadt bei. Andere Nutzer können dich nicht individuell sehen.',
      ),
      'partial' => _copy(
        tr: 'Mahalle seviyesinde veri paylaş. Daha düşük hassasiyet, daha fazla gizlilik.',
        en: 'Share data at neighborhood level. Lower precision, more privacy.',
        de: 'Teile Daten auf Nachbarschaftsebene. Geringere Genauigkeit, mehr Privatsphäre.',
      ),
      'ghost' => _copy(
        tr: 'Hiçbir veri paylaşma. Sadece şehri izle. İstediğin zaman değiştirebilirsin.',
        en: 'Share no data. Just observe the city. You can change this anytime.',
        de: 'Teile keine Daten. Beobachte nur die Stadt. Du kannst das jederzeit ändern.',
      ),
      _ => '',
    };
  }

  String _interestLabel(String label) {
    const en = {
      'Kafeler': 'Cafes',
      'Restoranlar': 'Restaurants',
      'Street Food': 'Street Food',
      'Barlar & Gece': 'Bars & Nightlife',
      'Müzik & Konser': 'Music & Concerts',
      'Sanat & Müze': 'Art & Museums',
      'Tiyatro & Sinema': 'Theater & Cinema',
      'Kitap & Okuma': 'Books & Reading',
      'Fitness & Spor': 'Fitness & Sports',
      'Koşu & Yürüyüş': 'Running & Walking',
      'Parklar & Doğa': 'Parks & Nature',
      'Bisiklet': 'Cycling',
      'Su Sporları': 'Water Sports',
      'Yoga & Meditasyon': 'Yoga & Meditation',
      'Board Game': 'Board Games',
      'Oyun & E-Spor': 'Gaming & E-Sports',
      'Dans': 'Dance',
      'Fotoğrafçılık': 'Photography',
      'Seyahat': 'Travel',
      'Alışveriş': 'Shopping',
      'Teknoloji': 'Technology',
      'Startup & İş': 'Startup & Work',
      'Dil Öğrenme': 'Language Learning',
      'Çocuk Aktiviteleri': 'Kids Activities',
      'Oyun Alanları': 'Playgrounds',
      'Aile Gezileri': 'Family Trips',
      'Evcil Hayvan': 'Pets',
      'Yemek Yapma': 'Cooking',
      'Bahçe & Bitki': 'Garden & Plants',
      'El Sanatları': 'Crafts',
    };
    const de = {
      'Kafeler': 'Cafés',
      'Restoranlar': 'Restaurants',
      'Street Food': 'Street Food',
      'Barlar & Gece': 'Bars & Nachtleben',
      'Müzik & Konser': 'Musik & Konzerte',
      'Sanat & Müze': 'Kunst & Museen',
      'Tiyatro & Sinema': 'Theater & Kino',
      'Kitap & Okuma': 'Bücher & Lesen',
      'Fitness & Spor': 'Fitness & Sport',
      'Koşu & Yürüyüş': 'Laufen & Spazieren',
      'Parklar & Doğa': 'Parks & Natur',
      'Bisiklet': 'Fahrrad',
      'Su Sporları': 'Wassersport',
      'Yoga & Meditasyon': 'Yoga & Meditation',
      'Board Game': 'Brettspiele',
      'Oyun & E-Spor': 'Gaming & E-Sport',
      'Dans': 'Tanz',
      'Fotoğrafçılık': 'Fotografie',
      'Seyahat': 'Reisen',
      'Alışveriş': 'Shopping',
      'Teknoloji': 'Technologie',
      'Startup & İş': 'Startup & Arbeit',
      'Dil Öğrenme': 'Sprachenlernen',
      'Çocuk Aktiviteleri': 'Kinderaktivitäten',
      'Oyun Alanları': 'Spielplätze',
      'Aile Gezileri': 'Familienausflüge',
      'Evcil Hayvan': 'Haustiere',
      'Yemek Yapma': 'Kochen',
      'Bahçe & Bitki': 'Garten & Pflanzen',
      'El Sanatları': 'Basteln',
    };
    return switch (_l10n.languageCode) {
      'en' => en[label] ?? label,
      'de' => de[label] ?? label,
      _ => label,
    };
  }

  void _next() {
    // Validasyon
    if (_currentPage == 0 && _privacyLevel == null) {
      _showError(
        _copy(
          tr: 'Bir gizlilik seviyesi seç.',
          en: 'Choose a privacy level.',
          de: 'Wähle eine Datenschutzstufe.',
        ),
      );
      return;
    }
    if (_currentPage == 1 && _selectedInterests.isEmpty) {
      _showError(
        _copy(
          tr: 'En az bir ilgi alanı seç.',
          en: 'Choose at least one interest.',
          de: 'Wähle mindestens ein Interesse.',
        ),
      );
      return;
    }
    if (_currentPage == 2 &&
        (_orientation == null || _relationshipIntent == null)) {
      _showError(
        _copy(
          tr: 'Yönelim ve niyetini seç (gizlilik için \'belirtmek istemiyorum\' uygundur).',
          en: 'Pick orientation and intent ("prefer not to say" is fine).',
          de: 'Wähle Orientierung und Absicht ("keine Angabe" ist ok).',
        ),
      );
      return;
    }

    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    setState(() => _isLoading = true);
    try {
      final uid = _authService.currentUserId;
      if (uid.isNotEmpty) {
        final locationGranularity = switch (_privacyLevel) {
          'partial' => 'district',
          'ghost' => 'city',
          _ => 'nearby',
        };

        await _firestoreService.updateProfile(uid, {
          'privacyLevel': _privacyLevel,
          'interests': _selectedInterests,
          'locationGranularity': locationGranularity,
          'isVisible': true,
          'orientation': _orientation,
          'relationshipIntent': _relationshipIntent,
        });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const HomeShellScreen(),
            transitionsBuilder: (_, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(
          _copy(
            tr: 'Profil oluşturulamadı. Tekrar dene.',
            en: 'Profile could not be created. Try again.',
            de: 'Das Profil konnte nicht erstellt werden. Versuche es erneut.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? AppColors.primary
                            : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: i <= _currentPage
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Sayfalar ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildPrivacyPage(),
                  _buildInterestsPage(),
                  _buildDatingContextPage(),
                  _buildReadyPage(),
                ],
              ),
            ),

            // ── Alt Butonlar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withValues(
                            alpha: 0.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _currentPage == 3
                                    ? _copy(
                                        tr: 'Başla',
                                        en: 'Start',
                                        de: 'Starten',
                                      )
                                    : _l10n.phrase('Devam'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // SAYFA 1: Gizlilik Seviyesi
  // ══════════════════════════════════════
  Widget _buildPrivacyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded, size: 40, color: AppColors.primary),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(
                  text: _copy(
                    tr: 'Gizliliğin,\n',
                    en: 'Your privacy,\n',
                    de: 'Deine Privatsphäre,\n',
                  ),
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: _copy(
                    tr: 'senin kontrolünde.',
                    en: 'under your control.',
                    de: 'liegt in deiner Hand.',
                  ),
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _copy(
              tr: 'Verilerini nasıl paylaşacağını sen belirle. İstediğin zaman değiştirebilirsin.',
              en: 'You decide how your data is shared. You can change this anytime.',
              de: 'Du entscheidest, wie deine Daten geteilt werden. Du kannst das jederzeit ändern.',
            ),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.4),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ..._privacyOptions.map((opt) => _buildPrivacyCard(opt)),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard(Map<String, dynamic> opt) {
    final isSelected = _privacyLevel == opt['id'];
    final color = opt['color'] as Color;

    return GestureDetector(
      onTap: () => setState(() => _privacyLevel = opt['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(opt['icon'], color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _privacyTitle(opt['id']),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _privacyDescription(opt['id']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // SAYFA 2: İlgi Alanları
  // ══════════════════════════════════════
  Widget _buildInterestsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.interests_rounded,
            size: 40,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(
                  text: _copy(
                    tr: 'Nelerle\n',
                    en: 'What are\n',
                    de: 'Wofür\n',
                  ),
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: _copy(
                    tr: 'ilgileniyorsun?',
                    en: 'you into?',
                    de: 'interessierst du dich?',
                  ),
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _copy(
              tr: 'Önerilerimizi sana özel hale getirelim. En az birini seç.',
              en: 'Let’s personalize your recommendations. Choose at least one.',
              de: 'Lass uns deine Empfehlungen personalisieren. Wähle mindestens eins.',
            ),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.4),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _interests.map((interest) {
              final isSelected = _selectedInterests.contains(interest['label']);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedInterests.remove(interest['label']);
                    } else {
                      _selectedInterests.add(interest['label']);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        interest['icon'],
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _interestLabel(interest['label']),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            _copy(
              tr: '${_selectedInterests.length} seçildi',
              en: '${_selectedInterests.length} selected',
              de: '${_selectedInterests.length} ausgewählt',
            ),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // SAYFA 3: Dating Context (orientation + intent)
  // ══════════════════════════════════════
  Widget _buildDatingContextPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.favorite_border_rounded,
            size: 40,
            color: AppColors.modeFlirt,
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(
                  text: _copy(
                    tr: 'Daha iyi\n',
                    en: 'Let’s get to\n',
                    de: 'Lass uns dich\n',
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: _copy(
                    tr: 'tanışalım.',
                    en: 'know you.',
                    de: 'besser kennenlernen.',
                  ),
                  style: const TextStyle(color: AppColors.modeFlirt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _copy(
              tr: 'Eşleştirmeyi senin için anlamlı kılalım. Her şey sonradan değiştirilebilir.',
              en: 'So matches feel right. You can change everything later.',
              de: 'Damit Matches passen. Du kannst später alles ändern.',
            ),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.4),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _copy(
              tr: 'Cinsel yönelim',
              en: 'Orientation',
              de: 'Orientierung',
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _orientationOptions.map((opt) {
              return _datingChip(
                id: opt['id']!,
                icon: opt['icon']!,
                label: _orientationLabel(opt['id']!),
                isSelected: _orientation == opt['id'],
                onTap: () => setState(() => _orientation = opt['id']),
                accent: AppColors.modeFlirt,
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Text(
            _copy(
              tr: 'Şu an ne arıyorsun?',
              en: 'What are you looking for?',
              de: 'Was suchst du gerade?',
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _intentOptions.map((opt) {
              return _datingChip(
                id: opt['id']!,
                icon: opt['icon']!,
                label: _intentLabel(opt['id']!),
                isSelected: _relationshipIntent == opt['id'],
                onTap: () => setState(() => _relationshipIntent = opt['id']),
                accent: AppColors.modeFriends,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _datingChip({
    required String id,
    required String icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.16)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? accent
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // SAYFA 4: Hazır
  // ══════════════════════════════════════
  Widget _buildReadyPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulse animasyon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 52,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _copy(
              tr: 'Hazırsın!',
              en: 'You are ready!',
              de: 'Du bist bereit!',
            ),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _copy(
              tr: 'Şehrin nabzını hissetmeye başla.\nHer şeyi istediğin zaman değiştirebilirsin.',
              en: 'Start feeling the pulse of your city.\nYou can change everything anytime.',
              de: 'Spüre jetzt den Puls deiner Stadt.\nDu kannst alles jederzeit ändern.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.4),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),

          // Özet
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  Icons.shield_rounded,
                  _copy(
                    tr: 'Gizlilik',
                    en: 'Privacy',
                    de: 'Datenschutz',
                  ),
                  _privacyTitle(
                    _privacyOptions.firstWhere(
                    (o) => o['id'] == _privacyLevel,
                    orElse: () => {'id': 'full'},
                  )['id']),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                _buildSummaryRow(
                  Icons.interests_rounded,
                  _copy(
                    tr: 'İlgi Alanları',
                    en: 'Interests',
                    de: 'Interessen',
                  ),
                  _copy(
                    tr: '${_selectedInterests.length} seçildi',
                    en: '${_selectedInterests.length} selected',
                    de: '${_selectedInterests.length} ausgewählt',
                  ),
                ),
                if (_orientation != null || _relationshipIntent != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  _buildSummaryRow(
                    Icons.favorite_border_rounded,
                    _copy(
                      tr: 'Niyet',
                      en: 'Intent',
                      de: 'Absicht',
                    ),
                    [
                      if (_orientation != null) _orientationLabel(_orientation!),
                      if (_relationshipIntent != null)
                        _intentLabel(_relationshipIntent!),
                    ].join(' · '),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
