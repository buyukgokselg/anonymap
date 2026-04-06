import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../theme/colors.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';
import 'signal_screen.dart';
import 'profile_screen.dart';
import 'discover_screen.dart';
import 'inbox_screen.dart';

final Point _kDefaultMapCenter = Point(coordinates: Position(9.9872, 53.5488));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedMode = 0;
  final _locationService = LocationService();
  final _firestoreService = FirestoreService();
  geo.Position? _currentPosition;
  MapboxMap? _mapboxMap;
  StreamSubscription<geo.Position>? _positionSub;
  DateTime _lastMapFlyTo = DateTime.fromMillisecondsSinceEpoch(0);
  bool _showMap = false;
  bool _mapStyleReady = false;
  bool _appliedInitialCamera = false;

  // Pulse Score demo
  int _pulseScore = 72;
  String _densityLabel = 'Orta';
  String _trendLabel = '↑ Yükseliyor';

  // Bottom sheet
  bool _showBottomCard = false;
  final ScrollController _suggestionsController = ScrollController();
  bool _showScrollHint = true;
  String _selectedAreaName = '';

  final List<Map<String, dynamic>> _modes = [
    {'label': 'Keşif', 'icon': Icons.explore_rounded, 'color': AppColors.modeKesif},
    {'label': 'Sakinlik', 'icon': Icons.spa_rounded, 'color': AppColors.modeSakinlik},
    {'label': 'Sosyal', 'icon': Icons.people_rounded, 'color': AppColors.modeSosyal},
    {'label': 'Üretkenlik', 'icon': Icons.laptop_mac_rounded, 'color': AppColors.modeUretkenlik},
    {'label': 'Eğlence', 'icon': Icons.celebration_rounded, 'color': AppColors.modeEglence},
    {'label': 'Açık Alan', 'icon': Icons.park_rounded, 'color': AppColors.modeAcikAlan},
    {'label': 'Topluluk', 'icon': Icons.group_work_rounded, 'color': AppColors.modeTopluluk},
    {'label': 'Aile', 'icon': Icons.family_restroom_rounded, 'color': AppColors.modeAcikAlan},
  ];

  // Demo öneriler
  final List<Map<String, dynamic>> _suggestions = [
    {
      'title': 'Sternschanze',
      'subtitle': 'Enerji yükseliyor',
      'pulse': 78,
      'density': 'Yoğun',
      'trend': '↑',
      'icon': Icons.local_fire_department_rounded,
      'color': AppColors.pulseHigh,
    },
    {
      'title': 'Altonaer Balkon',
      'subtitle': 'Sakin ve huzurlu',
      'pulse': 34,
      'density': 'Düşük',
      'trend': '→',
      'icon': Icons.park_rounded,
      'color': AppColors.pulseLow,
    },
    {
      'title': 'HafenCity',
      'subtitle': 'Akşama doğru hareketlenecek',
      'pulse': 55,
      'density': 'Orta',
      'trend': '↑',
      'icon': Icons.schedule_rounded,
      'color': AppColors.pulseMedium,
    },
  ];

  @override
  void initState() {
    super.initState();
    _startHomeFlow();
    _suggestionsController.addListener(() {
      final maxScroll = _suggestionsController.position.maxScrollExtent;
      final currentScroll = _suggestionsController.offset;
      final shouldShow = currentScroll < maxScroll - 20;
      if (shouldShow != _showScrollHint) {
        setState(() => _showScrollHint = shouldShow);
      }
    });
  }

  Future<void> _startHomeFlow() async {
    try {
      await _locationService.requestPermission();
    } catch (e, st) {
      debugPrint('Konum izni: $e\n$st');
    }
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _showMap = true);

    _positionSub = _locationService.positionStream.listen((pos) {
      if (!mounted) return;
      _currentPosition = pos;

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        _firestoreService.updateLocation(uid, pos.latitude, pos.longitude);
      }

      if (_mapboxMap != null &&
          _mapStyleReady &&
          DateTime.now().difference(_lastMapFlyTo).inSeconds > 30) {
        _lastMapFlyTo = DateTime.now();
        _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(pos.longitude, pos.latitude)),
            zoom: 14,
          ),
          MapAnimationOptions(duration: 1500),
        );
      }
    });
  }

  void _tryApplyInitialCamera() {
    if (_appliedInitialCamera || !_mapStyleReady || _mapboxMap == null) return;
    _appliedInitialCamera = true;

    final pos = _currentPosition;
    if (pos != null) {
      _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 14,
        ),
      );
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _suggestionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 12;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Stack(
        children: [
          // ── Harita ──
          if (_showMap)
            MapWidget(
              cameraOptions: CameraOptions(
                center: _kDefaultMapCenter,
                zoom: 13,
              ),
              styleUri: MapboxStyles.DARK,
              onMapCreated: (map) {
                _mapboxMap = map;
                _tryApplyInitialCamera();
              },
              onStyleLoadedListener: (data) {
                _mapStyleReady = true;
                _tryApplyInitialCamera();
              },
            )
          else
            Container(color: AppColors.bgMap),

          // ── Gradient overlay (üst) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bgMain.withOpacity(0.9),
                    AppColors.bgMain.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),

          // ── Gradient overlay (alt) ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 240,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.bgMain.withOpacity(0.95),
                    AppColors.bgMain.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),

          // ── Üst Bar ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Logo
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    children: [
                      TextSpan(text: 'Pulse', style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'City', style: TextStyle(color: AppColors.primary)),
                    ],
                  ),
                ),
                const Spacer(),
                // Pulse Score Badge
                GestureDetector(
                  onTap: () => _showPulseDetail(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '$_pulseScore',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Profil
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard.withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // ── Sağ taraf butonları ──
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 64,
            child: Column(
              children: [
                _buildMapButton(
                  Icons.my_location_rounded,
                  () {
                    if (_currentPosition != null && _mapboxMap != null) {
                      _mapboxMap!.flyTo(
                        CameraOptions(
                          center: Point(
                            coordinates: Position(
                              _currentPosition!.longitude,
                              _currentPosition!.latitude,
                            ),
                          ),
                          zoom: 15,
                        ),
                        MapAnimationOptions(duration: 1000),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                _buildMapButton(Icons.wifi_tethering_rounded, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignalScreen()),
                  );
                }),
                const SizedBox(height: 8),
                _buildMapButton(Icons.compass_calibration_rounded, () 
                {
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiscoverScreen()),
                  );
                }),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    _buildMapButton(Icons.chat_rounded, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InboxScreen()),
                      );
                    }),
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bgMain, width: 2),
                        ),
                        child: const Center(child: Text('3', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Alt Kısım ──
          Positioned(
            bottom: bottomPadding,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Öneri kartları + fade hint
                SizedBox(
                  height: 90,
                  child: Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification) {
                            setState(() {});
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _suggestionsController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _suggestions.length,
                          itemBuilder: (context, i) {
                            final s = _suggestions[i];
                            return _buildSuggestionCard(s);
                          },
                        ),
                      ),
                      // Sağ fade gradient
                      if (_showScrollHint)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 50,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppColors.bgMain.withOpacity(0),
                                    AppColors.bgMain.withOpacity(0.8),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withOpacity(0.3),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Mod seçici
                SizedBox(
                  height: 42,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _modes.length,
                    itemBuilder: (context, i) {
                      final isActive = i == _selectedMode;
                      final mode = _modes[i];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMode = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isActive
                                ? (mode['color'] as Color)
                                : AppColors.bgCard.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isActive
                                  ? (mode['color'] as Color).withOpacity(0.5)
                                  : Colors.white.withOpacity(0.08),
                              width: 0.5,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: (mode['color'] as Color).withOpacity(0.3),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                mode['icon'] as IconData,
                                size: 16,
                                color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                mode['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Detail Card ──
          if (_showBottomCard) _buildDetailCard(),
        ],
      ),
    );
  }

  // ── Öneri Kartı ──
  Widget _buildSuggestionCard(Map<String, dynamic> s) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showBottomCard = true;
          _selectedAreaName = s['title'];
          _pulseScore = s['pulse'];
          _densityLabel = s['density'];
        });
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(s['icon'] as IconData, size: 16, color: s['color'] as Color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s['title'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  s['subtitle'],
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (s['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${s['pulse']}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: s['color'] as Color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Harita Butonu ──
  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.bgCard.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
      ),
    );
  }

  // ── Pulse Detail Bottom Sheet ──
  void _showPulseDetail() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bölge Pulse Skoru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                '$_pulseScore',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_densityLabel  •  $_trendLabel',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 24),
              _buildScoreRow('Yoğunluk', 0.65, AppColors.densityMedium),
              const SizedBox(height: 12),
              _buildScoreRow('Enerji', 0.78, AppColors.pulseHigh),
              const SizedBox(height: 12),
              _buildScoreRow('Tazelik', 0.90, AppColors.success),
              const SizedBox(height: 12),
              _buildScoreRow('Güvenilirlik', 0.82, AppColors.modeSosyal),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '20 dk içinde yoğunluk artacak. Şimdi git!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoreRow(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(value * 100).toInt()}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  // ── Detail Card (alan tıklanınca) ──
  Widget _buildDetailCard() {
    return Positioned(
      bottom: 170,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () => setState(() => _showBottomCard = false),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _selectedAreaName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_pulseScore',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTag(_densityLabel, AppColors.densityMedium),
                  const SizedBox(width: 8),
                  _buildTag(_trendLabel, AppColors.success),
                  const SizedBox(width: 8),
                  _buildTag('Şu an ideal', AppColors.primary),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Kapat',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}