import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../theme/colors.dart';
import '../config/mode_config.dart';
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

  int _pulseScore = 72;
  String _densityLabel = 'Orta';
  String _trendLabel = '↑ Yükseliyor';

  bool _showBottomCard = false;
  String _selectedAreaName = '';
  final ScrollController _suggestionsController = ScrollController();
  bool _showScrollHint = true;

  // Mod değişim animasyonu
  late AnimationController _modeTransitionController;
  late Animation<double> _modeTransitionAnim;
  bool _showModeInfo = false;

  ModeConfig get _currentMode => ModeConfig.all[_selectedMode];

  @override
  void initState() {
    super.initState();

    _modeTransitionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _modeTransitionAnim = CurvedAnimation(parent: _modeTransitionController, curve: Curves.easeOut);

    _startHomeFlow();

    _suggestionsController.addListener(() {
      final maxScroll = _suggestionsController.position.maxScrollExtent;
      final currentScroll = _suggestionsController.offset;
      final shouldShow = currentScroll < maxScroll - 20;
      if (shouldShow != _showScrollHint) setState(() => _showScrollHint = shouldShow);
    });
  }

  Future<void> _startHomeFlow() async {
    try { await _locationService.requestPermission(); } catch (e, st) { debugPrint('Konum izni: $e\n$st'); }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _showMap = true);

    _positionSub = _locationService.positionStream.listen((pos) {
      if (!mounted) return;
      _currentPosition = pos;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) _firestoreService.updateLocation(uid, pos.latitude, pos.longitude);

      if (_mapboxMap != null && _mapStyleReady && DateTime.now().difference(_lastMapFlyTo).inSeconds > 30) {
        _lastMapFlyTo = DateTime.now();
        _mapboxMap!.flyTo(CameraOptions(center: Point(coordinates: Position(pos.longitude, pos.latitude)), zoom: 14), MapAnimationOptions(duration: 1500));
      }
    });
  }

  void _tryApplyInitialCamera() {
    if (_appliedInitialCamera || !_mapStyleReady || _mapboxMap == null) return;
    _appliedInitialCamera = true;
    final pos = _currentPosition;
    if (pos != null) {
      _mapboxMap!.setCamera(CameraOptions(center: Point(coordinates: Position(pos.longitude, pos.latitude)), zoom: 14));
    }
  }

  void _onModeChanged(int index) {
    if (index == _selectedMode) return;
    setState(() {
      _selectedMode = index;
      _showBottomCard = false;
      _showModeInfo = true;
    });

    _modeTransitionController.forward(from: 0);

    // Mod bilgi kartını 3 saniye sonra kapat
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showModeInfo = false);
    });

    // Haritayı ilk öneriye uçur
    final suggestions = _currentMode.suggestions;
    if (suggestions.isNotEmpty && _mapboxMap != null && _mapStyleReady) {
      final first = suggestions.first;
      _mapboxMap!.flyTo(
        CameraOptions(center: Point(coordinates: Position(first['lng'] as double, first['lat'] as double)), zoom: 14),
        MapAnimationOptions(duration: 1200),
      );
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _suggestionsController.dispose();
    _modeTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 12;
    final modeColor = _currentMode.color;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Stack(
        children: [
          // ── Harita ──
          if (_showMap)
            MapWidget(
              cameraOptions: CameraOptions(center: _kDefaultMapCenter, zoom: 13),
              styleUri: MapboxStyles.DARK,
              onMapCreated: (map) { _mapboxMap = map; _tryApplyInitialCamera(); },
              onStyleLoadedListener: (data) { _mapStyleReady = true; _tryApplyInitialCamera(); },
            )
          else
            Container(color: AppColors.bgMap),

          // ── Mod renk overlay (harita üstü) ──
          AnimatedBuilder(
            animation: _modeTransitionAnim,
            builder: (_, __) {
              return IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  color: modeColor.withOpacity(0.06),
                ),
              );
            },
          ),

          // ── Gradient overlay (üst) ──
          Positioned(
            top: 0, left: 0, right: 0, height: 140,
            child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.bgMain.withOpacity(0.9), AppColors.bgMain.withOpacity(0)])),
            ),
          ),

          // ── Gradient overlay (alt — mod renginde) ──
          Positioned(
            bottom: 0, left: 0, right: 0, height: 260,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [
                  AppColors.bgMain.withOpacity(0.98),
                  modeColor.withOpacity(0.08),
                  AppColors.bgMain.withOpacity(0),
                ]),
              ),
            ),
          ),

          // ── Üst Bar ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16,
            child: Row(
              children: [
                RichText(text: const TextSpan(style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5), children: [
                  TextSpan(text: 'Pulse', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'City', style: TextStyle(color: AppColors.primary)),
                ])),
                const Spacer(),
                GestureDetector(
                  onTap: _showPulseDetail,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.bgCard.withOpacity(0.9), borderRadius: BorderRadius.circular(30), border: Border.all(color: modeColor.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.favorite_rounded, size: 16, color: modeColor),
                      const SizedBox(width: 6),
                      Text('$_pulseScore', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: modeColor)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.bgCard.withOpacity(0.9), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 20)),
                ),
              ],
            ),
          ),

          // ── Mod bilgi kartı (geçici) ──
          if (_showModeInfo)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60, left: 20, right: 20,
              child: AnimatedBuilder(
                animation: _modeTransitionAnim,
                builder: (_, child) => Opacity(opacity: _modeTransitionAnim.value.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 10 * (1 - _modeTransitionAnim.value)), child: child)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: modeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: modeColor.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    Icon(_currentMode.icon, size: 20, color: modeColor),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_currentMode.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: modeColor)),
                      Text(_currentMode.description, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
                    ])),
                    Text('${_currentMode.suggestions.length} öneri', style: TextStyle(fontSize: 11, color: modeColor.withOpacity(0.6))),
                  ]),
                ),
              ),
            ),

          // ── Sağ taraf butonları ──
          Positioned(
            right: 16, top: MediaQuery.of(context).padding.top + 64,
            child: Column(children: [
              _buildMapButton(Icons.my_location_rounded, () {
                if (_currentPosition != null && _mapboxMap != null) {
                  _mapboxMap!.flyTo(CameraOptions(center: Point(coordinates: Position(_currentPosition!.longitude, _currentPosition!.latitude)), zoom: 15), MapAnimationOptions(duration: 1000));
                }
              }),
              const SizedBox(height: 8),
              _buildMapButton(Icons.wifi_tethering_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignalScreen()))),
              const SizedBox(height: 8),
              _buildMapButton(Icons.compass_calibration_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoverScreen()))),
              const SizedBox(height: 8),
              Stack(children: [
                _buildMapButton(Icons.chat_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()))),
                Positioned(top: 0, right: 0, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.bgMain, width: 2)),
                  child: const Center(child: Text('3', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))))),
              ]),
            ]),
          ),

          // ── Alt Kısım ──
          Positioned(
            bottom: bottomPadding, left: 0, right: 0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Öneri kartları
              SizedBox(
                height: 100,
                child: Stack(children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (n) { if (n is ScrollUpdateNotification) setState(() {}); return false; },
                    child: ListView.builder(
                      controller: _suggestionsController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _currentMode.suggestions.length,
                      itemBuilder: (_, i) => _buildSuggestionCard(_currentMode.suggestions[i]),
                    ),
                  ),
                  if (_showScrollHint)
                    Positioned(right: 0, top: 0, bottom: 0, width: 50, child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [AppColors.bgMain.withOpacity(0), AppColors.bgMain.withOpacity(0.8)])),
                        child: Center(child: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 22)),
                      ),
                    )),
                ]),
              ),

              const SizedBox(height: 12),

              // Mod seçici
              SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ModeConfig.all.length,
                  itemBuilder: (_, i) {
                    final isActive = i == _selectedMode;
                    final mode = ModeConfig.all[i];
                    return GestureDetector(
                      onTap: () => _onModeChanged(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isActive ? mode.color : AppColors.bgCard.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: isActive ? mode.color.withOpacity(0.5) : Colors.white.withOpacity(0.08), width: 0.5),
                          boxShadow: isActive ? [BoxShadow(color: mode.color.withOpacity(0.3), blurRadius: 12)] : null,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(mode.icon, size: 16, color: isActive ? Colors.white : Colors.white.withOpacity(0.4)),
                          const SizedBox(width: 6),
                          Text(mode.label, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? Colors.white : Colors.white.withOpacity(0.4))),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),

          if (_showBottomCard) _buildDetailCard(),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> s) {
    final color = s['color'] as Color;
    final modeColor = _currentMode.color;

    return GestureDetector(
      onTap: () {
        setState(() { _showBottomCard = true; _selectedAreaName = s['title']; _pulseScore = s['pulse']; _densityLabel = s['density']; });
        if (_mapboxMap != null && s['lat'] != null && s['lng'] != null) {
          _mapboxMap!.flyTo(CameraOptions(center: Point(coordinates: Position(s['lng'] as double, s['lat'] as double)), zoom: 15), MapAnimationOptions(duration: 1000));
        }
      },
      child: Container(
        width: 210, margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard.withOpacity(0.9), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: modeColor.withOpacity(0.1)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: modeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(s['icon'] as IconData, size: 15, color: modeColor)),
            const SizedBox(width: 10),
            Expanded(child: Text(s['title'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text(s['subtitle'], style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.favorite_rounded, size: 10, color: color),
                const SizedBox(width: 3),
                Text('${s['pulse']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.bgCard.withOpacity(0.9), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Icon(icon, color: Colors.white.withOpacity(0.7), size: 20)),
    );
  }

  void _showPulseDetail() {
    final modeColor = _currentMode.color;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Bölge Pulse Skoru', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 16),
          Text('$_pulseScore', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: modeColor)),
          const SizedBox(height: 6),
          Text('$_densityLabel  •  $_trendLabel', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: modeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_currentMode.icon, size: 14, color: modeColor),
              const SizedBox(width: 6),
              Text('${_currentMode.label} Modu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: modeColor)),
            ]),
          ),
          const SizedBox(height: 20),
          _buildScoreRow('Yoğunluk', 0.65, AppColors.densityMedium),
          const SizedBox(height: 10),
          _buildScoreRow('Enerji', 0.78, AppColors.pulseHigh),
          const SizedBox(height: 10),
          _buildScoreRow('Tazelik', 0.90, AppColors.success),
          const SizedBox(height: 10),
          _buildScoreRow('Güvenilirlik', 0.82, AppColors.modeSosyal),
          const SizedBox(height: 20),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: modeColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: modeColor.withOpacity(0.15))),
            child: Row(children: [
              Icon(Icons.lightbulb_rounded, size: 18, color: modeColor),
              const SizedBox(width: 10),
              Expanded(child: Text('20 dk içinde yoğunluk artacak. Şimdi git!', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500))),
            ]),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ]),
      ),
    );
  }

  Widget _buildScoreRow(String label, double value, Color color) {
    return Row(children: [
      SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: value, backgroundColor: Colors.white.withOpacity(0.08), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6))),
      const SizedBox(width: 10),
      Text('${(value * 100).toInt()}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _buildDetailCard() {
    final modeColor = _currentMode.color;
    return Positioned(
      bottom: 180, left: 16, right: 16,
      child: GestureDetector(
        onTap: () => setState(() => _showBottomCard = false),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withOpacity(0.95), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: modeColor.withOpacity(0.15)),
            boxShadow: [BoxShadow(color: modeColor.withOpacity(0.1), blurRadius: 20)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_selectedAreaName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: modeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.favorite_rounded, size: 12, color: modeColor),
                  const SizedBox(width: 4),
                  Text('$_pulseScore', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: modeColor)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _buildTag(_densityLabel, modeColor),
              const SizedBox(width: 8),
              _buildTag(_trendLabel, AppColors.success),
              const SizedBox(width: 8),
              _buildTag('${_currentMode.label} modu', modeColor),
            ]),
            const SizedBox(height: 6),
            Text('Kapat', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25))),
          ]),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}