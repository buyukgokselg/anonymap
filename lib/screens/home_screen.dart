import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../models/shorts_feed_scope.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'discover_people_screen.dart';
import 'matches_screen.dart';
import 'shorts_screen.dart';
import 'create_post_screen.dart';
import 'activity_detail_screen.dart';
import 'create_activity_screen.dart';
import '../widgets/animated_press.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/page_transitions.dart';
import '../services/places_service.dart';
import '../services/activity_service.dart';
import '../models/user_model.dart';
import '../models/activity_model.dart';
import '../navigation/app_route_observer.dart';
import '../config/app_features.dart';
import '../services/place_focus_service.dart';
import '../services/realtime_service.dart';
import '../widgets/shimmer_loading.dart';

final Point _kDefaultMapCenter = Point(coordinates: Position(9.9872, 53.5488));

/// Top-level "what am I looking at" lens for the map.
/// people = nearby users + place heatmap (the legacy mode-driven view).
/// activities = pinned upcoming activities (host-created events).
enum HomeLens { people, activities }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, RouteAware {
  int _selectedMode = 0;
  int _selectedPlaceLens = 0;
  HomeLens _currentLens = HomeLens.people;

  final _locationService = LocationService();
  final _firestoreService = FirestoreService();
  final _placesService = PlacesService();
  final ScrollController _modeSelectorController = ScrollController();
  final ScrollController _suggestionsController = ScrollController();
  final List<GlobalKey> _modeChipKeys = List<GlobalKey>.generate(
    ModeConfig.all.length,
    (_) => GlobalKey(),
  );

  geo.Position? _currentPosition;
  MapboxMap? _mapboxMap;
  StreamSubscription<geo.Position>? _positionSub;
  StreamSubscription<PlaceFocusRequest>? _placeFocusSub;
  StreamSubscription<void>? _presenceChangedSub;
  StreamSubscription? _authSub;
  Timer? _presenceRefreshDebounce;
  Timer? _nearbyRefreshTimer;

  DateTime _lastMapFlyTo = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPlacesFetch = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastLocationSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastRenderedPlacesSignature = '';
  geo.Position? _lastSyncedPosition;

  bool _showMap = false;
  bool _mapStyleReady = false;
  bool _heatmapAdded = false;
  bool _appliedInitialCamera = false;
  bool _loadingPlaces = false;
  bool _showBottomCard = false;
  bool _showScrollHint = true;
  bool _showModeInfo = false;
  bool _heroCollapsed = true;
  bool _bottomDeckCollapsed = true;
  bool _loadingPopularPlaces = false;

  List<Map<String, dynamic>> _nearbyPlaces = [];
  List<Map<String, dynamic>> _popularPlaces = [];
  List<UserModel> _modeNearbyUsers = [];
  List<ActivityModel> _nearbyActivities = [];
  Map<String, dynamic>? _selectedPlace;
  String _popularPlacesCacheKey = '';
  bool _loadingActivities = false;
  DateTime _lastActivitiesFetch = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<void>? _activityListSub;

  int _pulseScore = 72;
  String _densityLabel = 'Orta';
  String _trendLabel = 'Yukseliyor';
  String _selectedAreaName = '';

  late AnimationController _modeTransitionController;
  late Animation<double> _modeTransitionAnim;

  ModeConfig get _currentMode => ModeConfig.all[_selectedMode];
  String get _myUid => AuthService().currentUserId;

  List<Map<String, dynamic>> get _headlinePlaces {
    final pos = _currentPosition;
    if (pos == null || _nearbyPlaces.isEmpty) return _nearbyPlaces;
    return _placesService.rankPlacesForMoment(
      _nearbyPlaces,
      modeId: _currentMode.id,
      userLat: pos.latitude,
      userLng: pos.longitude,
    );
  }

  List<Map<String, dynamic>> get _activeNearbyPlaces {
    final pos = _currentPosition;
    if (pos == null || _nearbyPlaces.isEmpty) return _nearbyPlaces;
    return _placesService.rankPlacesForMoment(
      _nearbyPlaces,
      modeId: _currentMode.id,
      userLat: pos.latitude,
      userLng: pos.longitude,
      requireOpenNow: true,
    );
  }

  List<Map<String, dynamic>> get _visibleHeadlinePlaces {
    switch (_selectedPlaceLens) {
      case 1:
        final base = List<Map<String, dynamic>>.from(_headlinePlaces);
        if (base.isEmpty) return base;
        base.sort(
          (a, b) => _nearbyPriorityScore(b).compareTo(_nearbyPriorityScore(a)),
        );
        return base;
      case 2:
        final base = List<Map<String, dynamic>>.from(
          _popularPlaces.isNotEmpty ? _popularPlaces : _headlinePlaces,
        );
        if (base.isEmpty) return base;
        base.sort(
          (a, b) =>
              _popularPriorityScore(b).compareTo(_popularPriorityScore(a)),
        );
        return base;
      case 3:
        final base = List<Map<String, dynamic>>.from(_headlinePlaces);
        if (base.isEmpty) return base;
        final openNow = _activeNearbyPlaces;
        return openNow.isNotEmpty ? openNow : base;
      default:
        final base = List<Map<String, dynamic>>.from(_headlinePlaces);
        return base;
    }
  }

