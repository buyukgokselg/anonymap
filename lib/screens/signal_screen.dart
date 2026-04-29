import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../services/realtime_service.dart';
import '../theme/colors.dart';
import '../models/activity_model.dart';
import 'chat_screen.dart';
import 'create_activity_screen.dart';
import 'profile_screen.dart';

class SignalScreen extends StatefulWidget {
  /// [embedded]: HomeShellScreen sekmesi olarak gösterildiğinde true
  /// olmalı — leading "geri" oku gizlenir (sekme bağlamında pop
  /// edilecek route yok).
  const SignalScreen({super.key, this.embedded = false});

  final bool embedded;
  static bool isSignalActive = false;

  @override
  State<SignalScreen> createState() => _SignalScreenState();
}

class _SignalScreenState extends State<SignalScreen>
    with TickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  final _placesService = PlacesService();
  final _realtimeService = RealtimeService.instance;

  late AnimationController _pulseController;
  late AnimationController _orbitController;
  late AnimationController _sweepController;
  late AnimationController _matchSlideController;
  late Animation<double> _pulseAnim;
  late Animation<double> _matchSlideAnim;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<void>? _presenceChangedSub;
  StreamSubscription<List<Map<String, dynamic>>>? _incomingMatchesSub;
  bool _checkingIncomingMatches = false;
  String? _activeIncomingMatchId;
  UserModel? _me;
  Position? _currentPosition;
  bool _loading = true;
  Timer? _incomingDebounceTimer;
  Timer? _skipMatchTimer;
  Timer? _scanTimer;
  DateTime _lastLocationUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isMatchPending = false;
  bool _scanning = false;
  int _matchIndex = 0;
  bool _showMatchCard = false;
  bool _shareProfile = true;

  // Mini profil popup
  int? _selectedDotIndex;

  String get _myUid => AuthService().currentUserId;
  bool get _signalActive => SignalScreen.isSignalActive;
  set _signalActive(bool v) => SignalScreen.isSignalActive = v;
  AppLocalizations get _l10n => context.l10n;

  List<Map<String, dynamic>> _nearbyPeople = [];
  List<Map<String, dynamic>> _signalPlaces = [];
  DateTime _lastSignalPlacesFetch = DateTime.fromMillisecondsSinceEpoch(0);

  late List<Map<String, double>> _orbitParams;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _matchSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _matchSlideAnim = CurvedAnimation(
      parent: _matchSlideController,
      curve: Curves.easeOutCubic,
    );

    _orbitParams = _buildOrbitParams(0);
    _bootstrap();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _presenceChangedSub?.cancel();
    _incomingMatchesSub?.cancel();
    _incomingDebounceTimer?.cancel();
    _skipMatchTimer?.cancel();
    _scanTimer?.cancel();
    if (_myUid.isNotEmpty) {
      unawaited(
        _firestoreService.setOnlineStatus(_myUid, false).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint('Signal offline sync failed: $error\n$stackTrace');
        }),
      );
    }
    _pulseController.dispose();
    _orbitController.dispose();
    _sweepController.dispose();
    _matchSlideController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_myUid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final me = await _firestoreService.getUser(_myUid);
      final position = await _locationService
          .getCurrentPosition()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (!mounted) return;
      setState(() {
        _me = me;
        _currentPosition = position;
        _shareProfile = !(me?.isGhostMode ?? false);
      });

      if (position != null) {
        await _firestoreService.updateLocation(
          _myUid,
          position.latitude,
          position.longitude,
        );
        await _refreshNearby(position);
      }

      unawaited(_checkIncomingMatches());
      await _incomingMatchesSub?.cancel();
      _incomingMatchesSub = _firestoreService
          .getPendingIncomingMatchesStream()
          .listen(
            (_) => _debounceCheckIncoming(),
            onError: (e) => debugPrint('Incoming matches stream error: $e'),
          );

      await _presenceChangedSub?.cancel();
      _presenceChangedSub = _realtimeService.presenceChanged.listen((_) async {
        final position = _currentPosition;
        if (position == null || !mounted) return;
        try {
          await _refreshNearby(position);
        } catch (error, stackTrace) {
          debugPrint('Presence refresh failed: $error\n$stackTrace');
        }
      });

      await _firestoreService.setOnlineStatus(_myUid, _signalActive);

      await _positionSub?.cancel();
      _positionSub = _locationService.positionStream.listen(
        (position) async {
          if (!mounted) return;
          if (DateTime.now().difference(_lastLocationUpdate) < const Duration(seconds: 5)) {
            return;
          }
          _lastLocationUpdate = DateTime.now();
          _currentPosition = position;
          try {
            await _firestoreService.updateLocation(
              _myUid,
              position.latitude,
              position.longitude,
            );
            await _refreshNearby(position);
          } catch (error, stackTrace) {
            debugPrint('Signal location refresh failed: $error\n$stackTrace');
          }
        },
        onError: (e) => debugPrint('Position stream error: $e'),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _refreshingNearby = false;

  Future<void> _refreshNearby(Position position) async {
    if (_myUid.isEmpty || _refreshingNearby) return;
    _refreshingNearby = true;
    try {
      await _refreshNearbyInner(position);
    } finally {
      _refreshingNearby = false;
    }
  }

  Future<void> _refreshNearbyInner(Position position) async {

    final shouldRefreshPlaces =
        _signalPlaces.isEmpty ||
        DateTime.now().difference(_lastSignalPlacesFetch).inMinutes >= 2;
    if (shouldRefreshPlaces) {
      await _refreshSignalPlaces(position);
    }

    // Radar artık haritayla aynı havuzu çekiyor: 1.6 km, signalOnly kapalı.
    // "Sinyal aktif" olanlar görsel olarak ve sıralamada ön plana çıkıyor.
    final nearbyAll = await _firestoreService.getNearbyUsersList(
      _myUid,
      position.latitude,
      position.longitude,
      radiusKm: 1.6,
      signalOnly: false,
    );

    // Haritadaki "modeNearbyUsers" filtresiyle eşit görünür havuz:
    // konumu olan, görünür ve online kullanıcılar.
    final nearby = nearbyAll
        .where(
          (u) => u.location != null && u.isVisible && u.isOnline,
        )
        .toList();

    final mapped =
        nearby.map((user) {
          final shared = _me == null
              ? <String>[]
              : user.interests
                    .where((interest) => _me!.interests.contains(interest))
                    .take(3)
                    .toList();
          final distance = _locationService.getDistance(
            position.latitude,
            position.longitude,
            user.location?.latitude ?? position.latitude,
            user.location?.longitude ?? position.longitude,
          );
          final normalizedGender = _normalizeGender(user.gender);

          final anonymous = user.isGhostMode;
          final displayName = anonymous
              ? null
              : (user.hasProfile ? user.displayName : user.username);
          final emoji = anonymous
              ? null
              : ((displayName?.isNotEmpty ?? false)
                    ? displayName!.characters.first.toUpperCase()
                    : user.username.characters.first.toUpperCase());

          final meetingSpots = _buildMeetingSpots(user, shared);

          return <String, dynamic>{
            'uid': user.uid,
            'name': displayName,
            'username': anonymous ? null : '@${user.username}',
            'emoji': emoji,
            'dist': _locationService.formatDistance(distance),
            'distValue': distance.round(),
            'mode': _modeName(user.mode),
            'modeId': user.mode,
            'color': _modeColor(user.mode),
            'compatibility': _calculateCompatibility(user, shared, distance),
            'canMatch': _canMatchWith(user),
            'gender': _genderLabel(normalizedGender),
            'genderCode': normalizedGender,
            'matchPreference': _normalizeMatchPreference(
              user.matchPreference,
              normalizedGender,
            ),
            'pulse': user.pulseScore,
            'commonInterests': shared,
            'meetingSpots': meetingSpots,
            'bio': anonymous ? null : user.bio,
            'anonymous': anonymous,
            'photoUrl': anonymous ? '' : user.profilePhotoUrl,
            'signalActive': user.isSignalActive,
            'sameMode': _me != null && user.mode == _me!.mode,
          };
        }).toList()..sort((a, b) {
          // Önce sinyal aktif olanlar (görünürlük açık)
          final aSig = (a['signalActive'] as bool?) ?? false;
          final bSig = (b['signalActive'] as bool?) ?? false;
          if (aSig != bSig) return bSig ? 1 : -1;
          // Sonra aynı moddakiler
          final aMode = (a['sameMode'] as bool?) ?? false;
          final bMode = (b['sameMode'] as bool?) ?? false;
          if (aMode != bMode) return bMode ? 1 : -1;
          // Sonra uyumluluk skoru
          final compatibility = (b['compatibility'] as int).compareTo(
            a['compatibility'] as int,
          );
          if (compatibility != 0) return compatibility;
          // En son mesafe
          return (a['distValue'] as int).compareTo(b['distValue'] as int);
        });

    if (!mounted) return;
    setState(() {
      _nearbyPeople = mapped;
      _orbitParams = _buildOrbitParams(mapped.length);
      if (_selectedDotIndex != null &&
          _selectedDotIndex! >= _nearbyPeople.length) {
        _selectedDotIndex = null;
      }
      if (_nearbyPeople.isEmpty) {
        _showMatchCard = false;
        _matchIndex = 0;
      } else if (_matchIndex >= _nearbyPeople.length) {
        _matchIndex = _nearbyPeople.length - 1;
      }
    });
  }

  Future<void> _refreshSignalPlaces(Position position) async {
    try {
      final rawPlaces = await _placesService.getNearbyPlaces(
        lat: position.latitude,
        lng: position.longitude,
        modeId: _me?.mode ?? ModeConfig.defaultId,
        radius: 1400,
      );
      final communitySignals = await _firestoreService
          .getCommunitySignalsForPlaces(rawPlaces);

      _signalPlaces = _placesService.mergePulseSignals(
        rawPlaces,
        communitySignals: communitySignals,
      );
      _lastSignalPlacesFetch = DateTime.now();
    } catch (e, st) {
      debugPrint('Signal places refresh failed: $e\n$st');
    }
  }

  List<String> _buildMeetingSpots(
    UserModel other,
    List<String> sharedInterests,
  ) {
    if (_signalPlaces.isEmpty) return const [];

    final ranked = List<Map<String, dynamic>>.from(_signalPlaces)
      ..sort((a, b) {
        final aScore = _meetingSpotScore(a, other, sharedInterests);
        final bScore = _meetingSpotScore(b, other, sharedInterests);
        return bScore.compareTo(aScore);
      });

    return ranked
        .take(2)
        .map((place) => place['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  int _meetingSpotScore(
    Map<String, dynamic> place,
    UserModel other,
    List<String> sharedInterests,
  ) {
    final pulse = (place['pulse_score'] as num?)?.toInt() ?? 0;
    final trend = (place['trend_score'] as num?)?.toInt() ?? 0;
    final openBoost = place['open_now'] == true ? 16 : 0;
    final modeBoost = _placeFitsMode(place, other.mode) ? 14 : 0;
    final myModeBoost = _placeFitsMode(place, _me?.mode) ? 10 : 0;
    final interestBoost = sharedInterests.length * 5;
    return pulse + trend + openBoost + modeBoost + myModeBoost + interestBoost;
  }

  bool _placeFitsMode(Map<String, dynamic> place, String? mode) {
    final desiredTypes = PlacesService.modeTypes[mode] ?? const <String>[];
    final placeTypes = List<String>.from(place['types'] ?? const <String>[]);
    return placeTypes.any(desiredTypes.contains);
  }

  List<Map<String, double>> _buildOrbitParams(int count) {
    final rng = Random(42 + count);
    return List.generate(count, (i) {
      return {
        'radius': 55.0 + rng.nextDouble() * 50,
        'speed': 0.2 + rng.nextDouble() * 0.6,
        'offset': rng.nextDouble() * 2 * pi,
        'direction': rng.nextBool() ? 1.0 : -1.0,
      };
    });
  }

  int _calculateCompatibility(
    UserModel other,
    List<String> sharedInterests,
    double distanceMeters,
  ) {
    var score = 36 + (sharedInterests.length * 13);

    if (_me != null && _me!.mode == other.mode) score += 14;
    if (_me != null && _me!.city.isNotEmpty && _me!.city == other.city) {
      score += 6;
    }
    if (_me != null &&
        _me!.purpose.isNotEmpty &&
        _me!.purpose == other.purpose) {
      score += 8;
    }

    final pulseGap = _me == null
        ? 0
        : (_me!.pulseScore - other.pulseScore).abs();
    score += (14 - (pulseGap / 10).round()).clamp(0, 14);

    if (distanceMeters <= 150) {
      score += 10;
    } else if (distanceMeters <= 300) {
      score += 7;
    } else if (distanceMeters <= 500) {
      score += 4;
    }

    return score.clamp(1, 99);
  }

  String _modeName(String? mode) {
    return _l10n.modeLabel(ModeConfig.normalizeId(mode));
  }

  /// Defensive cast: backend sometimes delivers `Map<String,dynamic>` directly,
  /// sometimes a generic `Map` (e.g. after JSON decode). Returns empty on null.
  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _normalizeGender(String? gender) {
    final normalized = gender?.trim().toLowerCase() ?? '';
    switch (normalized) {
      case 'male':
      case 'man':
      case 'erkek':
        return 'male';
      case 'female':
      case 'woman':
      case 'kadin':
      case 'kadın':
        return 'female';
      case 'nonbinary':
      case 'non-binary':
      case 'diger':
      case 'diğer':
        return 'nonbinary';
      default:
        return normalized;
    }
  }

  String _normalizeMatchPreference(String? preference, String gender) {
    final normalized = preference?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty || normalized == 'auto') {
      switch (gender) {
        case 'male':
          return 'women';
        case 'female':
          return 'men';
        default:
          return 'everyone';
      }
    }

    switch (normalized) {
      case 'women':
      case 'woman':
      case 'kadınlar':
      case 'kadinlar':
        return 'women';
      case 'men':
      case 'man':
      case 'erkekler':
        return 'men';
      default:
        return 'everyone';
    }
  }

  bool _allowsGender(String preference, String targetGender) {
    if (targetGender.isEmpty) {
      return preference == 'everyone';
    }

    switch (preference) {
      case 'women':
        return targetGender == 'female';
      case 'men':
        return targetGender == 'male';
      default:
        return true;
    }
  }

  bool _canMatchWith(UserModel other) {
    final myGender = _normalizeGender(_me?.gender);
    final otherGender = _normalizeGender(other.gender);
    final myPreference = _normalizeMatchPreference(
      _me?.matchPreference,
      myGender,
    );
    final otherPreference = _normalizeMatchPreference(
      other.matchPreference,
      otherGender,
    );
    return _allowsGender(myPreference, otherGender) &&
        _allowsGender(otherPreference, myGender);
  }

  String _genderLabel(String gender) {
    switch (gender) {
      case 'male':
        return context.tr3(tr: 'Erkek', en: 'Male', de: 'Männlich');
      case 'female':
        return context.tr3(tr: 'Kadın', en: 'Female', de: 'Weiblich');
      case 'nonbinary':
        return context.tr3(tr: 'Non-binary', en: 'Non-binary', de: 'Nicht-binär');
      default:
        return context.tr3(
          tr: 'Belirtilmedi',
          en: 'Unspecified',
          de: 'Nicht angegeben',
        );
    }
  }

  Color _modeColor(String? mode) => ModeConfig.byId(mode).color;

  Future<void> _toggleProfileSharing(bool value) async {
    if (_myUid.isEmpty) return;
    setState(() => _shareProfile = value);
    await _firestoreService.updateProfile(_myUid, {
      'privacyLevel': value ? 'full' : 'ghost',
      'isVisible': true,
    });
  }

  Future<void> _toggleSignal() async {
    if (_signalActive) {
      setState(() {
        _signalActive = false;
        _scanning = false;
        _showMatchCard = false;
        _selectedDotIndex = null;
      });
      await _firestoreService.setOnlineStatus(_myUid, false);
    } else {
      final position =
          _currentPosition ?? await _locationService.getCurrentPosition();
      if (position == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _l10n.phrase('Konum açık olmadan sinyal başlatılamaz.'),
            ),
          ),
        );
        return;
      }

      setState(() {
        _signalActive = true;
        _scanning = true;
        _showMatchCard = false;
        _matchIndex = 0;
        _selectedDotIndex = null;
      });
      HapticFeedback.mediumImpact();
      await _firestoreService.updateLocation(
        _myUid,
        position.latitude,
        position.longitude,
      );
      await _firestoreService.updateProfile(_myUid, {'isVisible': true});
      await _firestoreService.setOnlineStatus(_myUid, true);
      await _refreshNearby(position);

      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(milliseconds: 3000), () {
        if (mounted && _signalActive) {
          if (_nearbyPeople.isEmpty) {
            setState(() => _scanning = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Şu an yeni bir eşleşme yok. Sinyal aktif kaldı.',
                ),
                backgroundColor: AppColors.bgCard,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            return;
          }
          HapticFeedback.heavyImpact();
          _matchSlideController.forward(from: 0);
          setState(() {
            _scanning = false;
            _showMatchCard = true;
          });
        }
      });
    }
  }

  void _skipMatch() {
    if (_nearbyPeople.isEmpty) return;

    setState(() {
      _showMatchCard = false;
      _scanning = true;
      _selectedDotIndex = null;
    });
    _matchSlideController.reset();
    _skipMatchTimer?.cancel();
    _skipMatchTimer = Timer(const Duration(milliseconds: 400), () {
      _showMatchCard = false;
    });
    final nextIndex = _matchIndex + 1;
    if (nextIndex < _nearbyPeople.length) {
      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted && _signalActive) {
          HapticFeedback.heavyImpact();
          _matchSlideController.forward(from: 0);
          setState(() {
            _matchIndex = nextIndex;
            _scanning = false;
            _showMatchCard = true;
          });
        }
      });
    } else {
      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted && _signalActive) {
          setState(() => _scanning = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _l10n.phrase(
                  'Şu an yeni eşleşme yok. Sinyal aktif — yeni biri gelince bildirim alacaksın.',
                ),
              ),
              backgroundColor: AppColors.bgCard,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      });
    }
  }

  /// Yeni radar akışı: önce anonim sohbet başlatır.
  /// Eşleşme/arkadaşlık istekleri sohbet içinden, iki taraf da
  /// rahat hissettiğinde tetiklenebilir (`requestChatPermanence`,
  /// `sendFriendRequest` zaten ChatScreen içinde mevcut).
  Future<void> _startAnonymousChat() async {
    if (_nearbyPeople.isEmpty || _myUid.isEmpty) return;
    if (_isMatchPending) return;

    final person = _nearbyPeople[_matchIndex];

    // Karşı taraf zaten anonim ise rumuz "Anonim Kullanıcı"
    final otherDisplay = person['anonymous'] == true
        ? _l10n.phrase('Anonim Kullanıcı')
        : (person['name'] as String? ?? _l10n.phrase('Anonim Kullanıcı'));

    // Bende nasıl görünmek istediğimi sor (anonim mi profil mi)
    final anonChoice = await _showAnonChoiceSheet(otherDisplay);
    if (anonChoice == null || !mounted) return; // kapatıldı

    setState(() => _isMatchPending = true);
    try {
      final chat = await _firestoreService.createOrGetDirectChat(
        _myUid,
        person['uid'].toString(),
        isTemporary: true,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => ChatScreen(
            user: {
              'uid': person['uid'],
              'chatId': chat.id,
              'name': person['anonymous'] == true
                  ? _l10n.phrase('Anonim Kullanıcı')
                  : person['name'],
              'username': person['anonymous'] == true
                  ? '@anonymous'
                  : person['username'],
              'bio': person['anonymous'] == true ? '' : person['bio'],
              'isTemporary': true,
              'anonymous': person['anonymous'] == true,
              'myAnonymous': anonChoice,
            },
          ),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr3(
              tr: 'Sohbet açılamadı, tekrar dene.',
              en: 'Could not open the chat, try again.',
              de: 'Chat konnte nicht geöffnet werden, versuche es erneut.',
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMatchPending = false);
    }
  }

  /// Shows a bottom sheet asking the user how they want to appear in the match chat.
  /// Returns true = anonymous, false = show profile, null = dismissed.
  Future<bool?> _showAnonChoiceSheet(String otherName) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr3(
                  tr: 'Nasıl görünmek istersin?',
                  en: 'How do you want to appear?',
                  de: 'Wie möchtest du erscheinen?',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr3(
                  tr: '$otherName ile açılacak sohbette kimliğini seç.',
                  en: 'Choose your identity for the chat with $otherName.',
                  de: 'Wähle deine Identität für den Chat mit $otherName.',
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildAnonChoiceButton(
                      icon: Icons.person_off_rounded,
                      title: context.tr3(tr: 'Anonim', en: 'Anonymous', de: 'Anonym'),
                      subtitle: context.tr3(
                        tr: 'Kimliğin gizli kalır',
                        en: 'Your identity stays hidden',
                        de: 'Deine Identität bleibt verborgen',
                      ),
                      color: AppColors.modeSosyal,
                      onTap: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAnonChoiceButton(
                      icon: Icons.person_rounded,
                      title: context.tr3(tr: 'Profil ile', en: 'With profile', de: 'Mit Profil'),
                      subtitle: context.tr3(
                        tr: 'Adın ve fotoğrafın görünür',
                        en: 'Your name and photo visible',
                        de: 'Name und Foto sichtbar',
                      ),
                      color: AppColors.primary,
                      onTap: () => Navigator.of(ctx).pop(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnonChoiceButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkIncomingMatches() async {
    if (_checkingIncomingMatches || !mounted || _myUid.isEmpty) {
      return;
    }

    _checkingIncomingMatches = true;
    try {
      final pending = await _firestoreService.getPendingIncomingMatches();
      if (!mounted) return;

      if (pending.isEmpty) {
        _activeIncomingMatchId = null;
        return;
      }

      final next = pending.first;
      final matchId = (next['id'] ?? '').toString();
      if (matchId.isEmpty || matchId == _activeIncomingMatchId) {
        return;
      }

      _activeIncomingMatchId = matchId;
      await _showIncomingMatchSheet(next);
    } catch (error, stackTrace) {
      debugPrint('Incoming match check failed: $error\n$stackTrace');
    } finally {
      _checkingIncomingMatches = false;
    }
  }

  void _debounceCheckIncoming() {
    _incomingDebounceTimer?.cancel();
    _incomingDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      await _checkIncomingMatches();
    });
  }

  Future<void> _showIncomingMatchSheet(Map<String, dynamic> match) async {
    if (!mounted) return;

    final currentUserId = _myUid;
    if (currentUserId.isEmpty) return;

    final user1 = _asStringMap(match['user1']);
    final user2 = _asStringMap(match['user2']);

    final other = (user1['id']?.toString() ?? '') == currentUserId ? user2 : user1;
    final otherUid = other['id']?.toString() ?? '';
    if (otherUid.isEmpty) {
      _activeIncomingMatchId = null;
      return;
    }

    final otherName = (other['displayName']?.toString().trim().isNotEmpty ?? false)
        ? other['displayName'].toString().trim()
        : other['username']?.toString() ?? _l10n.t('user');
    final otherUsername = other['username']?.toString() ?? '';
    final otherGender = _normalizeGender(other['gender']?.toString());
    final otherMode = ModeConfig.normalizeId(other['mode']?.toString());
    final compatibility = (match['compatibility'] as num?)?.toInt() ?? 0;
    final commonInterests = List<String>.from(
      match['commonInterests'] as List? ?? const <String>[],
    );

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr3(
                    tr: 'Yeni bir eşleşme isteğin var',
                    en: 'You have a new match request',
                    de: 'Du hast eine neue Match-Anfrage',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr3(
                    tr: 'Karar vermeden önce temel bilgileri burada görebilirsin.',
                    en: 'You can review the basics here before you decide.',
                    de: 'Hier kannst du dir die wichtigsten Infos ansehen, bevor du entscheidest.',
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          otherName.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              otherName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            if (otherUsername.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '@$otherUsername',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '%$compatibility',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHeroStatChip(_genderLabel(otherGender)),
                    _buildHeroStatChip(_modeName(otherMode)),
                    if (commonInterests.isNotEmpty)
                      _buildHeroStatChip(
                        context.tr3(
                          tr: '${commonInterests.length} ortak ilgi',
                          en: '${commonInterests.length} shared interests',
                          de: '${commonInterests.length} gemeinsame Interessen',
                        ),
                      ),
                  ],
                ),
                if (commonInterests.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: commonInterests
                        .take(4)
                        .map(
                          (interest) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              interest,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final success = await _firestoreService.respondToMatch(
                            match['id'].toString(),
                            status: 'declined',
                          );
                          if (!mounted) return;
                          _activeIncomingMatchId = null;
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr3(
                                    tr: 'Eşleşme isteği reddedildi.',
                                    en: 'Match request declined.',
                                    de: 'Match-Anfrage abgelehnt.',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          context.tr3(tr: 'Şimdilik geç', en: 'Not now', de: 'Nicht jetzt'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          if (!mounted) return;
                          // Ask the accepter how they want to appear in the chat
                          final anonChoice = await _showAnonChoiceSheet(otherName);
                          if (anonChoice == null || !mounted) return; // dismissed
                          final myAnonymous = anonChoice;
                          final chat = await _firestoreService.createOrGetDirectChat(
                            currentUserId,
                            otherUid,
                            isTemporary: true,
                          );
                          final success = await _firestoreService.respondToMatch(
                            match['id'].toString(),
                            status: 'accepted',
                            chatId: chat.id,
                            anonymousInChat: myAnonymous,
                          );
                          if (!mounted) return;
                          _activeIncomingMatchId = null;
                          if (!success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr3(
                                    tr: 'Eşleşme şu anda tamamlanamadı.',
                                    en: 'The match could not be completed right now.',
                                    de: 'Das Match konnte gerade nicht abgeschlossen werden.',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          // Determine how the other person appears to me:
                          // their anonymous flag comes from initiator1AnonymousInChat in match data
                          final otherIsAnon = match['initiator1AnonymousInChat'] == true;
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, _, _) => ChatScreen(
                                user: {
                                  'uid': otherUid,
                                  'chatId': chat.id,
                                  'name': otherIsAnon
                                      ? _l10n.phrase('Anonim Kullanıcı')
                                      : otherName,
                                  'username': otherIsAnon
                                      ? '@anonymous'
                                      : (otherUsername.isEmpty ? '@anonymous' : '@$otherUsername'),
                                  'bio': otherIsAnon ? '' : (other['bio']?.toString() ?? ''),
                                  'isTemporary': true,
                                  'anonymous': otherIsAnon,
                                  'myAnonymous': myAnonymous,
                                },
                              ),
                              transitionsBuilder:
                                  (context, anim, secondaryAnim, child) =>
                                  FadeTransition(opacity: anim, child: child),
                              transitionDuration: const Duration(milliseconds: 320),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          context.tr3(tr: 'Sohbeti başlat', en: 'Start chat', de: 'Chat starten'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    _activeIncomingMatchId = null;
  }

  void _openProfile(Map<String, dynamic> person) {
    if (person['anonymous'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _l10n.phrase('Bu kullanıcı anonim modda. Profil detayları gizli.'),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: person['uid'].toString()),
      ),
    );
  }

  void _onDotTap(int index) {
    HapticFeedback.lightImpact();
    setState(
      () => _selectedDotIndex = _selectedDotIndex == index ? null : index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _l10n.phrase('Sinyal'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_signalActive) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _shareProfile
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: _shareProfile
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppColors.warning.withValues(alpha: 0.7),
              size: 22,
            ),
            onPressed: _showPrivacySheet,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_selectedDotIndex != null) {
            setState(() => _selectedDotIndex = null);
          }
        },
        child: Column(
          children: [
            _buildSignalHeroPanel(),
            if (!_shareProfile) _buildAnonBanner(),

            // Sinyal gücü göstergesi
            if (_signalActive) _buildSignalStrength(),

            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_showMatchCard && _nearbyPeople.isNotEmpty)
              Expanded(child: _buildMatchCardAnimated())
            else
              Expanded(child: _buildMainView()),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalHeroPanel() {
    final accent = _signalActive ? AppColors.primary : AppColors.modeSosyal;
    final statusText = _signalActive
        ? (_scanning
              ? context.tr3(
                  tr: 'Tarama s\u00fcr\u00fcyor',
                  en: 'Scanning in progress',
                  de: 'Scan l\u00e4uft',
                )
              : context.tr3(
                  tr: 'Radar aktif',
                  en: 'Radar is active',
                  de: 'Radar ist aktiv',
                ))
        : context.tr3(
            tr: 'Radar kapal\u0131',
            en: 'Radar is off',
            de: 'Radar ist aus',
          );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            AppColors.bgSurface,
            AppColors.bgCard,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar_rounded, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                context.tr3(tr: '\u015eimdi', en: 'Now', de: 'Jetzt'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.tr3(
              tr: 'Yak\u0131ndaki uyumlu insanlar\u0131 an\u0131nda tara',
              en: 'Scan for compatible people around you in real time',
              de: 'Scanne kompatible Menschen in deiner N\u00e4he in Echtzeit',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr3(
              tr:
                  'Sinyal a\u00e7\u0131kken radar canl\u0131 olarak yak\u0131ndaki ki\u015fileri, e\u015fle\u015fme ihtimalini ve bulu\u015fma i\u00e7in uygun noktalar\u0131 g\u00f6sterir.',
              en:
                  'When signal is on, the radar reveals nearby people, match potential, and good places to meet.',
              de:
                  'Wenn das Signal aktiv ist, zeigt das Radar Menschen in deiner N\u00e4he, Match-Potenzial und passende Treffpunkte.',
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              height: 1.45,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroStatChip(
                context.tr3(
                  tr: '${_nearbyPeople.length} menzilde',
                  en: '${_nearbyPeople.length} in range',
                  de: '${_nearbyPeople.length} in Reichweite',
                ),
              ),
              _buildHeroStatChip(
                context.tr3(
                  tr: _shareProfile ? 'Profil g\u00f6r\u00fcn\u00fcr' : 'Anonim mod',
                  en: _shareProfile ? 'Profile visible' : 'Anonymous mode',
                  de: _shareProfile ? 'Profil sichtbar' : 'Anonymer Modus',
                ),
              ),
              _buildHeroStatChip(
                context.tr3(tr: '800m alan', en: '800m radius', de: '800m Radius'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildAnlikIntentCta(),
        ],
      ),
    );
  }

  Widget _buildAnlikIntentCta() {
    return GestureDetector(
      onTap: _openInstantActivityComposer,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.neonCyan.withValues(alpha: 0.22),
              AppColors.primaryGlow.withValues(alpha: 0.18),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.neonCyan.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.bolt_rounded,
                color: AppColors.neonCyan,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr3(
                      tr: 'Şu an için niyet at',
                      en: 'Drop an instant intent',
                      de: 'Spontane Absicht senden',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr3(
                      tr: 'Anlık etkinlik aç — yakındaki uyumlular görsün',
                      en: 'Open an instant activity for nearby people',
                      de: 'Spontane Aktivität für Personen in der Nähe',
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.55),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInstantActivityComposer() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateActivityScreen(
          initialCategory: ActivityCategory.anlik,
        ),
      ),
    );
  }

  Widget _buildHeroStatChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAnonBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_rounded,
            size: 16,
            color: AppColors.warning.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _l10n.phrase('Anonim moddasın. Adın ve profilin gizli.'),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.warning.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalStrength() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.wifi_tethering_rounded,
            size: 14,
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          ...List.generate(5, (i) {
            return Container(
              width: 20,
              height: 4,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < 4
                    ? AppColors.primary.withValues(alpha: 0.3 + i * 0.15)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
          const SizedBox(width: 8),
          Text(
            '${_nearbyPeople.length} ${_l10n.phrase('kişi menzilde')}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const Spacer(),
          Text(
            _scanning ? _l10n.phrase('Aranıyor...') : _l10n.phrase('Aktif'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _scanning ? AppColors.warning : AppColors.success,
            ),
          ),
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
              builder: (_, child) => Transform.scale(
                scale: _signalActive ? _pulseAnim.value : 1.0,
                child: child,
              ),
              child: SizedBox(
                width: 280,
                height: 280,
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
                        builder: (context, child) {
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
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: List.generate(_nearbyPeople.length, (i) {
                            final params = _orbitParams[i];
                            final angle =
                                params['offset']! +
                                (_orbitController.value *
                                    2 *
                                    pi *
                                    params['speed']! *
                                    params['direction']!);
                            final radius = params['radius']!;
                            final dx = radius * cos(angle);
                            final dy = radius * sin(angle);
                            return Transform.translate(
                              offset: Offset(dx, dy),
                              child: GestureDetector(
                                onTap: () => _onDotTap(i),
                                child: _buildRadarDot(
                                  _nearbyPeople[i],
                                  i == _selectedDotIndex,
                                ),
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
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _signalActive
                              ? AppColors.primary
                              : AppColors.bgCard,
                          border: Border.all(
                            color: _signalActive
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.08),
                            width: 2,
                          ),
                          boxShadow: _signalActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 36,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _signalActive
                                  ? (_scanning
                                        ? Icons.radar_rounded
                                        : Icons.wifi_tethering_rounded)
                                  : Icons.wifi_tethering_rounded,
                              size: 30,
                              color: _signalActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _signalActive
                                  ? (_scanning
                                        ? _l10n.phrase('Arıyor')
                                        : _l10n.phrase('Aktif'))
                                  : _l10n.phrase('Aç'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _signalActive
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Mini profil popup
        if (_selectedDotIndex != null &&
            _selectedDotIndex! < _nearbyPeople.length)
          _buildMiniProfile(_nearbyPeople[_selectedDotIndex!]),

        // Durum
        if (_selectedDotIndex == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _signalActive
                  ? _scanning
                        ? _l10n.phrase('Uyumlu kişiler aranıyor...')
                        : _l10n.phrase('Sinyal aktif. Bir noktaya dokun.')
                  : _nearbyPeople.isEmpty
                  ? _l10n.phrase(
                      'Yakında aktif birileri göründüğünde burada listelenecek.',
                    )
                  : '${_nearbyPeople.length} ${_l10n.phrase('kişi yakınında')}.\n${_l10n.phrase('Merkez butona bas ve başla.')}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.35),
                height: 1.5,
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Yakındakiler
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'YAKININDA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.25),
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '${_nearbyPeople.length} kişi',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: _nearbyPeople.isEmpty
              ? Center(
                  child: Text(
                    'Su anda menzilde aktif biri gorunmuyor.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.32),
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _nearbyPeople.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _onDotTap(i),
                    child: _buildNearbyCard(
                      _nearbyPeople[i],
                      i == _selectedDotIndex,
                    ),
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
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.03),
                width: 1,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: size / 2 - 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.bgMain,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  fontWeight: FontWeight.w500,
                ),
              ),
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
    final signalActive = (p['signalActive'] as bool?) ?? false;
    // Sinyal aktif olanlar daha büyük, daha yoğun glow ve primary rengin
    // sıcak tonuyla halka alıyor; pasifler donuk halde duruyor.
    final baseSize = signalActive ? 34.0 : 26.0;
    final selSize = signalActive ? 42.0 : 32.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: selected ? selSize : baseSize,
      height: selected ? selSize : baseSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? color.withValues(alpha: signalActive ? 0.4 : 0.22)
            : color.withValues(
                alpha: signalActive ? 0.25 : 0.1,
              ),
        border: Border.all(
          color: signalActive
              ? AppColors.primary.withValues(alpha: selected ? 0.95 : 0.7)
              : color.withValues(alpha: selected ? 0.55 : 0.28),
          width: signalActive ? (selected ? 2.4 : 2.0) : (selected ? 1.6 : 1.0),
        ),
        boxShadow: signalActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: selected ? 0.55 : 0.32,
                  ),
                  blurRadius: selected ? 22 : 14,
                  spreadRadius: selected ? 2 : 1,
                ),
              ]
            : [
                BoxShadow(
                  color: color.withValues(alpha: selected ? 0.32 : 0.12),
                  blurRadius: selected ? 14 : 6,
                ),
              ],
      ),
      child: Icon(
        isAnon ? Icons.person_off_rounded : Icons.person_rounded,
        size: selected ? (signalActive ? 20 : 16) : (signalActive ? 16 : 12),
        color: signalActive
            ? Colors.white.withValues(alpha: isAnon ? 0.7 : 1.0)
            : color.withValues(alpha: isAnon ? 0.4 : 0.65),
      ),
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
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: isAnon
                ? Icon(
                    Icons.person_off_rounded,
                    size: 20,
                    color: color.withValues(alpha: 0.5),
                  )
                : Center(
                    child: Text(
                      p['emoji'] ?? '🧑',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isAnon
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white,
                        ),
                      ),
                    ),
                    if (isAnon) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.visibility_off_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ],
                    if ((p['signalActive'] as bool?) ?? false) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.wifi_tethering_rounded,
                              size: 10,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _l10n.phrase('Sinyal'),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _miniInfoTag(
                      Icons.location_on_rounded,
                      p['dist'],
                      Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 10),
                    _miniInfoTag(Icons.circle, p['mode'], color),
                    const SizedBox(width: 10),
                    _miniInfoTag(
                      Icons.favorite_rounded,
                      'Pulse ${p['pulse']}',
                      AppColors.primary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${p['compatibility']}%',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfoTag(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
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
          child: Opacity(
            opacity: _matchSlideAnim.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: _buildMatchContent(),
    );
  }

  Widget _buildMatchContent() {
    if (_nearbyPeople.isEmpty) {
      return const SizedBox.shrink();
    }

    final person = _nearbyPeople[_matchIndex];
    final isAnon = person['anonymous'] == true;
    final color = person['color'] as Color;
    final name = isAnon ? 'Anonim Kullanıcı' : (person['name'] ?? 'Anonim');
    final username = isAnon ? 'Profil gizli' : (person['username'] ?? '');
    final bio = isAnon ? null : person['bio'];
    final gender = person['gender']?.toString() ?? '';
    final interests = person['commonInterests'] as List<String>;
    final meetingSpots = List<String>.from(person['meetingSpots'] ?? const []);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 64,
            height: 64,
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
                  blurRadius: 24,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _l10n.phrase('Eşleşme Bulundu!'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _l10n.phrase('Sinyal aktif — arka planda aranıyor'),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.success.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Kişi kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.15),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: isAnon
                          ? Icon(
                              Icons.person_rounded,
                              size: 26,
                              color: color.withValues(alpha: 0.5),
                            )
                          : Center(
                              child: Text(
                                person['emoji'] ?? '🧑',
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              if (isAnon) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.visibility_off_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            username,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(
                                alpha: isAnon ? 0.25 : 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${person['compatibility']}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'uyum',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.primary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (bio != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bgMain.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      bio,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMatchInfo(Icons.location_on_rounded, person['dist']),
                    const SizedBox(width: 14),
                    _buildMatchInfo(
                      Icons.favorite_rounded,
                      'Pulse ${person['pulse']}',
                    ),
                    const SizedBox(width: 14),
                    _buildMatchInfo(Icons.circle, person['mode'], color: color),
                    const SizedBox(width: 14),
                    _buildMatchInfo(Icons.person_rounded, gender),
                  ],
                ),
                if (interests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                          _l10n.phrase('Ortak İlgi Alanları').toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.25),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: interests
                        .map(
                          (i) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              i,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (meetingSpots.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'BULUSMA ONERILERI',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.25),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: meetingSpots
                        .map(
                          (spot) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                            child: Text(
                              spot,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Aksiyonlar — yeni akış: önce anonim sohbet, eşleşme/arkadaşlık
          // sohbet içinden iki taraf da hazır olunca tetiklenir.
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isMatchPending ? null : _startAnonymousChat,
              icon: _isMatchPending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.chat_bubble_rounded,
                      size: 18,
                    ),
              label: Text(
                _isMatchPending
                    ? context.tr3(
                        tr: 'Sohbet açılıyor…',
                        en: 'Opening chat…',
                        de: 'Chat wird geöffnet…',
                      )
                    : context.tr3(
                        tr: 'Anonim Sohbet Başlat',
                        en: 'Start Anonymous Chat',
                        de: 'Anonymer Chat starten',
                      ),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Akışı açıklayan kısa not
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr3(
                      tr: 'Önce anonim tanışın. Eşleşme veya arkadaşlık isteği sohbet içinden hazır olduğunda gönderilebilir.',
                      en: 'Meet anonymously first. Match or friend request can be sent from inside the chat when both feel ready.',
                      de: 'Lerne dich erst anonym kennen. Match- oder Freundschaftsanfrage geht später im Chat.',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _skipMatch,
              icon: Icon(
                Icons.skip_next_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              label: Text(
                _l10n.phrase('Sonraki'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _openProfile(person),
              child: Text(
                isAnon ? 'Profil Gizli' : 'Profili Ac',
                style: TextStyle(
                  color: isAnon
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMatchInfo(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: color ?? Colors.white.withValues(alpha: 0.3),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color ?? Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyCard(Map<String, dynamic> p, bool selected) {
    final color = p['color'] as Color;
    final isAnon = p['anonymous'] == true;
    final name = isAnon ? 'Anonim' : (p['name'] ?? 'Anonim');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 150,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.08) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.12),
          width: selected ? 1.5 : 1,
        ),
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
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: isAnon
                    ? Icon(
                        Icons.person_off_rounded,
                        size: 14,
                        color: color.withValues(alpha: 0.4),
                      )
                    : Center(
                        child: Text(
                          p['emoji'] ?? '🧑',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isAnon
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      p['dist'],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p['mode'],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.favorite_rounded,
                size: 10,
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 3),
              Text(
                '${p['compatibility']}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // GİZLİLİK
  // ══════════════════════════════════════
  void _showPrivacySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
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
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _l10n.phrase('Sinyal Gizliliği'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgMain.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _l10n.phrase('Profilini Göster'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _l10n.phrase(
                                'Adın, biyografin ve ilgi alanların görünür',
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _shareProfile,
                        onChanged: (v) async {
                          setSheetState(() => _shareProfile = v);
                          await _toggleProfileSharing(v);
                        },
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.primary,
                        inactiveThumbColor: Colors.white.withValues(alpha: 0.3),
                        inactiveTrackColor: Colors.white.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgMain.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _l10n.phrase(
                            'Anonim modda diğer kullanıcılar sadece modunu, mesafeni ve uyumluluk yüzdesini görür. Adın, fotoğrafın ve biyografin gizli kalır.',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.35),
                            height: 1.5,
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
      ),
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
      colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.12)],
      transform: GradientRotation(angle - 0.8),
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);

    // Sweep çizgisi
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final endPoint = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );

    canvas.drawLine(center, endPoint, linePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
