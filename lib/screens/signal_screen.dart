import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import 'chat_screen.dart';

class SignalScreen extends StatefulWidget {
  const SignalScreen({super.key});
  static bool isSignalActive = false;

  @override
  State<SignalScreen> createState() => _SignalScreenState();
}

class _SignalScreenState extends State<SignalScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _orbitController;
  late AnimationController _sweepController;
  late AnimationController _matchSlideController;
  late Animation<double> _pulseAnim;
  late Animation<double> _matchSlideAnim;

  bool _scanning = false;
  int _matchIndex = 0;
  bool _showMatchCard = false;
  bool _shareProfile = true;

  // Mini profil popup
  int? _selectedDotIndex;

  bool get _signalActive => SignalScreen.isSignalActive;
  set _signalActive(bool v) => SignalScreen.isSignalActive = v;

  final List<Map<String, dynamic>> _nearbyPeople = [
    {
      'name': 'Lena S.', 'username': '@lena_s', 'emoji': '👩',
      'dist': '120m', 'distValue': 120, 'mode': 'Sosyal', 'color': AppColors.modeSosyal,
      'compatibility': 87, 'pulse': 65,
      'commonInterests': ['Müzik & Konser', 'Kafeler', 'Fotoğrafçılık'],
      'bio': 'Hamburg keşfetmeyi seven biri ☕', 'anonymous': false,
    },
    {
      'name': null, 'username': null, 'emoji': '🧑',
      'dist': '240m', 'distValue': 240, 'mode': 'Keşif', 'color': AppColors.modeKesif,
      'compatibility': 72, 'pulse': 48,
      'commonInterests': ['Seyahat', 'Fotoğrafçılık'],
      'bio': null, 'anonymous': true,
    },
    {
      'name': 'Emre B.', 'username': '@emre_b', 'emoji': '🧑',
      'dist': '380m', 'distValue': 380, 'mode': 'Eğlence', 'color': AppColors.modeEglence,
      'compatibility': 65, 'pulse': 91,
      'commonInterests': ['Barlar & Gece', 'Müzik & Konser'],
      'bio': 'Gece kuşu 🦉', 'anonymous': false,
    },
    {
      'name': null, 'username': null, 'emoji': '👩',
      'dist': '450m', 'distValue': 450, 'mode': 'Sosyal', 'color': AppColors.modeSosyal,
      'compatibility': 54, 'pulse': 37,
      'commonInterests': ['Kafeler'],
      'bio': null, 'anonymous': true,
    },
    {
      'name': 'Sophie W.', 'username': '@sophie_w', 'emoji': '👩',
      'dist': '520m', 'distValue': 520, 'mode': 'Topluluk', 'color': AppColors.modeTopluluk,
      'compatibility': 48, 'pulse': 55,
      'commonInterests': ['Yoga & Meditasyon', 'Parklar & Doğa'],
      'bio': 'Doğa ve huzur 🌿', 'anonymous': false,
    },
    {
      'name': 'Can T.', 'username': '@can_t', 'emoji': '🧑',
      'dist': '600m', 'distValue': 600, 'mode': 'Üretkenlik', 'color': AppColors.modeUretkenlik,
      'compatibility': 43, 'pulse': 62,
      'commonInterests': ['Teknoloji', 'Kafeler'],
      'bio': 'Kod ve kahve ☕💻', 'anonymous': false,
    },
    {
      'name': 'Julia M.', 'username': '@julia_m', 'emoji': '👩',
      'dist': '290m', 'distValue': 290, 'mode': 'Sakinlik', 'color': AppColors.modeSakinlik,
      'compatibility': 76, 'pulse': 44,
      'commonInterests': ['Yoga & Meditasyon', 'Kitap & Okuma', 'Kafeler'],
      'bio': 'Kitap kurdu 📚', 'anonymous': false,
    },
  ];

  late List<Map<String, double>> _orbitParams;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _orbitController = AnimationController(vsync: this, duration: const Duration(seconds: 25))..repeat();
    _sweepController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _matchSlideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _matchSlideAnim = CurvedAnimation(parent: _matchSlideController, curve: Curves.easeOutCubic);

    final rng = Random(42);
    _orbitParams = List.generate(_nearbyPeople.length, (i) {
      return {
        'radius': 55.0 + rng.nextDouble() * 50,
        'speed': 0.2 + rng.nextDouble() * 0.6,
        'offset': rng.nextDouble() * 2 * pi,
        'direction': rng.nextBool() ? 1.0 : -1.0,
      };
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    _sweepController.dispose();
    _matchSlideController.dispose();
    super.dispose();
  }

  void _toggleSignal() {
    if (_signalActive) {
      setState(() { _signalActive = false; _scanning = false; _showMatchCard = false; _selectedDotIndex = null; });
    } else {
      setState(() { _signalActive = true; _scanning = true; _showMatchCard = false; _matchIndex = 0; _selectedDotIndex = null; });
      HapticFeedback.mediumImpact();

      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted && _signalActive) {
          HapticFeedback.heavyImpact();
          _matchSlideController.forward(from: 0);
          setState(() { _scanning = false; _showMatchCard = true; });
        }
      });
    }
  }

  void _skipMatch() {
    setState(() { _showMatchCard = false; _scanning = true; _selectedDotIndex = null; });
    _matchSlideController.reset();

    final nextIndex = _matchIndex + 1;
    if (nextIndex < _nearbyPeople.length) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && _signalActive) {
          HapticFeedback.heavyImpact();
          _matchSlideController.forward(from: 0);
          setState(() { _matchIndex = nextIndex; _scanning = false; _showMatchCard = true; });
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && _signalActive) {
          setState(() => _scanning = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Şu an yeni eşleşme yok. Sinyal aktif — yeni biri gelince bildirim alacaksın.'),
            backgroundColor: AppColors.bgCard, behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      });
    }
  }

  void _acceptMatch() {
    final person = _nearbyPeople[_matchIndex];
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, _, _) => ChatScreen(user: person),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  void _onDotTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedDotIndex = _selectedDotIndex == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Sinyal', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          if (_signalActive) ...[
            const SizedBox(width: 8),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.5), blurRadius: 6)])),
          ],
        ]),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_shareProfile ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: _shareProfile ? Colors.white.withOpacity(0.6) : AppColors.warning.withOpacity(0.7), size: 22),
            onPressed: _showPrivacySheet,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () { if (_selectedDotIndex != null) setState(() => _selectedDotIndex = null); },
        child: Column(
          children: [
            if (!_shareProfile) _buildAnonBanner(),

            // Sinyal gücü göstergesi
            if (_signalActive) _buildSignalStrength(),

            if (_showMatchCard)
              Expanded(child: _buildMatchCardAnimated())
            else
              Expanded(child: _buildMainView()),
          ],
        ),
      ),
    );
  }

  Widget _buildAnonBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withOpacity(0.2))),
      child: Row(children: [
        Icon(Icons.visibility_off_rounded, size: 16, color: AppColors.warning.withOpacity(0.7)),
        const SizedBox(width: 10),
        Expanded(child: Text('Anonim moddasın. Adın ve profilin gizli.', style: TextStyle(fontSize: 12, color: AppColors.warning.withOpacity(0.8), fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildSignalStrength() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.wifi_tethering_rounded, size: 14, color: AppColors.primary.withOpacity(0.5)),
          const SizedBox(width: 8),
          ...List.generate(5, (i) {
            return Container(
              width: 20, height: 4,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < 4 ? AppColors.primary.withOpacity(0.3 + i * 0.15) : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
          const SizedBox(width: 8),
          Text('${_nearbyPeople.length} kişi menzilde', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3))),
          const Spacer(),
          Text(_scanning ? 'Aranıyor...' : 'Aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _scanning ? AppColors.warning : AppColors.success)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // ANA GÖRÜNÜM
  // ══════════════════════════════════════
  Widget _buildMainView() {
    return Column(
      children: [
        const SizedBox(height: 4),
        Expanded(
          flex: 4,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(scale: _signalActive ? _pulseAnim.value : 1.0, child: child),
              child: SizedBox(
                width: 280, height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Mesafe halkaları + etiketler
                    _buildDistanceRing(260, '500m'),
                    _buildDistanceRing(195, '300m'),
                    _buildDistanceRing(130, '100m'),

                    // Radar sweep
                    if (_signalActive)
                      AnimatedBuilder(
                        animation: _sweepController,
                        builder: (_, __) {
                          return CustomPaint(
                            size: const Size(260, 260),
                            painter: _RadarSweepPainter(
                              angle: _sweepController.value * 2 * pi,
                              color: AppColors.primary,
                            ),
                          );
                        },
                      ),

                    // Dönen ve tıklanabilir kullanıcı noktaları
                    AnimatedBuilder(
                      animation: _orbitController,
                      builder: (_, __) {
                        return Stack(
                          alignment: Alignment.center,
                          children: List.generate(_nearbyPeople.length, (i) {
                            final params = _orbitParams[i];
                            final angle = params['offset']! + (_orbitController.value * 2 * pi * params['speed']! * params['direction']!);
                            final radius = params['radius']!;
                            final dx = radius * cos(angle);
                            final dy = radius * sin(angle);
                            return Transform.translate(
                              offset: Offset(dx, dy),
                              child: GestureDetector(
                                onTap: () => _onDotTap(i),
                                child: _buildRadarDot(_nearbyPeople[i], i == _selectedDotIndex),
                              ),
                            );
                          }),
                        );
                      },
                    ),

                    // Merkez buton
                    GestureDetector(
                      onTap: _toggleSignal,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _signalActive ? AppColors.primary : AppColors.bgCard,
                          border: Border.all(color: _signalActive ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.08), width: 2),
                          boxShadow: _signalActive ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 36, spreadRadius: 4)] : null,
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(
                            _signalActive ? (_scanning ? Icons.radar_rounded : Icons.wifi_tethering_rounded) : Icons.wifi_tethering_rounded,
                            size: 30, color: _signalActive ? Colors.white : Colors.white.withOpacity(0.4),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _signalActive ? (_scanning ? 'Arıyor' : 'Aktif') : 'Aç',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _signalActive ? Colors.white : Colors.white.withOpacity(0.4)),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Mini profil popup
        if (_selectedDotIndex != null) _buildMiniProfile(_nearbyPeople[_selectedDotIndex!]),

        // Durum
        if (_selectedDotIndex == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _signalActive
                  ? _scanning ? 'Uyumlu kişiler aranıyor...' : 'Sinyal aktif. Bir noktaya dokun.'
                  : '${_nearbyPeople.length} kişi yakınında.\nMerkez butona bas ve başla.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.35), height: 1.5),
            ),
          ),

        const SizedBox(height: 12),

        // Yakındakiler
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text('YAKININDA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.25), letterSpacing: 1.5)),
            const Spacer(),
            Text('${_nearbyPeople.length} kişi', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.2))),
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _nearbyPeople.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _onDotTap(i),
              child: _buildNearbyCard(_nearbyPeople[i], i == _selectedDotIndex),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }

  // ── Mesafe Halkası ──
  Widget _buildDistanceRing(double size, String label) {
    final isActive = _signalActive;
    return SizedBox(
      width: size, height: size,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isActive ? AppColors.primary.withOpacity(0.08) : Colors.white.withOpacity(0.03), width: 1),
            ),
          ),
          Positioned(
            top: 0, left: size / 2 - 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: AppColors.bgMain, borderRadius: BorderRadius.circular(4)),
              child: Text(label, style: TextStyle(fontSize: 9, color: isActive ? AppColors.primary.withOpacity(0.3) : Colors.white.withOpacity(0.15), fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Radar Dot ──
  Widget _buildRadarDot(Map<String, dynamic> p, bool selected) {
    final color = p['color'] as Color;
    final isAnon = p['anonymous'] == true;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: selected ? 38 : 30, height: selected ? 38 : 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color.withOpacity(0.3) : color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(selected ? 0.8 : 0.4), width: selected ? 2 : 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(selected ? 0.5 : 0.2), blurRadius: selected ? 16 : 8)],
      ),
      child: Icon(isAnon ? Icons.person_off_rounded : Icons.person_rounded, size: selected ? 18 : 14, color: color.withOpacity(isAnon ? 0.5 : 0.9)),
    );
  }

  // ── Mini Profil Popup ──
  Widget _buildMiniProfile(Map<String, dynamic> p) {
    final color = p['color'] as Color;
    final isAnon = p['anonymous'] == true;
    final name = isAnon ? 'Anonim' : (p['name'] ?? 'Anonim');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 20)],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15), border: Border.all(color: color.withOpacity(0.3))),
            child: isAnon
                ? Icon(Icons.person_off_rounded, size: 20, color: color.withOpacity(0.5))
                : Center(child: Text(p['emoji'] ?? '🧑', style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isAnon ? Colors.white.withOpacity(0.5) : Colors.white)),
                if (isAnon) ...[const SizedBox(width: 4), Icon(Icons.visibility_off_rounded, size: 12, color: Colors.white.withOpacity(0.2))],
              ]),
              const SizedBox(height: 4),
              Row(children: [
                _miniInfoTag(Icons.location_on_rounded, p['dist'], Colors.white.withOpacity(0.4)),
                const SizedBox(width: 10),
                _miniInfoTag(Icons.circle, p['mode'], color),
                const SizedBox(width: 10),
                _miniInfoTag(Icons.favorite_rounded, 'Pulse ${p['pulse']}', AppColors.primary.withOpacity(0.6)),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Text('${p['compatibility']}%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _miniInfoTag(IconData icon, String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    ]);
  }

  // ══════════════════════════════════════
  // EŞLEŞME KARTI (Animated)
  // ══════════════════════════════════════
  Widget _buildMatchCardAnimated() {
    return AnimatedBuilder(
      animation: _matchSlideAnim,
      builder: (_, child) {
        return Transform.translate(
          offset: Offset(0, 60 * (1 - _matchSlideAnim.value)),
          child: Opacity(opacity: _matchSlideAnim.value.clamp(0.0, 1.0), child: child),
        );
      },
      child: _buildMatchContent(),
    );
  }

  Widget _buildMatchContent() {
    final person = _nearbyPeople[_matchIndex];
    final isAnon = person['anonymous'] == true;
    final color = person['color'] as Color;
    final name = isAnon ? 'Anonim Kullanıcı' : (person['name'] ?? 'Anonim');
    final username = isAnon ? 'Profil gizli' : (person['username'] ?? '');
    final bio = isAnon ? null : person['bio'];
    final interests = person['commonInterests'] as List<String>;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1), border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 24)]),
          child: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 12),
        const Text('Eşleşme Bulundu!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Sinyal aktif — arka planda aranıyor', style: TextStyle(fontSize: 11, color: AppColors.success.withOpacity(0.6))),
        ]),
        const SizedBox(height: 18),

        // Kişi kartı
        Container(
          width: double.infinity, padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
          child: Column(children: [
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15), border: Border.all(color: color.withOpacity(0.3))),
                child: isAnon ? Icon(Icons.person_rounded, size: 26, color: color.withOpacity(0.5)) : Center(child: Text(person['emoji'] ?? '🧑', style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  if (isAnon) ...[const SizedBox(width: 6), Icon(Icons.visibility_off_rounded, size: 14, color: Colors.white.withOpacity(0.3))],
                ]),
                Text(username, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(isAnon ? 0.25 : 0.4))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Text('${person['compatibility']}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                  Text('uyum', style: TextStyle(fontSize: 9, color: AppColors.primary.withOpacity(0.6))),
                ]),
              ),
            ]),
            if (bio != null) ...[
              const SizedBox(height: 12),
              Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.bgMain.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
                child: Text(bio, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5), height: 1.4))),
            ],
            const SizedBox(height: 12),
            Row(children: [
              _buildMatchInfo(Icons.location_on_rounded, person['dist']),
              const SizedBox(width: 14),
              _buildMatchInfo(Icons.favorite_rounded, 'Pulse ${person['pulse']}'),
              const SizedBox(width: 14),
              _buildMatchInfo(Icons.circle, person['mode'], color: color),
            ]),
            if (interests.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('ORTAK İLGİ ALANLARI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.25), letterSpacing: 1))),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: interests.map((i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.success.withOpacity(0.2))),
                child: Text(i, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
              )).toList()),
            ],
          ]),
        ),
        const SizedBox(height: 18),

        // Aksiyonlar
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
          onPressed: _acceptMatch,
          icon: const Icon(Icons.chat_bubble_rounded, size: 18),
          label: const Text('Mesaj Gönder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
        )),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: SizedBox(height: 46, child: OutlinedButton.icon(
            onPressed: _skipMatch,
            icon: Icon(Icons.skip_next_rounded, size: 18, color: Colors.white.withOpacity(0.4)),
            label: Text('Sonraki', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4))),
            style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withOpacity(0.08)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ))),
          const SizedBox(width: 10),
          Expanded(child: SizedBox(height: 46, child: OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.person_add_rounded, size: 18, color: AppColors.modeSosyal.withOpacity(0.7)),
            label: Text('Arkadaş Ekle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.modeSosyal.withOpacity(0.7))),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.modeSosyal.withOpacity(0.2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ))),
        ]),
        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _buildMatchInfo(IconData icon, String text, {Color? color}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color ?? Colors.white.withOpacity(0.3)),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: color ?? Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildNearbyCard(Map<String, dynamic> p, bool selected) {
    final color = p['color'] as Color;
    final isAnon = p['anonymous'] == true;
    final name = isAnon ? 'Anonim' : (p['name'] ?? 'Anonim');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 150, margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.08) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? color.withOpacity(0.4) : color.withOpacity(0.12), width: selected ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
            child: isAnon ? Icon(Icons.person_off_rounded, size: 14, color: color.withOpacity(0.4)) : Center(child: Text(p['emoji'] ?? '🧑', style: const TextStyle(fontSize: 14)))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isAnon ? Colors.white.withOpacity(0.4) : Colors.white), overflow: TextOverflow.ellipsis),
            Text(p['dist'], style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3))),
          ])),
        ]),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(p['mode'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))),
          const Spacer(),
          Icon(Icons.favorite_rounded, size: 10, color: AppColors.primary.withOpacity(0.4)),
          const SizedBox(width: 3),
          Text('${p['compatibility']}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary.withOpacity(0.6))),
        ]),
      ]),
    );
  }

  // ══════════════════════════════════════
  // GİZLİLİK
  // ══════════════════════════════════════
  void _showPrivacySheet() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Sinyal Gizliliği', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: AppColors.bgMain.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_rounded, size: 20, color: AppColors.primary)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Profilini Göster', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text('Adın, biyografin ve ilgi alanların görünür', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3))),
                ])),
                Switch(value: _shareProfile, onChanged: (v) { setSheetState(() {}); setState(() => _shareProfile = v); },
                  activeThumbColor: Colors.white, activeTrackColor: AppColors.primary,
                  inactiveThumbColor: Colors.white.withOpacity(0.3), inactiveTrackColor: Colors.white.withOpacity(0.08)),
              ]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.bgMain.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Colors.white.withOpacity(0.3)),
                const SizedBox(width: 10),
                Expanded(child: Text('Anonim modda diğer kullanıcılar sadece modunu, mesafeni ve uyumluluk yüzdesini görür. Adın, fotoğrafın ve biyografin gizli kalır.', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35), height: 1.5))),
              ]),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ]),
        );
      }),
    );
  }
}

// ══════════════════════════════════════
// RADAR SWEEP PAINTER
// ══════════════════════════════════════
class _RadarSweepPainter extends CustomPainter {
  final double angle;
  final Color color;

  _RadarSweepPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: angle - 0.8,
      endAngle: angle,
      colors: [
        color.withOpacity(0),
        color.withOpacity(0.12),
      ],
      transform: GradientRotation(angle - 0.8),
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);

    // Sweep çizgisi
    final linePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final endPoint = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );

    canvas.drawLine(center, endPoint, linePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) => oldDelegate.angle != angle;
}