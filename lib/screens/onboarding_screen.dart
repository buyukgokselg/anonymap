import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _firestoreService = FirestoreService();
  int _currentPage = 0;
  bool _isLoading = false;

  // Sayfa 1: Gizlilik
  String? _privacyLevel;

  // Sayfa 2: İlgi alanları
  final List<String> _selectedInterests = [];

  // Sayfa 3: Intent mod
  String? _selectedMode;

  // ── Gizlilik Seçenekleri ──
  final List<Map<String, dynamic>> _privacyOptions = [
    {
      'id': 'full',
      'icon': Icons.visibility_rounded,
      'title': 'Tam Katılım',
      'desc': 'Konum verilerinle şehrin nabzına katkı yap. Diğer kullanıcılar seni bireysel olarak göremez.',
      'color': AppColors.success,
    },
    {
      'id': 'partial',
      'icon': Icons.visibility_off_rounded,
      'title': 'Kısmi Katılım',
      'desc': 'Mahalle seviyesinde veri paylaş. Daha düşük hassasiyet, daha fazla gizlilik.',
      'color': AppColors.warning,
    },
    {
      'id': 'ghost',
      'icon': Icons.shield_rounded,
      'title': 'Ghost Mode',
      'desc': 'Hiçbir veri paylaşma. Sadece şehri izle. İstediğin zaman değiştirebilirsin.',
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

  // ── Intent Modları ──
  final List<Map<String, dynamic>> _modes = [
    {
      'id': 'kesif',
      'icon': Icons.explore_rounded,
      'title': 'Keşif',
      'desc': 'Yeni yerler ve deneyimler keşfet',
      'color': AppColors.modeKesif,
    },
    {
      'id': 'sakinlik',
      'icon': Icons.spa_rounded,
      'title': 'Sakinlik',
      'desc': 'Kalabalıktan uzak, huzurlu ortamlar',
      'color': AppColors.modeSakinlik,
    },
    {
      'id': 'sosyal',
      'icon': Icons.people_rounded,
      'title': 'Sosyal',
      'desc': 'Yeni insanlarla tanış, sosyal ortamlar',
      'color': AppColors.modeSosyal,
    },
    {
      'id': 'uretkenlik',
      'icon': Icons.laptop_mac_rounded,
      'title': 'Üretkenlik',
      'desc': 'Sessiz çalışma ortamları, kafeler',
      'color': AppColors.modeUretkenlik,
    },
    {
      'id': 'eglence',
      'icon': Icons.celebration_rounded,
      'title': 'Eğlence',
      'desc': 'Enerji dolu, hareketli mekanlar',
      'color': AppColors.modeEglence,
    },
    {
      'id': 'acik_alan',
      'icon': Icons.park_rounded,
      'title': 'Açık Alan',
      'desc': 'Parklar, doğa, dış mekan aktiviteleri',
      'color': AppColors.modeAcikAlan,
    },
    {
      'id': 'topluluk',
      'icon': Icons.group_work_rounded,
      'title': 'Topluluk',
      'desc': 'Benzer ilgi alanlarına sahip insanlar',
      'color': AppColors.modeTopluluk,
    },
    {
      'id': 'aile',
      'icon': Icons.family_restroom_rounded,
      'title': 'Aile & Çocuk',
      'desc': 'Çocuk dostu, güvenli ortamlar',
      'color': AppColors.modeAcikAlan,
    },
  ];

  void _next() {
    // Validasyon
    if (_currentPage == 0 && _privacyLevel == null) {
      _showError('Bir gizlilik seviyesi seç.');
      return;
    }
    if (_currentPage == 1 && _selectedInterests.isEmpty) {
      _showError('En az bir ilgi alanı seç.');
      return;
    }
    if (_currentPage == 2 && _selectedMode == null) {
      _showError('Bir başlangıç modu seç.');
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestoreService.createUserProfile(
          uid: user.uid,
          email: user.email ?? '',
          gender: '',
          age: 0,
          purpose: _selectedMode ?? 'kesif',
          interests: _selectedInterests,
        );

        // Gizlilik ve mod bilgisini de kaydet
        await _firestoreService.updateProfile(user.uid, {
          'privacyLevel': _privacyLevel,
          'mode': _selectedMode,
        });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const HomeScreen(),
            transitionsBuilder: (_, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Profil oluşturulamadı. Tekrar dene.');
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
                                  color: AppColors.primary.withOpacity(0.4),
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
                  _buildModePage(),
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
                              color: Colors.white.withOpacity(0.1),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 20),
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
                          disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.4),
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
                                _currentPage == 3 ? 'Başla' : 'Devam',
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
            text: const TextSpan(
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(text: 'Gizliliğin,\n', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'senin kontrolünde.', style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verilerini nasıl paylaşacağını sen belirle. İstediğin zaman değiştirebilirsin.',
            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.4), height: 1.5),
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
          color: isSelected ? color.withOpacity(0.1) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.white.withOpacity(0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(isSelected ? 0.2 : 0.1),
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
                    opt['title'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opt['desc'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
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
          const Icon(Icons.interests_rounded, size: 40, color: AppColors.primary),
          const SizedBox(height: 16),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(text: 'Nelerle\n', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'ilgileniyorsun?', style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Önerilerimizi sana özel hale getirelim. En az birini seç.',
            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.4), height: 1.5),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.5)
                          : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(interest['icon'], style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        interest['label'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.6),
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
            '${_selectedInterests.length} seçildi',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // SAYFA 3: Intent Mod Seçimi
  // ══════════════════════════════════════
  Widget _buildModePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tune_rounded, size: 40, color: AppColors.primary),
          const SizedBox(height: 16),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(text: 'Bugün ne\n', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'arıyorsun?', style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Başlangıç modunu seç. Harita ve öneriler buna göre şekillenecek.',
            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.4), height: 1.5),
          ),
          const SizedBox(height: 24),
          ..._modes.map((mode) => _buildModeCard(mode)),
        ],
      ),
    );
  }

  Widget _buildModeCard(Map<String, dynamic> mode) {
    final isSelected = _selectedMode == mode['id'];
    final color = mode['color'] as Color;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.white.withOpacity(0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(isSelected ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(mode['icon'], color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode['title'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode['desc'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 22),
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
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
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
          const Text(
            'Hazırsın!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Şehrin nabzını hissetmeye başla.\nHer şeyi istediğin zaman değiştirebilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.4),
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
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  Icons.shield_rounded,
                  'Gizlilik',
                  _privacyOptions.firstWhere(
                    (o) => o['id'] == _privacyLevel,
                    orElse: () => {'title': '-'},
                  )['title'],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                _buildSummaryRow(
                  Icons.interests_rounded,
                  'İlgi Alanları',
                  '${_selectedInterests.length} seçildi',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                _buildSummaryRow(
                  Icons.tune_rounded,
                  'Başlangıç Modu',
                  _modes.firstWhere(
                    (m) => m['id'] == _selectedMode,
                    orElse: () => {'title': '-'},
                  )['title'],
                ),
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
        Icon(icon, size: 20, color: AppColors.primary.withOpacity(0.7)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.4),
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