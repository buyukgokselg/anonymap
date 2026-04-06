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
import '../widgets/animated_press.dart';
import '../widgets/page_transitions.dart';
import '../services/places_service.dart';

final Point _kDefaultMapCenter =
    Point(coordinates: Position(9.9872, 53.5488));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _selectedMode = 0;

  final _locationService = LocationService();
  final _firestoreService = FirestoreService();
  final _placesService = PlacesService();
  final ScrollController _suggestionsController = ScrollController();

  geo.Position? _currentPosition;
  MapboxMap? _mapboxMap;
  StreamSubscription<geo.Position>? _positionSub;

  DateTime _lastMapFlyTo = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPlacesFetch = DateTime.fromMillisecondsSinceEpoch(0);

  bool _showMap = false;
  bool _mapStyleReady = false;
  bool _heatmapAdded = false;
  bool _showPlaceDetail = false;
  bool _appliedInitialCamera = false;
  bool _loadingPlaces = false;
  bool _showBottomCard = false;
  bool _showScrollHint = true;
  bool _showModeInfo = false;

  List<Map<String, dynamic>> _nearbyPlaces = [];
  Map<String, dynamic>? _selectedPlace;

  int _pulseScore = 72;
  String _densityLabel = 'Orta';
  String _trendLabel = '↑ Yükseliyor';
  String _selectedAreaName = '';

  late AnimationController _modeTransitionController;
  late Animation<double> _modeTransitionAnim;

  ModeConfig get _currentMode => ModeConfig.all[_selectedMode];

  @override
  void initState() {
    super.initState();

    _modeTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _modeTransitionAnim = CurvedAnimation(
      parent: _modeTransitionController,
      curve: Curves.easeOut,
    );

    _startHomeFlow();

    _suggestionsController.addListener(() {
      if (!_suggestionsController.hasClients) return;

      final maxScroll = _suggestionsController.position.maxScrollExtent;
      final currentScroll = _suggestionsController.offset;
      final shouldShow = currentScroll < maxScroll - 20;

      if (shouldShow != _showScrollHint && mounted) {
        setState(() => _showScrollHint = shouldShow);
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _suggestionsController.dispose();
    _modeTransitionController.dispose();
    super.dispose();
  }

  Future<void> _startHomeFlow() async {
    try {
      await _locationService.requestPermission();
    } catch (e, st) {
      debugPrint('Konum izni hatası: $e\n$st');
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

      _maybeFetchPlaces();

      if (_mapboxMap != null &&
          _mapStyleReady &&
          DateTime.now().difference(_lastMapFlyTo).inSeconds > 30) {
        _lastMapFlyTo = DateTime.now();
        _flyToCoordinates(pos.longitude, pos.latitude, zoom: 14);
      }
    });
  }

  void _maybeFetchPlaces({bool force = false}) {
    if (_currentPosition == null || _loadingPlaces) return;

    final now = DateTime.now();
    final diff = now.difference(_lastPlacesFetch).inSeconds;

    if (!force && diff < 10 && _nearbyPlaces.isNotEmpty) return;

    _lastPlacesFetch = now;
    _fetchPlaces();
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

  void _flyToCoordinates(double lng, double lat, {double zoom = 14}) {
    if (_mapboxMap == null) return;

    _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  int _colorToRgba(Color c, double opacity) {
    final a = (opacity.clamp(0.0, 1.0) * 255).round();
    return (a << 24) | (c.red << 16) | (c.green << 8) | c.blue;
  }

  int _modeColorInt(double opacity) {
    return _colorToRgba(_currentMode.color, opacity);
  }

  Future<void> _addHeatmapLayer() async {
    if (_mapboxMap == null || !_mapStyleReady || _heatmapAdded) return;

    try {
      final geoJsonData = _generateDensityPoints();

      await _safeRemoveLayer('density-glow');
      await _safeRemoveLayer('density-mid');
      await _safeRemoveLayer('density-core');
      await _safeRemoveSource('density-source');

      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: 'density-source', data: geoJsonData),
      );

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'density-glow',
          sourceId: 'density-source',
          circleRadius: 45.0,
          circleColor: _colorToRgba(_currentMode.color, 0.15),
          circleBlur: 1.0,
          circleOpacity: 0.6,
        ),
      );

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'density-mid',
          sourceId: 'density-source',
          circleRadius: 25.0,
          circleColor: _colorToRgba(_currentMode.color, 0.30),
          circleBlur: 0.8,
          circleOpacity: 0.5,
        ),
      );

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'density-core',
          sourceId: 'density-source',
          circleRadius: 8.0,
          circleColor: _colorToRgba(_currentMode.color, 0.70),
          circleBlur: 0.3,
          circleOpacity: 0.8,
        ),
      );

      _heatmapAdded = true;
    } catch (e, st) {
      _heatmapAdded = false;
      debugPrint('Heatmap ekleme hatası: $e\n$st');
    }
  }

  String _generateDensityPoints() {
    final mode = _currentMode;
    final features = <String>[];

    for (final s in mode.suggestions) {
      final lat = (s['lat'] as num).toDouble();
      final lng = (s['lng'] as num).toDouble();
      final pulse = (s['pulse'] as num).toInt();
      final weight = (pulse / 100).clamp(0.1, 1.0);

      features.add(
        '{"type":"Feature","geometry":{"type":"Point","coordinates":[$lng,$lat]},"properties":{"weight":$weight}}',
      );

      final count = (pulse / 12).round();
      for (int i = 0; i < count; i++) {
        final offsetLat = (i.isEven ? 1 : -1) * (0.0008 + (i * 0.0004));
        final offsetLng = (i % 3 == 0 ? 1 : -1) * (0.0008 + (i * 0.0003));
        final pointWeight = (weight * (0.4 + (i % 3) * 0.2)).clamp(0.1, 1.0);

        features.add(
          '{"type":"Feature","geometry":{"type":"Point","coordinates":[${lng + offsetLng},${lat + offsetLat}]},"properties":{"weight":$pointWeight}}',
        );
      }
    }

    return '{"type":"FeatureCollection","features":[${features.join(",")}]}';
  }

  Future<void> _updateHeatmapForMode() async {
    if (_mapboxMap == null || !_mapStyleReady) return;

    _heatmapAdded = false;
    await _addHeatmapLayer();
  }

  Future<void> _fetchPlaces() async {
    final pos = _currentPosition;
    if (pos == null) return;

    if (mounted) {
      setState(() => _loadingPlaces = true);
    }

    try {
      final places = await _placesService.getNearbyPlaces(
        lat: pos.latitude,
        lng: pos.longitude,
        modeId: _currentMode.id,
      );

      if (!mounted) return;

      setState(() {
        _nearbyPlaces = places;
        _loadingPlaces = false;
      });

      await _addPlaceMarkers();
    } catch (e, st) {
      debugPrint('Mekan getirme hatası: $e\n$st');
      if (mounted) {
        setState(() => _loadingPlaces = false);
      }
    }
  }

  Future<void> _addPlaceMarkers() async {
    if (_mapboxMap == null || !_mapStyleReady || _nearbyPlaces.isEmpty) return;

    try {
      await _safeRemoveLayer('place-markers');
      await _safeRemoveLayer('place-labels');
      await _safeRemoveSource('places-source');

      final features = _nearbyPlaces.map((p) {
        final name = (p['name']?.toString() ?? '').replaceAll('"', r'\"');
        final rating = (p['rating'] as num?)?.toDouble() ?? 0.0;
        final isOpen = p['open_now'] == true ? 1 : 0;
        final lng = (p['lng'] as num?)?.toDouble() ?? 0.0;
        final lat = (p['lat'] as num?)?.toDouble() ?? 0.0;

        return '{"type":"Feature","geometry":{"type":"Point","coordinates":[$lng,$lat]},"properties":{"name":"$name","rating":$rating,"isOpen":$isOpen}}';
      }).join(',');

      await _mapboxMap!.style.addSource(
        GeoJsonSource(
          id: 'places-source',
          data: '{"type":"FeatureCollection","features":[$features]}',
        ),
      );

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'place-markers',
          sourceId: 'places-source',
          circleRadius: 6.0,
          circleColor: _modeColorInt(0.9),
          circleStrokeWidth: 2.0,
          circleStrokeColor: _modeColorInt(0.4),
        ),
      );
    } catch (e, st) {
      debugPrint('Marker ekleme hatası: $e\n$st');
    }
  }

  Future<void> _safeRemoveLayer(String id) async {
    try {
      await _mapboxMap?.style.removeStyleLayer(id);
    } catch (_) {}
  }

  Future<void> _safeRemoveSource(String id) async {
    try {
      await _mapboxMap?.style.removeStyleSource(id);
    } catch (_) {}
  }

  void _showPlaceDetailSheet(Map<String, dynamic> place) async {
    if (!mounted) return;

    setState(() {
      _selectedPlace = place;
      _showPlaceDetail = true;
    });

    final details = await _placesService.getPlaceDetails(place['place_id']);

    if (!mounted) return;

    final weekdayText =
        (details?['weekday_text'] as List?)?.cast<String>() ?? <String>[];
    final reviews = (details?['reviews'] as List?) ?? [];
    final phone = details?['phone']?.toString() ?? '';
    final website = details?['website']?.toString() ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final modeColor = _currentMode.color;
        final rating = (place['rating'] as num?)?.toDouble() ?? 0.0;
        final totalRatings = (place['user_ratings_total'] as num?)?.toInt() ?? 0;
        final isOpen = place['open_now'] == true;
        final photoRef = place['photo_reference'];

        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (photoRef != null)
                    Container(
                      height: 160,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.bgMain,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          PlacesService.getPhotoUrl(photoRef),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.image_rounded,
                              size: 40,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: modeColor,
                                strokeWidth: 2,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          place['name']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? AppColors.success.withOpacity(0.12)
                              : AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOpen ? 'Açık' : 'Kapalı',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                isOpen ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (place['vicinity'] != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            place['vicinity'].toString(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        if (i < rating.floor()) {
                          return const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: AppColors.warning,
                          );
                        }
                        if (i < rating) {
                          return const Icon(
                            Icons.star_half_rounded,
                            size: 18,
                            color: AppColors.warning,
                          );
                        }
                        return Icon(
                          Icons.star_border_rounded,
                          size: 18,
                          color: Colors.white.withOpacity(0.15),
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        '$rating',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($totalRatings)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: modeColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: modeColor.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(_currentMode.icon, size: 18, color: modeColor),
                        const SizedBox(width: 10),
                        Text(
                          '${_currentMode.label} modu için önerildi',
                          style: TextStyle(
                            fontSize: 13,
                            color: modeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (details != null) ...[
                    const SizedBox(height: 16),

                    if (weekdayText.isNotEmpty) ...[
                      Text(
                        'ÇALIŞMA SAATLERİ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.25),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...weekdayText.map(
                        (day) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.45),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (reviews.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'YORUMLAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.25),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...reviews.take(3).map((review) {
                        final reviewMap =
                            Map<String, dynamic>.from(review as Map);
                        final reviewRating =
                            (reviewMap['rating'] as num?)?.toInt() ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgMain.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      reviewMap['author']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ...List.generate(
                                    5,
                                    (i) => Icon(
                                      i < reviewRating
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 12,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                reviewMap['text']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.4),
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reviewMap['time']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    if (phone.isNotEmpty || website.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (phone.isNotEmpty)
                            Expanded(
                              child: _actionButton(
                                Icons.phone_rounded,
                                'Ara',
                                AppColors.success,
                                () {},
                              ),
                            ),
                          if (phone.isNotEmpty && website.isNotEmpty)
                            const SizedBox(width: 10),
                          if (website.isNotEmpty)
                            Expanded(
                              child: _actionButton(
                                Icons.language_rounded,
                                'Website',
                                AppColors.modeSosyal,
                                () {},
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          Icons.navigation_rounded,
                          'Yol Tarifi',
                          modeColor,
                          () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          Icons.bookmark_border_rounded,
                          'Kaydet',
                          Colors.white.withOpacity(0.5),
                          () {},
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    setState(() => _showPlaceDetail = false);
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onModeChanged(int index) {
    if (index == _selectedMode) return;

    setState(() {
      _selectedMode = index;
      _showBottomCard = false;
      _showModeInfo = true;
    });

    _modeTransitionController.forward(from: 0);
    _updateHeatmapForMode();
    _maybeFetchPlaces(force: true);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showModeInfo = false);
      }
    });

    final suggestions = _currentMode.suggestions;
    if (suggestions.isNotEmpty && _mapboxMap != null && _mapStyleReady) {
      final first = suggestions.first;
      final lng = (first['lng'] as num).toDouble();
      final lat = (first['lat'] as num).toDouble();
      _flyToCoordinates(lng, lat, zoom: 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 12;
    final modeColor = _currentMode.color;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Stack(
        children: [
          if (_showMap)
            MapWidget(
              cameraOptions: CameraOptions(
                center: _kDefaultMapCenter,
                zoom: 13,
              ),
              styleUri: MapboxStyles.STANDARD,
              onMapCreated: (map) {
                _mapboxMap = map;
                _tryApplyInitialCamera();
              },
              onStyleLoadedListener: (_) async {
                _mapStyleReady = true;
                _tryApplyInitialCamera();
                await _addHeatmapLayer();
                await _addPlaceMarkers();
              },
            )
          else
            Container(color: AppColors.bgMap),

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

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 260,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.bgMain.withOpacity(0.98),
                    modeColor.withOpacity(0.08),
                    AppColors.bgMain.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'Pulse',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'City',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showPulseDetail,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: modeColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: modeColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_pulseScore',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: modeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    SlideRightRoute(page: const ProfileScreen()),
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard.withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_showModeInfo)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 20,
              right: 20,
              child: AnimatedBuilder(
                animation: _modeTransitionAnim,
                builder: (_, child) => Opacity(
                  opacity: _modeTransitionAnim.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - _modeTransitionAnim.value)),
                    child: child,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: modeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: modeColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(_currentMode.icon, size: 20, color: modeColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentMode.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: modeColor,
                              ),
                            ),
                            Text(
                              _currentMode.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_currentMode.suggestions.length} öneri',
                        style: TextStyle(
                          fontSize: 11,
                          color: modeColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 64,
            child: Column(
              children: [
                _buildMapButton(Icons.my_location_rounded, () {
                  final pos = _currentPosition;
                  if (pos != null) {
                    _flyToCoordinates(pos.longitude, pos.latitude, zoom: 15);
                  }
                }),
                const SizedBox(height: 8),
                _buildMapButton(
                  Icons.wifi_tethering_rounded,
                  () => Navigator.push(
                    context,
                    FadeScaleRoute(page: const SignalScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  Icons.compass_calibration_rounded,
                  () => Navigator.push(
                    context,
                    SlideUpRoute(page: const DiscoverScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    _buildMapButton(
                      Icons.chat_rounded,
                      () => Navigator.push(
                        context,
                        SlideUpRoute(page: const InboxScreen()),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bgMain, width: 2),
                        ),
                        child: const Center(
                          child: Text(
                            '3',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Positioned(
            bottom: bottomPadding,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 100,
                  child: Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n is ScrollUpdateNotification && mounted) {
                            setState(() {});
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _suggestionsController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _currentMode.suggestions.length,
                          itemBuilder: (_, i) =>
                              _buildSuggestionCard(_currentMode.suggestions[i]),
                        ),
                      ),
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

                if (_nearbyPlaces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 14,
                          color: modeColor.withOpacity(0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'YAKININDAKI MEKANLAR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.25),
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        if (_loadingPlaces)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: modeColor.withOpacity(0.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _nearbyPlaces.length.clamp(0, 10),
                      itemBuilder: (_, i) {
                        final place = _nearbyPlaces[i];
                        final rating =
                            (place['rating'] as num?)?.toDouble() ?? 0.0;
                        final isOpen = place['open_now'] == true;

                        return AnimatedPress(
                          onTap: () => _showPlaceDetailSheet(place),
                          scaleDown: 0.96,
                          child: Container(
                            width: 180,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.bgCard.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: modeColor.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        place['name']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isOpen
                                            ? AppColors.success
                                            : AppColors.error.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 12,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$rating',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        place['vicinity']?.toString() ?? '',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 12),

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
                            color: isActive
                                ? mode.color
                                : AppColors.bgCard.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isActive
                                  ? mode.color.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.08),
                              width: 0.5,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: mode.color.withOpacity(0.3),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                mode.icon,
                                size: 16,
                                color: isActive
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.4),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                mode.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
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

          if (_showBottomCard) _buildDetailCard(),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> s) {
    final color = s['color'] as Color;
    final modeColor = _currentMode.color;

    return AnimatedPress(
      onTap: () {
        setState(() {
          _showBottomCard = true;
          _selectedAreaName = s['title']?.toString() ?? '';
          _pulseScore = (s['pulse'] as num?)?.toInt() ?? 0;
          _densityLabel = s['density']?.toString() ?? '';
        });

        final lat = (s['lat'] as num?)?.toDouble();
        final lng = (s['lng'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          _flyToCoordinates(lng, lat, zoom: 15);
        }
      },
      scaleDown: 0.96,
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: modeColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: modeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    s['icon'] as IconData,
                    size: 15,
                    color: modeColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s['title']?.toString() ?? '',
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
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s['subtitle']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_rounded, size: 10, color: color),
                      const SizedBox(width: 3),
                      Text(
                        '${s['pulse']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return AnimatedPress(
      onTap: onTap,
      scaleDown: 0.9,
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

  void _showPulseDetail() {
    final modeColor = _currentMode.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$_pulseScore',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: modeColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_densityLabel  •  $_trendLabel',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: modeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_currentMode.icon, size: 14, color: modeColor),
                  const SizedBox(width: 6),
                  Text(
                    '${_currentMode.label} Modu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: modeColor,
                    ),
                  ),
                ],
              ),
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
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: modeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: modeColor.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_rounded, size: 18, color: modeColor),
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
      ),
    );
  }

  Widget _buildScoreRow(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
            ),
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard() {
    final modeColor = _currentMode.color;

    return Positioned(
      bottom: 180,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () => setState(() => _showBottomCard = false),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: modeColor.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(color: modeColor.withOpacity(0.1), blurRadius: 20),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: modeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 12,
                          color: modeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_pulseScore',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: modeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTag(_densityLabel, modeColor),
                  const SizedBox(width: 8),
                  _buildTag(_trendLabel, AppColors.success),
                  const SizedBox(width: 8),
                  _buildTag('${_currentMode.label} modu', modeColor),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Kapat',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.25),
                ),
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}