  @override
  void initState() {
    super.initState();

    _authSub = AuthService().authStateChanges.listen((session) {
      if (session == null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    });

    _modeTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _modeTransitionAnim = CurvedAnimation(
      parent: _modeTransitionController,
      curve: Curves.easeOut,
    );

    _selectedMode = _modeIndexForId(AuthService().currentUser?.mode);
    _placeFocusSub = PlaceFocusService.instance.requests.listen(
      (request) => unawaited(_handlePlaceFocusRequest(request)),
      onError: (e) => debugPrint('PlaceFocus stream error: $e'),
    );
    _presenceChangedSub = RealtimeService.instance.presenceChanged.listen((_) {
      _presenceRefreshDebounce?.cancel();
      _presenceRefreshDebounce = Timer(const Duration(milliseconds: 900), () {
        if (!mounted || _currentPosition == null) return;
        _maybeFetchPlaces(force: true);
      });
    });
    _activityListSub = ActivityService.instance.listChanged.listen((_) {
      if (!mounted || _currentPosition == null) return;
      if (_currentLens != HomeLens.activities) return;
      unawaited(_fetchNearbyActivities(force: true));
    });
    _startHomeFlow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = PlaceFocusService.instance.takePendingRequest();
      if (pending != null) {
        unawaited(_handlePlaceFocusRequest(pending));
      }
      _centerSelectedModeChip(animate: false);
    });

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
    appRouteObserver.unsubscribe(this);
    _authSub?.cancel();
    _positionSub?.cancel();
    _placeFocusSub?.cancel();
    _presenceChangedSub?.cancel();
    _activityListSub?.cancel();
    _modeSelectorController.dispose();
    _presenceRefreshDebounce?.cancel();
    _nearbyRefreshTimer?.cancel();
    _suggestionsController.dispose();
    _modeTransitionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _syncModeFromSession(refreshData: true);
  }

  @override
  void didPush() {
    _syncModeFromSession(refreshData: true);
  }

  int _modeIndexForId(String? modeId) {
    final index = ModeConfig.all.indexWhere((mode) => mode.id == modeId);
    return index >= 0 ? index : 0;
  }

  void _syncModeFromSession({bool refreshData = false}) {
    final sessionModeId = AuthService().currentUser?.mode;
    final index = _modeIndexForId(sessionModeId);
    if (index != _selectedMode) {
      _applyModeSelection(
        index,
        persist: false,
        focusTopPlace: refreshData,
        showInfo: false,
      );
      return;
    }

    if (refreshData) {
      _lastRenderedPlacesSignature = '';
      _updateHeatmapForMode();
      _maybeFetchPlaces(force: true);
    }
  }

  Future<void> _handlePlaceFocusRequest(PlaceFocusRequest request) async {
    Map<String, dynamic>? resolvedPlace;
    for (final place in _nearbyPlaces) {
      final sameId =
          request.placeId.isNotEmpty &&
          (place['place_id']?.toString() ?? '') == request.placeId;
      final sameName =
          request.placeName.isNotEmpty &&
          (place['name']?.toString() ?? '').trim().toLowerCase() ==
              request.placeName.trim().toLowerCase();
      if (sameId || sameName) {
        resolvedPlace = Map<String, dynamic>.from(place);
        break;
      }
    }

    if (resolvedPlace == null && request.placeId.isNotEmpty) {
      final details = await _placesService.getPlaceDetails(request.placeId);
      resolvedPlace = {
        'place_id': request.placeId,
        'name': request.placeName.isNotEmpty
            ? request.placeName
            : (details?['name'] ?? ''),
        'vicinity': details?['address'] ?? request.placeName,
        'lat': request.latitude ?? details?['lat'],
        'lng': request.longitude ?? details?['lng'],
        ...?details,
      };
    } else if (resolvedPlace == null &&
        request.placeName.isNotEmpty &&
        request.hasCoordinates) {
      resolvedPlace = {
        'place_id': request.placeId,
        'name': request.placeName,
        'vicinity': request.placeName,
        'lat': request.latitude,
        'lng': request.longitude,
      };
    }

    if (!mounted || resolvedPlace == null) return;

    final lat = (resolvedPlace['lat'] as num?)?.toDouble();
    final lng = (resolvedPlace['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      _flyToCoordinates(lng, lat, zoom: 15.2);
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    _showPlaceDetailSheet(resolvedPlace);
  }

  Future<void> _startHomeFlow() async {
    _syncModeFromSession();

    try {
      await _locationService.requestPermission();
    } catch (e, st) {
      debugPrint('Konum izni hatasi: $e\n$st');
    }

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() => _showMap = true);
    _nearbyRefreshTimer?.cancel();
    _nearbyRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || _currentPosition == null || _loadingPlaces) return;
      unawaited(_fetchPlaces());
    });

    _positionSub = _locationService.positionStream.listen((pos) {
      if (!mounted) return;

      _currentPosition = pos;
      if (_mapboxMap != null) {
        unawaited(_applyUserLocationPuck(_mapboxMap!));
      }

      final uid = _myUid;
      if (uid.isNotEmpty) {
        unawaited(_syncLocationIfNeeded(uid, pos));
      }

      _maybeFetchPlaces();
      if (_currentLens == HomeLens.activities) {
        unawaited(_fetchNearbyActivities());
      }

      if (_mapboxMap != null &&
          _mapStyleReady &&
          DateTime.now().difference(_lastMapFlyTo).inSeconds > 30) {
        _lastMapFlyTo = DateTime.now();
        _flyToCoordinates(pos.longitude, pos.latitude, zoom: 14);
      }
    }, onError: (e) => debugPrint('Position stream error: $e'));
  }

  void _maybeFetchPlaces({bool force = false}) {
    if (_currentPosition == null || _loadingPlaces) return;

    final now = DateTime.now();
    final diff = now.difference(_lastPlacesFetch).inSeconds;

    if (!force && diff < 20 && _nearbyPlaces.isNotEmpty) return;

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
    final r = (c.r * 255).round().clamp(0, 255);
    final g = (c.g * 255).round().clamp(0, 255);
    final b = (c.b * 255).round().clamp(0, 255);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  int _modeColorInt(double opacity) {
    return _colorToRgba(_currentMode.color, opacity);
  }

  Future<void> _addHeatmapLayer() async {
    if (_mapboxMap == null || !_mapStyleReady || _heatmapAdded) return;

    try {
      final geoJsonData = _generateDensityPoints();

      await _safeRemoveLayer('density-heat');
      await _safeRemoveLayer('density-glow');
      await _safeRemoveLayer('density-mid');
      await _safeRemoveLayer('density-core');
      await _safeRemoveSource('density-source');

      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: 'density-source', data: geoJsonData),
      );

      await _mapboxMap!.style.addLayer(
        HeatmapLayer(
          id: 'density-heat',
          sourceId: 'density-source',
          maxZoom: 17,
          heatmapOpacity: 0.68,
          heatmapIntensityExpression: <Object>[
            'interpolate',
            <Object>['linear'],
            <Object>['zoom'],
            0,
            0.6,
            10,
            0.9,
            14,
            1.15,
          ],
          heatmapRadiusExpression: <Object>[
            'interpolate',
            <Object>['linear'],
            <Object>['zoom'],
            0,
            16,
            10,
            24,
            14,
            38,
          ],
          heatmapWeightExpression: <Object>[
            'coalesce',
            <Object>['get', 'weight'],
            0.12,
          ],
          heatmapColorExpression: const <Object>[
            'interpolate',
            ['linear'],
            ['heatmap-density'],
            0,
            'rgba(146, 156, 169, 0)',
            0.2,
            'rgba(146, 156, 169, 0.10)',
            0.4,
            'rgba(154, 166, 181, 0.16)',
            0.6,
            'rgba(165, 178, 194, 0.24)',
            0.8,
            'rgba(182, 196, 214, 0.32)',
            1,
            'rgba(202, 215, 232, 0.42)',
          ],
        ),
      );

      _heatmapAdded = true;
    } catch (e, st) {
      _heatmapAdded = false;
      debugPrint('Heatmap ekleme hatasi: $e\n$st');
    }
  }

  String _generateDensityPoints() {
    final points = _nearbyPlaces.take(24).toList();
    final features = <String>[];

    for (final s in points) {
      final lat = (s['lat'] as num).toDouble();
      final lng = (s['lng'] as num).toDouble();
      final pulse =
          (s['pulse_score'] as num?)?.toInt() ??
          (s['pulse'] as num?)?.toInt() ??
          0;
      final density =
          (s['density_score'] as num?)?.toDouble() ?? pulse.toDouble();
      final weight = (((density * 0.65) + (pulse * 0.35)) / 100).clamp(
        0.12,
        1.0,
      );

      features.add(
        '{"type":"Feature","geometry":{"type":"Point","coordinates":[$lng,$lat]},"properties":{"weight":$weight}}',
      );
    }

    return '{"type":"FeatureCollection","features":[${features.join(",")}]}';
  }

  String _generateModeUserPoints() {
    final features = _modeNearbyUsers
        .where((user) => user.location != null)
        .map((user) {
          final location = user.location!;
          final pulse = user.pulseScore.clamp(10, 100);
          final weight = (pulse / 100).clamp(0.2, 1.0);

          return '{"type":"Feature","geometry":{"type":"Point","coordinates":[${location.longitude},${location.latitude}]},"properties":{"weight":$weight}}';
        })
        .join(',');

    return '{"type":"FeatureCollection","features":[$features]}';
  }

  Future<void> _updateHeatmapForMode() async {
    if (_mapboxMap == null || !_mapStyleReady) return;

    _heatmapAdded = false;
    _lastRenderedPlacesSignature = '';
    await _syncMapDecorations(force: true);
  }

  Future<void> _fetchPlaces() async {
    final pos = _currentPosition;
    if (pos == null) return;
    final popularCacheKey = _popularPlacesCacheKeyFor(
      pos.latitude,
      pos.longitude,
      _currentMode.id,
    );
    if (_popularPlacesCacheKey != popularCacheKey &&
        (_popularPlaces.isNotEmpty || _popularPlacesCacheKey.isNotEmpty)) {
      _popularPlaces = [];
      _popularPlacesCacheKey = '';
    }

    if (mounted) {
      setState(() => _loadingPlaces = true);
    }

    try {
      final rawPlacesFuture = _placesService.getNearbyPlaces(
        lat: pos.latitude,
        lng: pos.longitude,
        modeId: _currentMode.id,
      );
      final nearbyUsersFuture = _myUid.isEmpty
          ? Future<List<UserModel>>.value(const <UserModel>[])
          : _firestoreService.getNearbyUsersList(
              _myUid,
              pos.latitude,
              pos.longitude,
              radiusKm: 1.6,
            );
      final rawPlaces = await rawPlacesFuture;
      final communitySignals = await _firestoreService
          .getCommunitySignalsForPlaces(rawPlaces);
      final nearbyUsers = await nearbyUsersFuture;
      final places = _placesService.mergePulseSignals(
        rawPlaces,
        communitySignals: communitySignals,
      );
      final rankedHeadline = _placesService.rankPlacesForMoment(
        places,
        modeId: _currentMode.id,
        userLat: pos.latitude,
        userLng: pos.longitude,
      );

      if (!mounted) return;

      setState(() {
        _nearbyPlaces = places;
        _modeNearbyUsers = nearbyUsers
            .where(
              (user) =>
                  user.location != null &&
                  user.mode == _currentMode.id &&
                  user.isVisible &&
                  user.isOnline,
            )
            .toList();
        final topPlace = rankedHeadline.isNotEmpty
            ? rankedHeadline.first
            : null;
        if (topPlace != null) {
          _pulseScore = (topPlace['pulse_score'] as num?)?.toInt() ?? 0;
          _densityLabel = topPlace['density_label']?.toString() ?? 'Orta';
          _trendLabel = topPlace['trend_label']?.toString() ?? 'Sabit';
          _selectedAreaName = topPlace['name']?.toString() ?? '';
        }
        _loadingPlaces = false;
      });
      _syncHeadlineSelection();
      if (_selectedPlaceLens == 2) {
        unawaited(_ensurePopularScopePlaces(force: true));
      }

      await _syncMapDecorations();
    } catch (e, st) {
      debugPrint('Mekan getirme hatasi: $e\n$st');
      if (mounted) {
        setState(() => _loadingPlaces = false);
      }
    }
  }

  Future<void> _addPlaceMarkers() async {
    if (_mapboxMap == null || !_mapStyleReady) return;

    try {
      await _safeRemoveLayer('place-markers');
      await _safeRemoveLayer('place-labels');
      await _safeRemoveSource('places-source');
      await _safeRemoveLayer('mode-user-glow');
      await _safeRemoveLayer('mode-user-core');
      await _safeRemoveSource('mode-users-source');

      if (_modeNearbyUsers.isEmpty) return;

      final features = _generateModeUserPoints();

      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: 'mode-users-source', data: features),
      );

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'mode-user-glow',
          sourceId: 'mode-users-source',
          circleRadiusExpression: const <Object>[
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            8,
            14,
            14,
          ],
          circleColor: _modeColorInt(0.22),
          circleBlur: 1.0,
          circleOpacity: 0.85,
        ),
      );

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'mode-user-core',
          sourceId: 'mode-users-source',
          circleRadiusExpression: const <Object>[
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            4,
            14,
            7,
          ],
          circleColor: _modeColorInt(0.95),
          circleStrokeWidth: 2.0,
          circleStrokeColor: _colorToRgba(Colors.white, 0.4),
          circleOpacity: 0.95,
        ),
      );
    } catch (e, st) {
      debugPrint('Kullanici marker ekleme hatasi: $e\n$st');
    }
  }

  // ignore: unused_element
  Future<void> _addLegacyPlaceMarkers() async {
    if (_mapboxMap == null || !_mapStyleReady || _nearbyPlaces.isEmpty) return;

    try {
      await _safeRemoveLayer('place-markers');
      await _safeRemoveLayer('place-labels');
      await _safeRemoveSource('places-source');

      final features = _nearbyPlaces
          .map((p) {
            final name = (p['name']?.toString() ?? '').replaceAll('"', r'\"');
            final rating = (p['rating'] as num?)?.toDouble() ?? 0.0;
            final isOpen = p['open_now'] == true ? 1 : 0;
            final lng = (p['lng'] as num?)?.toDouble() ?? 0.0;
            final lat = (p['lat'] as num?)?.toDouble() ?? 0.0;

            return '{"type":"Feature","geometry":{"type":"Point","coordinates":[$lng,$lat]},"properties":{"name":"$name","rating":$rating,"isOpen":$isOpen}}';
          })
          .join(',');

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
      debugPrint('Marker ekleme hatasi: $e\n$st');
    }
  }

  Future<void> _configureMapUi(MapboxMap map) async {
    try {
      await _applyUserLocationPuck(map);
      await map.compass.updateSettings(
        CompassSettings(enabled: false, visibility: false),
      );
      await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
      await map.logo.updateSettings(
        LogoSettings(
          enabled: true,
          position: OrnamentPosition.BOTTOM_LEFT,
          marginLeft: 12,
          marginBottom: 12,
        ),
      );
      await map.attribution.updateSettings(
        AttributionSettings(
          enabled: true,
          clickable: true,
          position: OrnamentPosition.BOTTOM_RIGHT,
          marginRight: 12,
          marginBottom: 12,
        ),
      );
    } catch (e, st) {
      debugPrint('Map UI ayarlari uygulanamadi: $e\n$st');
    }
  }

  Future<void> _applyUserLocationPuck(MapboxMap map) async {
    try {
      await map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: _modeColorInt(0.34),
          pulsingMaxRadius: 24,
          showAccuracyRing: false,
          puckBearingEnabled: true,
          puckBearing: PuckBearing.HEADING,
          locationPuck: LocationPuck(
            locationPuck2D: DefaultLocationPuck2D(
              scaleExpression:
                  '["interpolate",["linear"],["zoom"],8,0.78,14,1.05,18,1.18]',
              opacity: 0.96,
            ),
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('User puck uygulanamadi: $e\n$st');
    }
  }

  String _mapRenderSignature() {
    return _nearbyPlaces
        .take(10)
        .map(
          (place) =>
              '${place['place_id']}:${place['pulse_score']}:${place['open_now']}:${place['lat']}:${place['lng']}',
        )
        .join('|');
  }

  String _mapUserSignature() {
    return _modeNearbyUsers
        .take(20)
        .map(
          (user) =>
              '${user.uid}:${user.mode}:${user.pulseScore}:${user.location?.latitude}:${user.location?.longitude}',
        )
        .join('|');
  }

  Future<void> _syncMapDecorations({bool force = false}) async {
    if (_mapboxMap == null || !_mapStyleReady) return;

    // When the activity lens is active, hide places/people decorations and
    // render activity pins instead.
    if (_currentLens == HomeLens.activities) {
      await _safeRemoveLayer('density-heat');
      await _safeRemoveLayer('mode-user-glow');
      await _safeRemoveLayer('mode-user-core');
      await _safeRemoveSource('density-source');
      await _safeRemoveSource('mode-users-source');

      final signature =
          'activities|${_currentMode.id}|${_mapActivitySignature()}';
      if (!force && signature == _lastRenderedPlacesSignature) {
        return;
      }
      _lastRenderedPlacesSignature = signature;
      _heatmapAdded = false;
      await _addActivityMarkers();
      return;
    }

    // People lens — clear any leftover activity layers, then render the
    // legacy places + nearby-users decorations.
    await _safeRemoveLayer('activity-pin-glow');
    await _safeRemoveLayer('activity-pin-core');
    await _safeRemoveSource('activities-source');

    if (_nearbyPlaces.isEmpty) {
      await _safeRemoveLayer('density-heat');
      await _safeRemoveLayer('mode-user-glow');
      await _safeRemoveLayer('mode-user-core');
      await _safeRemoveSource('density-source');
      await _safeRemoveSource('mode-users-source');
      return;
    }

    final signature =
        'people|${_currentMode.id}|$_selectedPlaceLens|${_mapRenderSignature()}|${_mapUserSignature()}';
    if (!force && signature == _lastRenderedPlacesSignature) {
      return;
    }

    _lastRenderedPlacesSignature = signature;
    _heatmapAdded = false;
    await _addHeatmapLayer();
    await _addPlaceMarkers();
  }

  String _mapActivitySignature() {
    return _nearbyActivities
        .take(40)
        .map(
          (a) =>
              '${a.id}:${a.latitude}:${a.longitude}:${a.startsAt.millisecondsSinceEpoch}:${a.currentParticipantCount}',
        )
        .join('|');
  }

  String _generateActivityPoints() {
    final features = _nearbyActivities
        .where((a) => a.latitude != 0.0 && a.longitude != 0.0)
        .map((a) {
          final weight =
              (a.currentParticipantCount.clamp(0, 30) / 30).clamp(0.2, 1.0);
          return '{"type":"Feature","geometry":{"type":"Point","coordinates":[${a.longitude},${a.latitude}]},"properties":{"weight":$weight}}';
        })
        .join(',');
    return '{"type":"FeatureCollection","features":[$features]}';
  }

  Future<void> _addActivityMarkers() async {
    if (_mapboxMap == null || !_mapStyleReady) return;
    try {
      await _safeRemoveLayer('activity-pin-glow');
      await _safeRemoveLayer('activity-pin-core');
      await _safeRemoveSource('activities-source');

      if (_nearbyActivities.isEmpty) return;

      await _mapboxMap!.style.addSource(
        GeoJsonSource(
          id: 'activities-source',
          data: _generateActivityPoints(),
        ),
      );

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'activity-pin-glow',
          sourceId: 'activities-source',
          circleRadiusExpression: const <Object>[
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            12,
            14,
            22,
          ],
          circleColor: _modeColorInt(0.20),
          circleBlur: 1.0,
          circleOpacity: 0.9,
        ),
      );

      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'activity-pin-core',
          sourceId: 'activities-source',
          circleRadiusExpression: const <Object>[
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            6,
            14,
            10,
          ],
          circleColor: _modeColorInt(0.95),
          circleStrokeWidth: 2.5,
          circleStrokeColor: _colorToRgba(Colors.white, 0.85),
          circleOpacity: 0.98,
        ),
      );
    } catch (e, st) {
      debugPrint('Activity marker ekleme hatasi: $e\n$st');
    }
  }

  Future<void> _fetchNearbyActivities({bool force = false}) async {
    final pos = _currentPosition;
    if (pos == null || _loadingActivities) return;
    final now = DateTime.now();
    if (!force &&
        _nearbyActivities.isNotEmpty &&
        now.difference(_lastActivitiesFetch).inSeconds < 30) {
      return;
    }
    _lastActivitiesFetch = now;
    if (mounted) setState(() => _loadingActivities = true);
    try {
      final result = await ActivityService.instance.search(
        ActivityListQueryParams(
          centerLatitude: pos.latitude,
          centerLongitude: pos.longitude,
          radiusKm: 8.0,
          mode: _currentMode.id,
          limit: 40,
        ),
      );
      if (!mounted) return;
      setState(() {
        _nearbyActivities = result.items
            .where((a) =>
                a.status == ActivityStatus.published &&
                !a.isPast)
            .toList();
        _loadingActivities = false;
      });
      if (_currentLens == HomeLens.activities) {
        await _syncMapDecorations(force: true);
      }
    } catch (e, st) {
      debugPrint('Activity fetch failed: $e\n$st');
      if (mounted) setState(() => _loadingActivities = false);
    }
  }

  void _onLensChanged(HomeLens lens) {
    if (_currentLens == lens) return;
    setState(() {
      _currentLens = lens;
      _showBottomCard = false;
    });
    _lastRenderedPlacesSignature = '';
    if (lens == HomeLens.activities) {
      unawaited(_fetchNearbyActivities(force: true));
    } else {
      unawaited(_syncMapDecorations(force: true));
    }
  }

  void _focusActivity(ActivityModel activity) {
    if (activity.latitude == 0.0 && activity.longitude == 0.0) return;
    _flyToCoordinates(activity.longitude, activity.latitude, zoom: 14.5);
  }

  void _openActivityDetail(ActivityModel activity) {
    Navigator.push(
      context,
      SlideUpRoute(
        page: ActivityDetailScreen(
          activityId: activity.id,
          initialActivity: activity,
        ),
      ),
    );
  }

  Future<void> _safeRemoveLayer(String id) async {
    try {
      await _mapboxMap?.style.removeStyleLayer(id);
    } catch (error, stackTrace) {
      debugPrint('Map layer removal failed for $id: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _safeRemoveSource(String id) async {
    try {
      await _mapboxMap?.style.removeStyleSource(id);
    } catch (error, stackTrace) {
      debugPrint('Map source removal failed for $id: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _launchExternal(
    Uri uri, {
    String errorText = 'Baglanti acilamadi.',
  }) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText)));
    }
  }

  Future<void> _openPlaceRoute(Map<String, dynamic> place) async {
    final l10n = context.l10n;
    final lat = (place['lat'] as num?)?.toDouble();
    final lng = (place['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await _launchExternal(uri, errorText: l10n.phrase('Yol tarifi açılamadı.'));
  }

  Future<void> _openWebsite(String website) async {
    final l10n = context.l10n;
    if (website.trim().isEmpty) return;
    final raw = website.startsWith('http') ? website : 'https://$website';
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await _launchExternal(uri, errorText: l10n.phrase('Website açılamadı.'));
  }

  Future<void> _callPlace(String phone) async {
    final l10n = context.l10n;
    if (phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    await _launchExternal(uri, errorText: l10n.phrase('Arama başlatılamadı.'));
  }

  Future<void> _toggleSavePlace(Map<String, dynamic> place) async {
    final l10n = context.l10n;
    if (_myUid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.phrase('Kaydetmek için giriş gerekli.'))),
      );
      return;
    }

    final saved = await _firestoreService.toggleSavePlace(_myUid, place);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? l10n.phrase('Mekan kaydedildi.')
              : l10n.phrase('Kayıt kaldırıldı.'),
        ),
      ),
    );
  }

  void _showPlaceDetailSheet(Map<String, dynamic> place) async {
    if (!mounted) return;
    final l10n = context.l10n;

    setState(() => _selectedPlace = place);

    final details = await _placesService.getPlaceDetails(place['place_id']);

    if (!mounted) return;

    final weekdayText =
        (details?['weekday_text'] as List?)?.cast<String>() ?? <String>[];
    final reviews = (details?['reviews'] as List?) ?? [];
    final phone = details?['phone']?.toString() ?? '';
    final website = details?['website']?.toString() ?? '';
    final resolvedPlace = <String, dynamic>{...place, ...?details};
    final pulseBreakdown = _placesService.buildPulseBreakdown(resolvedPlace);
    final pulseTags = _placesService.buildPulseDriverTags(resolvedPlace);
    final pulseExplanation = _placesService.explainPulseDrivers(
      resolvedPlace,
      modeLabel: l10n.modeLabel(_currentMode.id),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final modeColor = _currentMode.color;
        final rating = (place['rating'] as num?)?.toDouble() ?? 0.0;
        final totalRatings =
            (place['user_ratings_total'] as num?)?.toInt() ?? 0;
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
                        color: Colors.white.withValues(alpha: 0.15),
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
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(
                              Icons.image_rounded,
                              size: 40,
                              color: Colors.white.withValues(alpha: 0.1),
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
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOpen ? l10n.phrase('Açık') : l10n.phrase('Kapalı'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOpen ? AppColors.success : AppColors.error,
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
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            place['vicinity'].toString(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.4),
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
                          color: Colors.white.withValues(alpha: 0.15),
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
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag(
                        l10n.formatPhrase('Pulse {score}', {
                          'score':
                              (resolvedPlace['pulse_score'] as num?)?.toInt() ??
                              0,
                        }),
                        modeColor,
                      ),
                      _buildTag(
                        l10n.densityLabel(
                          resolvedPlace['density_label']?.toString() ?? 'Orta',
                        ),
                        AppColors.warning,
                      ),
                      _buildTag(
                        l10n.trendLabel(
                          resolvedPlace['trend_label']?.toString() ?? 'Sabit',
                        ),
                        AppColors.success,
                      ),
                    ],
                  ),
                  if (pulseTags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pulseTags
                          .map((tag) => _buildTag(tag, modeColor))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgMain.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.phrase('Neden Yükseliyor').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.25),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pulseExplanation,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.62),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildScoreRow(
                          l10n.phrase('Yoğunluk'),
                          pulseBreakdown['density'] ?? 0,
                          AppColors.densityMedium,
                        ),
                        const SizedBox(height: 8),
                        _buildScoreRow(
                          l10n.phrase('Enerji'),
                          pulseBreakdown['energy'] ?? 0,
                          AppColors.pulseHigh,
                        ),
                        const SizedBox(height: 8),
                        _buildScoreRow(
                          l10n.phrase('Tazelik'),
                          pulseBreakdown['freshness'] ?? 0,
                          AppColors.success,
                        ),
                        const SizedBox(height: 8),
                        _buildScoreRow(
                          l10n.phrase('Güven'),
                          pulseBreakdown['reliability'] ?? 0,
                          AppColors.modeSosyal,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: modeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: modeColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(_currentMode.icon, size: 18, color: modeColor),
                        const SizedBox(width: 10),
                        Text(
                          l10n.formatPhrase('{mode} modu için önerildi', {
                            'mode': l10n.modeLabel(_currentMode.id),
                          }),
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
                        l10n.phrase('Çalışma Saatleri').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.25),
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
                              color: Colors.white.withValues(alpha: 0.45),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (reviews.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.t('comments').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.25),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...reviews.take(3).map((review) {
                        final reviewMap = Map<String, dynamic>.from(
                          review as Map,
                        );
                        final reviewRating =
                            (reviewMap['rating'] as num?)?.toInt() ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgMain.withValues(alpha: 0.5),
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
                                  color: Colors.white.withValues(alpha: 0.4),
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
                                  color: Colors.white.withValues(alpha: 0.2),
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
                                l10n.phrase('Ara'),
                                AppColors.success,
                                () {
                                  unawaited(_callPlace(phone));
                                },
                              ),
                            ),
                          if (phone.isNotEmpty && website.isNotEmpty)
                            const SizedBox(width: 10),
                          if (website.isNotEmpty)
                            Expanded(
                              child: _actionButton(
                                Icons.language_rounded,
                                l10n.phrase('Website'),
                                AppColors.modeSosyal,
                                () {
                                  unawaited(_openWebsite(website));
                                },
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
                          l10n.phrase('Yol Tarifi'),
                          modeColor,
                          () {
                            unawaited(_openPlaceRoute(resolvedPlace));
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          Icons.bookmark_border_rounded,
                          l10n.phrase('Kaydet'),
                          Colors.white.withValues(alpha: 0.5),
                          () {
                            unawaited(_toggleSavePlace(resolvedPlace));
                          },
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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

  void _applyModeSelection(
    int index, {
    required bool persist,
    bool focusTopPlace = true,
    bool showInfo = true,
  }) {
    if (index == _selectedMode) {
      if (focusTopPlace) {
        _lastRenderedPlacesSignature = '';
        _updateHeatmapForMode();
        _maybeFetchPlaces(force: true);
      }
      return;
    }

    setState(() {
      _selectedMode = index;
      _showBottomCard = false;
      _showModeInfo = showInfo;
      _popularPlaces = [];
      _popularPlacesCacheKey = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerSelectedModeChip();
    });

    _lastRenderedPlacesSignature = '';
    _modeTransitionController.forward(from: 0);
    if (_mapboxMap != null) {
      unawaited(_applyUserLocationPuck(_mapboxMap!));
    }
    _updateHeatmapForMode();
    _maybeFetchPlaces(force: true);
    if (_currentLens == HomeLens.activities) {
      unawaited(_fetchNearbyActivities(force: true));
    }

    if (showInfo) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showModeInfo = false);
        }
      });
    }

    if (persist && _myUid.isNotEmpty) {
      final selectedModeId = ModeConfig.all[index].id;
      if (AuthService().currentUser?.mode != selectedModeId) {
        unawaited(
          _firestoreService.updateMode(_myUid, selectedModeId).catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            debugPrint('Mode sync failed: $error\n$stackTrace');
          }),
        );
      }
    }

    if (!focusTopPlace) return;

    final headlinePlaces = _visibleHeadlinePlaces;
    if (headlinePlaces.isNotEmpty && _mapboxMap != null && _mapStyleReady) {
      final first = headlinePlaces.first;
      final lng = (first['lng'] as num).toDouble();
      final lat = (first['lat'] as num).toDouble();
      _flyToCoordinates(lng, lat, zoom: 14);
    }
  }

  void _onModeChanged(int index) {
    _applyModeSelection(index, persist: false);
  }

  void _onPlaceLensChanged(int index) {
    if (index == _selectedPlaceLens) return;
    setState(() => _selectedPlaceLens = index);
    _syncHeadlineSelection();
    if (index == 2) {
      unawaited(_ensurePopularScopePlaces());
    }

    final first = _visibleHeadlinePlaces.isNotEmpty
        ? _visibleHeadlinePlaces.first
        : null;
    if (first != null && _mapboxMap != null && _mapStyleReady) {
      final lng = (first['lng'] as num?)?.toDouble();
      final lat = (first['lat'] as num?)?.toDouble();
      if (lng != null && lat != null) {
        _flyToCoordinates(lng, lat, zoom: 14.5);
      }
    }
  }

  void _syncHeadlineSelection() {
    final topPlace = _visibleHeadlinePlaces.isNotEmpty
        ? _visibleHeadlinePlaces.first
        : null;
    if (topPlace == null || !mounted) return;

    setState(() {
      _pulseScore = (topPlace['pulse_score'] as num?)?.toInt() ?? 0;
      _densityLabel = topPlace['density_label']?.toString() ?? 'Orta';
      _trendLabel = topPlace['trend_label']?.toString() ?? 'Sabit';
      _selectedAreaName = topPlace['name']?.toString() ?? '';
    });
  }

  double _nearbyPriorityScore(Map<String, dynamic> place) {
    final pulse = (place['pulse_score'] as num?)?.toDouble() ?? 0;
    final trend = (place['trend_score'] as num?)?.toDouble() ?? 0;
    final community = (place['community_score'] as num?)?.toDouble() ?? 0;
    final distanceMeters =
        (place['distance_meters'] as num?)?.toDouble() ?? 9999;
    final proximity = (100 - (distanceMeters / 15)).clamp(0, 100).toDouble();
    final openBoost = place['open_now'] == true ? 14.0 : 0.0;
    return (proximity * 0.46) +
        (pulse * 0.30) +
        (trend * 0.12) +
        (community * 0.12) +
        openBoost;
  }

  double _popularPriorityScore(Map<String, dynamic> place) {
    final pulse = (place['pulse_score'] as num?)?.toDouble() ?? 0;
    final rating = (place['rating'] as num?)?.toDouble() ?? 0;
    final trend = (place['trend_score'] as num?)?.toDouble() ?? 0;
    final community = (place['community_score'] as num?)?.toDouble() ?? 0;
    final totalRatings =
        (place['user_ratings_total'] as num?)?.toDouble() ?? 0.0;
    final reviewVolume = (totalRatings / 20).clamp(0, 100).toDouble();
    final distanceMeters =
        (place['distance_meters'] as num?)?.toDouble() ?? 99999;
    final metroDistanceBias = (100 - (distanceMeters / 1200))
        .clamp(0, 100)
        .toDouble();
    final openBoost = place['open_now'] == true ? 12.0 : 0.0;
    return (pulse * 0.40) +
        (rating * 10.0) +
        (reviewVolume * 0.24) +
        (community * 0.16) +
        (trend * 0.08) +
        (metroDistanceBias * 0.08) +
        openBoost;
  }

  String _popularPlacesCacheKeyFor(double lat, double lng, String modeId) =>
      '$modeId:${lat.toStringAsFixed(2)}:${lng.toStringAsFixed(2)}';

  Future<void> _ensurePopularScopePlaces({bool force = false}) async {
    final pos = _currentPosition;
    if (pos == null) return;

    final requestKey = _popularPlacesCacheKeyFor(
      pos.latitude,
      pos.longitude,
      _currentMode.id,
    );
    if (!force &&
        _popularPlacesCacheKey == requestKey &&
        _popularPlaces.isNotEmpty) {
      return;
    }
    if (_loadingPopularPlaces) return;

    if (mounted) {
      setState(() => _loadingPopularPlaces = true);
    } else {
      _loadingPopularPlaces = true;
    }

    try {
      final rawPlaces = await _placesService.getNearbyPlaces(
        lat: pos.latitude,
        lng: pos.longitude,
        modeId: _currentMode.id,
        radius: 45000,
        sortBy: 'popular',
      );
      final communitySignals = await _firestoreService
          .getCommunitySignalsForPlaces(rawPlaces);
      final mergedPlaces = _placesService.mergePulseSignals(
        rawPlaces,
        communitySignals: communitySignals,
      );
      final metroPlaces = _selectDominantPopularArea(mergedPlaces);
      final latestKey = _currentPosition == null
          ? ''
          : _popularPlacesCacheKeyFor(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              _currentMode.id,
            );
      if (!mounted || latestKey != requestKey) {
        _loadingPopularPlaces = false;
        return;
      }

      setState(() {
        _popularPlaces = metroPlaces;
        _popularPlacesCacheKey = requestKey;
        _loadingPopularPlaces = false;
      });
      if (_selectedPlaceLens == 2) {
        _syncHeadlineSelection();
        final first = _visibleHeadlinePlaces.isNotEmpty
            ? _visibleHeadlinePlaces.first
            : null;
        if (first != null && _mapboxMap != null && _mapStyleReady) {
          final lng = (first['lng'] as num?)?.toDouble();
          final lat = (first['lat'] as num?)?.toDouble();
          if (lng != null && lat != null) {
            _flyToCoordinates(lng, lat, zoom: 13.9);
          }
        }
      }
    } catch (e, st) {
      debugPrint('Popular metro places error: $e\n$st');
      if (mounted) {
        setState(() => _loadingPopularPlaces = false);
      } else {
        _loadingPopularPlaces = false;
      }
    }
  }

  List<Map<String, dynamic>> _selectDominantPopularArea(
    List<Map<String, dynamic>> places,
  ) {
    if (places.length <= 3) {
      return places;
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final place in places) {
      final area = _extractPopularArea(place);
      groups.putIfAbsent(area, () => <Map<String, dynamic>>[]).add(place);
    }

    if (groups.length <= 1) {
      return places;
    }

    String? bestArea;
    double bestScore = double.negativeInfinity;
    for (final entry in groups.entries) {
      final ranked = List<Map<String, dynamic>>.from(entry.value)
        ..sort(
          (a, b) =>
              _popularPriorityScore(b).compareTo(_popularPriorityScore(a)),
        );
      final topFiveScore = ranked
          .take(5)
          .fold<double>(0, (sum, place) => sum + _popularPriorityScore(place));
      final groupScore = topFiveScore + (ranked.length * 22.0);
      if (groupScore > bestScore) {
        bestScore = groupScore;
        bestArea = entry.key;
      }
    }

    if (bestArea == null) {
      return places;
    }

    final bestGroup = List<Map<String, dynamic>>.from(groups[bestArea]!)
      ..sort(
        (a, b) => _popularPriorityScore(b).compareTo(_popularPriorityScore(a)),
      );
    return bestGroup;
  }

  String _extractPopularArea(Map<String, dynamic> place) {
    final vicinity = (place['vicinity']?.toString() ?? '').trim();
    if (vicinity.isEmpty) {
      return 'unknown';
    }

    final segments = vicinity
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return 'unknown';
    }

    return segments.length == 1 ? segments.first : segments.last;
  }

  void _centerSelectedModeChip({bool animate = true}) {
    if (!mounted || _selectedMode >= _modeChipKeys.length) return;
    final chipContext = _modeChipKeys[_selectedMode].currentContext;
    if (chipContext == null) return;

    Scrollable.ensureVisible(
      chipContext,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 280) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 6;

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
              // ignore: experimental_member_use
              androidHostingMode: AndroidPlatformViewHostingMode.HC,
              styleUri: MapboxStyles.STANDARD,
              onMapCreated: (map) {
                _mapboxMap = map;
                unawaited(_configureMapUi(map));
                _tryApplyInitialCamera();
              },
              onStyleLoadedListener: (_) async {
                _mapStyleReady = true;
                _lastRenderedPlacesSignature = '';
                _tryApplyInitialCamera();
                await _applyUserLocationPuck(_mapboxMap!);
                await _syncMapDecorations(force: true);
              },
            )
          else
            Container(color: AppColors.bgMap),
          AnimatedBuilder(
            animation: _modeTransitionAnim,
            builder: (context, child) {
              return IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  color: _currentMode.color.withValues(alpha: 0.06),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 132,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bgMain.withValues(alpha: 0.92),
                    AppColors.bgMain.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 210,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.bgMain.withValues(alpha: 0.98),
                    _currentMode.color.withValues(alpha: 0.1),
                    AppColors.bgMain.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          _buildTopBar(MediaQuery.of(context).padding.top + 8),
          _buildHeroCard(MediaQuery.of(context).padding.top + 8),
          _buildActionRail(MediaQuery.of(context).padding.top + 8),
          if (_bottomDeckCollapsed)
            Positioned(
              bottom: bottomPadding + 80,
              left: 12,
              right: 12,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: _buildLensToggle(),
                ),
              ),
            ),
          _buildBottomDeck(bottomPadding),
          if (_showBottomCard) _buildDetailCard(),
        ],
      ),
    );
  }

  Future<void> _syncLocationIfNeeded(String uid, geo.Position position) async {
    if (!_shouldSyncLocation(position)) {
      return;
    }

    _lastLocationSyncAt = DateTime.now();
    _lastSyncedPosition = position;

    try {
      await _firestoreService.updateLocation(
        uid,
        position.latitude,
        position.longitude,
      );
    } catch (error, stackTrace) {
      debugPrint('Location sync failed: $error\n$stackTrace');
    }
  }

  bool _shouldSyncLocation(geo.Position position) {
    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastLocationSyncAt).inSeconds;
    if (_lastSyncedPosition == null) {
      return true;
    }

    final movedMeters = _locationService.getDistance(
      _lastSyncedPosition!.latitude,
      _lastSyncedPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    return elapsedSeconds >= 12 || movedMeters >= 35;
  }

  Widget _buildSuggestionCard(Map<String, dynamic> s, int index) {
    final color = _resolvePlaceAccent(s);
    final modeColor = _currentMode.color;
    final l10n = context.l10n;
    final compactCard = MediaQuery.of(context).size.height < 760;
    final pulse = (s['pulse_score'] as num?)?.toInt() ?? 0;
    final isOpen = s['open_now'] == true;
    final title = s['name']?.toString() ?? s['title']?.toString() ?? '';
    final subtitle =
        s['vicinity']?.toString() ?? s['subtitle']?.toString() ?? '';
    final density =
        s['density_label']?.toString() ?? s['density']?.toString() ?? '';
    final distance = s['distance_label']?.toString() ?? '';
    final trend = s['trend_label']?.toString() ?? '';

    return AnimatedPress(
      onTap: () {
        setState(() {
          _showBottomCard = true;
          _selectedAreaName = title;
          _pulseScore = pulse;
          _densityLabel = density;
          _trendLabel = trend;
        });

        final lat = (s['lat'] as num?)?.toDouble();
        final lng = (s['lng'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          _flyToCoordinates(lng, lat, zoom: 15);
        }

        _showPlaceDetailSheet(s);
      },
      scaleDown: 0.96,
      child: Container(
        width: compactCard ? 198 : 214,
        margin: const EdgeInsets.only(right: 12),
        padding: EdgeInsets.all(compactCard ? 10 : 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              modeColor.withValues(alpha: 0.14),
              AppColors.bgCard.withValues(alpha: 0.96),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: modeColor.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: compactCard ? 28 : 30,
                  height: compactCard ? 28 : 30,
                  decoration: BoxDecoration(
                    color: modeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _resolvePlaceIcon(s),
                    size: compactCard ? 14 : 15,
                    color: modeColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: compactCard ? 12 : 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compactCard ? 8 : 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_rounded, size: 10, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '$pulse',
                        style: TextStyle(
                          fontSize: compactCard ? 10 : 11,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compactCard ? 8 : 10),
            Text(
              subtitle.isNotEmpty
                  ? subtitle
                  : density.isNotEmpty
                  ? l10n.densityLabel(density)
                  : l10n.phrase('Canlı veri'),
              style: TextStyle(
                fontSize: compactCard ? 10 : 11,
                color: Colors.white.withValues(alpha: 0.48),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: compactCard ? 6 : 8),
            Text(
              distance.isNotEmpty
                  ? '$distance • ${l10n.trendLabel(trend)}'
                  : l10n.trendLabel(trend),
              style: TextStyle(
                fontSize: compactCard ? 10 : 11,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: compactCard ? 6 : 8),
            Row(
              children: [
                Flexible(
                  child: _buildTag(l10n.densityLabel(density), modeColor),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compactCard ? 8 : 10,
                    vertical: compactCard ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: (isOpen ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOpen ? Icons.circle_rounded : Icons.cancel_rounded,
                        size: 10,
                        color: isOpen ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOpen ? l10n.phrase('Açık') : l10n.phrase('Kapalı'),
                        style: TextStyle(
                          fontSize: compactCard ? 9.5 : 10,
                          fontWeight: FontWeight.w700,
                          color: isOpen ? AppColors.success : AppColors.error,
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

  Color _resolvePlaceAccent(Map<String, dynamic> place) {
    final pulse = (place['pulse_score'] as num?)?.toInt() ?? 0;
    if (pulse >= 85) return AppColors.pulseVeryHigh;
    if (pulse >= 70) return AppColors.pulseHigh;
    if (pulse >= 55) return AppColors.pulseMedium;
    return AppColors.pulseLow;
  }

  IconData _resolvePlaceIcon(Map<String, dynamic> place) {
    final types = List<String>.from(place['types'] ?? const []);
    if (types.contains('night_club')) return Icons.nightlife_rounded;
    if (types.contains('bar')) return Icons.local_bar_rounded;
    if (types.contains('cafe')) return Icons.coffee_rounded;
    if (types.contains('restaurant')) return Icons.restaurant_rounded;
    if (types.contains('park')) return Icons.park_rounded;
    if (types.contains('museum') || types.contains('art_gallery')) {
      return Icons.palette_rounded;
    }
    if (types.contains('library')) return Icons.local_library_rounded;
    return _currentMode.icon;
  }

  Widget _buildMapButton(
    IconData icon,
    VoidCallback onTap, {
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        child: AnimatedPress(
          onTap: onTap,
          scaleDown: 0.9,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.bgCard.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  /// Action rail'in en üstünde duran "Etkinlik oluştur" FAB'ı.
  /// CreateActivity uygulamanın ana yaratım eylemlerinden — Harita
  /// üzerinde her zaman görünür, mevcut moda (Sosyal / Gece / Spor …)
  /// uygun renkte parlar.
  Widget _buildCreateActivityRailButton() {
    final modeColor = _currentMode.color;
    final label = context.tr3(
      tr: 'Etkinlik oluştur',
      en: 'Create activity',
      de: 'Aktivität erstellen',
    );
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: AnimatedPress(
          onTap: () => Navigator.push(
            context,
            SlideUpRoute(page: const CreateActivityScreen()),
          ),
          scaleDown: 0.9,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [modeColor, modeColor.withValues(alpha: 0.72)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: modeColor.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  /// Action rail'inde duran "Gönderi oluştur" butonu (metin/feed post).
  /// Profil rail'lerinde foto/story/shorts için inline + var; feed post
  /// için global giriş noktası bu rail butonu.
  Widget _buildComposeRailButton() {
    final label = context.tr3(
      tr: 'Gönderi oluştur',
      en: 'Create post',
      de: 'Beitrag erstellen',
    );
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: AnimatedPress(
          onTap: _openComposer,
          scaleDown: 0.9,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryGlow],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openComposer() async {
    final uid = _myUid;
    if (uid.isEmpty) {
      if (!mounted) return;
      AppSnackbar.showInfo(context, context.l10n.phrase('Önce giriş yap.'));
      return;
    }
    final user = await _firestoreService.getUser(uid);
    if (!mounted) return;
    if (user == null) {
      AppSnackbar.showError(
        context,
        context.l10n.phrase('Profil yüklenemedi.'),
      );
      return;
    }
    final didCreate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          kind: CreatePostKind.post,
          currentUser: user,
        ),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || didCreate != true) return;
    AppSnackbar.showSuccess(
      context,
      context.l10n.phrase('Gönderi feede eklendi.'),
    );
  }

  Widget _buildLensToggle() {
    final modeColor = _currentMode.color;
    Widget seg(HomeLens lens, IconData icon, String label) {
      final selected = _currentLens == lens;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onLensChanged(lens),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? modeColor.withValues(alpha: 0.20)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? modeColor.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected
                      ? modeColor
                      : Colors.white.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? modeColor
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          seg(
            HomeLens.people,
            Icons.person_pin_circle_rounded,
            context.tr3(tr: 'İnsanlar', en: 'People', de: 'Leute'),
          ),
          const SizedBox(width: 4),
          seg(
            HomeLens.activities,
            Icons.event_rounded,
            context.tr3(tr: 'Etkinlik', en: 'Events', de: 'Events'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceLensChip(String label, int index) {
    final selected = _selectedPlaceLens == index;
    final color = _currentMode.color;

    return GestureDetector(
      onTap: () => _onPlaceLensChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.48)
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index == 2 && _loadingPopularPlaces) ...[
              SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: selected ? color : Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? color : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRailCard(ActivityModel a) {
    final modeColor = _currentMode.color;
    final pos = _currentPosition;
    String distanceLabel = '';
    if (pos != null && a.latitude != 0.0 && a.longitude != 0.0) {
      final meters = geo.Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        a.latitude,
        a.longitude,
      );
      distanceLabel = meters < 1000
          ? '${meters.round()} m'
          : '${(meters / 1000).toStringAsFixed(1)} km';
    }

    final timeLabel = _formatActivityWhen(a.startsAt);

    return GestureDetector(
      onTap: () {
        _focusActivity(a);
        _openActivityDetail(a);
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: modeColor.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: modeColor.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: modeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: modeColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (distanceLabel.isNotEmpty)
                  Text(
                    distanceLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              a.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    a.locationName.isNotEmpty
                        ? a.locationName
                        : (a.city.isNotEmpty ? a.city : '—'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.group_rounded,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 3),
                Text(
                  a.maxParticipants != null
                      ? '${a.currentParticipantCount}/${a.maxParticipants}'
                      : '${a.currentParticipantCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: modeColor.withValues(alpha: 0.85),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatActivityWhen(DateTime startsAt) {
    final now = DateTime.now();
    final diff = startsAt.difference(now);
    if (diff.isNegative) {
      return context.tr3(tr: 'Şimdi', en: 'Now', de: 'Jetzt');
    }
    if (diff.inMinutes < 60) {
      return context.tr3(
        tr: '${diff.inMinutes} dk sonra',
        en: 'in ${diff.inMinutes} min',
        de: 'in ${diff.inMinutes} Min',
      );
    }
    final sameDay = startsAt.year == now.year &&
        startsAt.month == now.month &&
        startsAt.day == now.day;
    final hh = startsAt.hour.toString().padLeft(2, '0');
    final mm = startsAt.minute.toString().padLeft(2, '0');
    if (sameDay) {
      return context.tr3(tr: 'Bugün $hh:$mm', en: 'Today $hh:$mm', de: 'Heute $hh:$mm');
    }
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = startsAt.year == tomorrow.year &&
        startsAt.month == tomorrow.month &&
        startsAt.day == tomorrow.day;
    if (isTomorrow) {
      return context.tr3(
        tr: 'Yarın $hh:$mm',
        en: 'Tomorrow $hh:$mm',
        de: 'Morgen $hh:$mm',
      );
    }
    return '${startsAt.day}/${startsAt.month} $hh:$mm';
  }

  Widget _buildActivitiesEmptyState() {
    final modeColor = _currentMode.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_available_rounded,
            color: modeColor.withValues(alpha: 0.7),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr3(
                    tr: 'Yakında etkinlik yok',
                    en: 'No nearby activities',
                    de: 'Keine Aktivitäten in der Nähe',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr3(
                    tr: 'İlk hareketi sen başlat — bir etkinlik aç.',
                    en: 'Be the first — host an activity.',
                    de: 'Mach den Anfang — erstelle eine Aktivität.',
                  ),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              SlideUpRoute(page: const CreateActivityScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: modeColor.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: modeColor),
                  const SizedBox(width: 4),
                  Text(
                    context.tr3(tr: 'Aç', en: 'Host', de: 'Erstellen'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: modeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectorChip(ModeConfig mode, int index) {
    final isActive = index == _selectedMode;

    return GestureDetector(
      key: _modeChipKeys[index],
      onTap: () => _onModeChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? mode.color : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive
                ? mode.color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: mode.color.withValues(alpha: 0.24),
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
                  : Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.modeLabel(mode.id),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelToggleButton({
    required bool collapsed,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Icon(
          collapsed
              ? Icons.keyboard_arrow_down_rounded
              : Icons.keyboard_arrow_up_rounded,
          color: Colors.white.withValues(alpha: 0.72),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTopBar(double topInset) {
    final modeColor = _currentMode.color;
    return Positioned(
      top: topInset,
      left: 16,
      right: 16,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
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
              Text(
                context.tr3(
                  tr: 'Canlı şehir akışı',
                  en: 'Live city flow',
                  de: 'Live-Stadtfluss',
                ),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showPulseDetail,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: modeColor.withValues(alpha: 0.24)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, size: 16, color: modeColor),
                  const SizedBox(width: 6),
                  Text(
                    '$_pulseScore',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: modeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(double topInset) {
    final l10n = context.l10n;
    final modeColor = _currentMode.color;
    final suggestionCount = _visibleHeadlinePlaces.length;
    final openCount = _activeNearbyPlaces.length;

    return Positioned(
      top: topInset + 56,
      left: 16,
      right: 86,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: EdgeInsets.fromLTRB(16, 14, 16, _heroCollapsed ? 14 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              modeColor.withValues(alpha: _showModeInfo ? 0.28 : 0.22),
              AppColors.bgSurface,
              AppColors.bgCard,
            ],
          ),
          border: Border.all(color: modeColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: modeColor.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_currentMode.icon, size: 14, color: modeColor),
                      const SizedBox(width: 6),
                      Text(
                        l10n.modeLabel(_currentMode.id),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: modeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr3(tr: 'Şu an', en: 'Right now', de: 'Jetzt'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.52),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildPanelToggleButton(
                  collapsed: _heroCollapsed,
                  onTap: () => setState(() => _heroCollapsed = !_heroCollapsed),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.tr3(
                tr: 'Bugün sana en iyi uyan yerler',
                en: 'Best matching places for you now',
                de: 'Die besten Orte für dich im Moment',
              ),
              maxLines: _heroCollapsed ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _heroCollapsed ? 19 : 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.05,
              ),
            ),
            if (!_heroCollapsed) ...[
              const SizedBox(height: 8),
              Text(
                context.tr3(
                  tr: 'Moduna, yakınlığına, açıklık durumuna ve anlık pulse yoğunluğuna göre sıralanıyor.',
                  en: 'Ranked by your mode, distance, open status, and live pulse intensity.',
                  de: 'Sortiert nach Modus, Entfernung, Öffnungsstatus und Live-Pulse.',
                ),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag(
                    context.tr3(
                      tr: '$suggestionCount öneri',
                      en: '$suggestionCount picks',
                      de: '$suggestionCount Vorschläge',
                    ),
                    modeColor,
                  ),
                  _buildTag(
                    context.tr3(
                      tr: '$openCount açık nokta',
                      en: '$openCount open now',
                      de: '$openCount offen',
                    ),
                    AppColors.success,
                  ),
                  _buildTag(
                    context.tr3(
                      tr: 'Anlık sıralama',
                      en: 'Live ranking',
                      de: 'Live-Ranking',
                    ),
                    Colors.white.withValues(alpha: 0.78),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionRail(double topInset) {
    return Positioned(
      right: 16,
      top: topInset + (_heroCollapsed ? 70 : 96),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.bgCard.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            _buildCreateActivityRailButton(),
            const SizedBox(height: 8),
            _buildComposeRailButton(),
            const SizedBox(height: 8),
            _buildMapButton(
              Icons.my_location_rounded,
              () {
                final pos = _currentPosition;
                if (pos != null) {
                  _flyToCoordinates(pos.longitude, pos.latitude, zoom: 15);
                }
              },
              tooltip: context.tr3(
                tr: 'Konumum',
                en: 'My location',
                de: 'Mein Standort',
              ),
            ),
            const SizedBox(height: 8),
            _buildMapButton(
              Icons.compass_calibration_rounded,
              () => Navigator.push(
                context,
                SlideUpRoute(page: const DiscoverPeopleScreen()),
              ),
              tooltip: context.tr3(
                tr: 'Yakındakiler',
                en: 'Nearby',
                de: 'In der Nähe',
              ),
            ),
            const SizedBox(height: 8),
            _buildMapButton(
              Icons.favorite_rounded,
              () => Navigator.push(
                context,
                SlideUpRoute(page: const MatchesScreen()),
              ),
              tooltip: context.tr3(
                tr: 'Eşleşmeler',
                en: 'Matches',
                de: 'Matches',
              ),
            ),
            const SizedBox(height: 8),
            const NotificationBellButton(),
            if (AppFeatures.shortsFeed) ...[
              const SizedBox(height: 8),
              _buildMapButton(
                Icons.smart_display_rounded,
                () => Navigator.push(
                  context,
                  SlideUpRoute(
                    page: const ShortsScreen(scope: ShortsFeedScope.global),
                  ),
                ),
                tooltip: context.tr3(
                  tr: 'Kısa videolar',
                  en: 'Shorts',
                  de: 'Kurzvideos',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDeck(double bottomPadding) {
    final l10n = context.l10n;
    final modeColor = _currentMode.color;
    final screenHeight = MediaQuery.of(context).size.height;
    final compactDeck = screenHeight < 760;
    final deckMaxHeight = compactDeck
        ? 254.0
        : screenHeight < 860
        ? 292.0
        : 332.0;
    final suggestionHeight = compactDeck ? 116.0 : 132.0;
    // Fade the rightmost ~22px so users get a visual cue that more chips
    // exist when the row overflows (notably in DE with longer labels).
    final modeSelector = SizedBox(
      height: 42,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.85, 1.0],
            colors: [Colors.white, Colors.white, Colors.transparent],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _modeSelectorController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: ModeConfig.all.length,
          itemBuilder: (_, i) {
            final mode = ModeConfig.all[i];
            return _buildModeSelectorChip(mode, i);
          },
        ),
      ),
    );

    return Positioned(
      bottom: bottomPadding,
      left: 12,
      right: 12,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        constraints: BoxConstraints(
          maxHeight: _bottomDeckCollapsed ? 74 : deckMaxHeight,
        ),
        padding: EdgeInsets.fromLTRB(
          14,
          12,
          14,
          _bottomDeckCollapsed ? 10 : 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgMain.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: _bottomDeckCollapsed
            ? Row(
                children: [
                  Expanded(child: modeSelector),
                  const SizedBox(width: 8),
                  _buildPanelToggleButton(
                    collapsed: true,
                    onTap: () => setState(() => _bottomDeckCollapsed = false),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Expanded(child: _buildLensToggle()),
                        const SizedBox(width: 8),
                        if ((_loadingPlaces &&
                                _currentLens == HomeLens.people) ||
                            (_loadingActivities &&
                                _currentLens == HomeLens.activities))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.7,
                                color: modeColor.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        _buildPanelToggleButton(
                          collapsed: false,
                          onTap: () =>
                              setState(() => _bottomDeckCollapsed = true),
                        ),
                      ],
                    ),
                    SizedBox(height: compactDeck ? 8 : 10),
                    if (_currentLens == HomeLens.people) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          context.tr3(
                            tr: 'Seçtiğin moda göre en yüksek pulse taşıyan ve şu ana en uygun görünen yerler.',
                            en: 'Places with the highest pulse and strongest fit for your selected mode right now.',
                            de: 'Orte mit dem stärksten Pulse und der besten Passung zu deinem aktuellen Modus.',
                          ),
                          style: TextStyle(
                            fontSize: compactDeck ? 11.5 : 12,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      SizedBox(height: compactDeck ? 10 : 12),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          children: [
                            _buildPlaceLensChip(l10n.phrase('Genel'), 0),
                            _buildPlaceLensChip(
                              context.tr3(
                                tr: 'En Yakın',
                                en: 'Nearest',
                                de: 'Nächste',
                              ),
                              1,
                            ),
                            _buildPlaceLensChip(
                              context.tr3(
                                tr: 'En Popüler',
                                en: 'Popular',
                                de: 'Beliebt',
                              ),
                              2,
                            ),
                            _buildPlaceLensChip(
                              context.tr3(tr: 'Açık', en: 'Open', de: 'Offen'),
                              3,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compactDeck ? 10 : 12),
                      SizedBox(
                        height: suggestionHeight,
                        child: Stack(
                          children: [
                            NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n is ScrollUpdateNotification && mounted) {
                                  setState(() {});
                                }
                                return false;
                              },
                              child:
                                  _loadingPlaces &&
                                      _visibleHeadlinePlaces.isEmpty
                                  ? ListView(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      children: List.generate(
                                        3,
                                        (_) => const ShimmerSuggestionCard(),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: _suggestionsController,
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      itemCount: _visibleHeadlinePlaces.length,
                                      itemBuilder: (_, i) =>
                                          _buildSuggestionCard(
                                        _visibleHeadlinePlaces[i],
                                        i,
                                      ),
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
                                          AppColors.bgMain.withValues(alpha: 0),
                                          AppColors.bgMain.withValues(
                                            alpha: 0.92,
                                          ),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          context.tr3(
                            tr: 'Yakındaki etkinlikler — bir gruba katıl ya da kendi etkinliğini aç.',
                            en: 'Nearby activities — join one or host your own.',
                            de: 'Aktivitäten in der Nähe — mitmachen oder selbst hosten.',
                          ),
                          style: TextStyle(
                            fontSize: compactDeck ? 11.5 : 12,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      SizedBox(height: compactDeck ? 10 : 12),
                      SizedBox(
                        height: compactDeck ? 150.0 : 168.0,
                        child: _loadingActivities && _nearbyActivities.isEmpty
                            ? ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                children: List.generate(
                                  3,
                                  (_) => const ShimmerSuggestionCard(),
                                ),
                              )
                            : _nearbyActivities.isEmpty
                            ? _buildActivitiesEmptyState()
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                itemCount: _nearbyActivities.length,
                                itemBuilder: (_, i) => _buildActivityRailCard(
                                  _nearbyActivities[i],
                                ),
                              ),
                      ),
                    ],
                    SizedBox(height: compactDeck ? 10 : 12),
                    modeSelector,
                  ],
                ),
              ),
      ),
    );
  }

  void _showPulseDetail() {
    final modeColor = _currentMode.color;
    final l10n = context.l10n;
    final activePlace =
        _selectedPlace ??
        (_visibleHeadlinePlaces.isNotEmpty
            ? _visibleHeadlinePlaces.first
            : null);
    final breakdown = activePlace == null
        ? const <String, double>{
            'density': 0.5,
            'energy': 0.5,
            'freshness': 0.5,
            'reliability': 0.5,
            'proximity': 0.5,
            'momentum': 0.5,
          }
        : _placesService.buildPulseBreakdown(activePlace);
    final explanation = activePlace == null
        ? l10n.phrase('Canlı veri geldikçe pulse detayları burada güçlenecek.')
        : _placesService.explainPulseDrivers(
            activePlace,
            modeLabel: l10n.modeLabel(_currentMode.id),
          );
    final tags = activePlace == null
        ? const <String>[]
        : _placesService.buildPulseDriverTags(activePlace);

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
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.phrase('Bölge Pulse Skoru'),
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
            const SizedBox(height: 4),
            Text(
              '${l10n.densityLabel(_densityLabel)} - ${l10n.trendLabel(_trendLabel)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_currentMode.icon, size: 14, color: modeColor),
                  const SizedBox(width: 6),
                  Text(
                    l10n.formatPhrase('{mode} Modu', {
                      'mode': l10n.modeLabel(_currentMode.id),
                    }),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: modeColor,
                    ),
                  ),
                ],
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) => _buildTag(tag, modeColor)).toList(),
              ),
            ],
            const SizedBox(height: 20),
            _buildScoreRow(
              l10n.phrase('Yoğunluk'),
              breakdown['density'] ?? 0,
              AppColors.densityMedium,
            ),
            const SizedBox(height: 10),
            _buildScoreRow(
              l10n.phrase('Enerji'),
              breakdown['energy'] ?? 0,
              AppColors.pulseHigh,
            ),
            const SizedBox(height: 10),
            _buildScoreRow(
              l10n.phrase('İvme'),
              breakdown['momentum'] ?? 0,
              AppColors.success,
            ),
            const SizedBox(height: 10),
            _buildScoreRow(
              l10n.phrase('Güven'),
              breakdown['reliability'] ?? 0,
              AppColors.modeSosyal,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: modeColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_rounded, size: 18, color: modeColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      explanation,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
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
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
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
    final l10n = context.l10n;

    return Positioned(
      bottom: _bottomDeckCollapsed ? 104 : 204,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () => setState(() => _showBottomCard = false),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: modeColor.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: modeColor.withValues(alpha: 0.1),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: modeColor.withValues(alpha: 0.15),
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
                  _buildTag(l10n.densityLabel(_densityLabel), modeColor),
                  const SizedBox(width: 8),
                  _buildTag(l10n.trendLabel(_trendLabel), AppColors.success),
                  const SizedBox(width: 8),
                  _buildTag(
                    l10n.formatPhrase('{mode} modu', {
                      'mode': l10n.modeLabel(_currentMode.id),
                    }),
                    modeColor,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.t('close'),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.25),
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
        color: color.withValues(alpha: 0.12),
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
