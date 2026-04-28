import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_localizations.dart';
import '../models/highlight_model.dart';
import '../models/immersive_media.dart';
import '../models/place_visit_model.dart';
import '../models/post_model.dart';
import '../models/shorts_feed_scope.dart';
import '../models/signal_crossing_model.dart';
import '../config/mode_config.dart';
import '../theme/colors.dart';
import '../widgets/activity/activity_profile_rail.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/profile/badges_profile_rail.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_loading.dart';
import '../models/user_model.dart';
import '../services/api_exception.dart';
import '../services/app_locale_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/network_media_headers.dart';
import '../services/place_focus_service.dart';
import '../services/storage_service.dart';
import 'immersive_profile_viewer_screen.dart';
import 'story_status_picker_screen.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'shorts_screen.dart';
import 'create_post_screen.dart';

/// Yeni Profile Screen (Hero + Rails tasarımı).
///
/// Scan katmanı: Hero (foto + isim/bio/mod) → kategorik rail'lar
/// (Fotoğraflar, Storyler, Shorts, Mekanlar).
///
/// [compatibilityScore] — başka kullanıcının profili açılırken eşleşme
/// ekranından iletilen uyum yüzdesi (0-100). Null ise rozet gösterilmez.
class ProfileScreen extends StatefulWidget {
  final String? userId;
  final int? compatibilityScore;

  const ProfileScreen({super.key, this.userId, this.compatibilityScore});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<String> _interestOptions = [
    'Kafeler',
    'Restoranlar',
    'Street Food',
    'Barlar & Gece',
    'Müzik & Konser',
    'Sanat & Müze',
    'Tiyatro & Sinema',
    'Kitap & Okuma',
    'Fitness & Spor',
    'Koşu & Yürüyüş',
    'Parklar & Doğa',
    'Bisiklet',
    'Yoga & Meditasyon',
    'Teknoloji',
    'Board Game',
    'Workshop & Etkinlik',
  ];

  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  static const double _heroHeight = 440;
  static const double _miniNavTriggerOffset = 260;

  UserModel? _user;
  UserModel? _myUser; // ortak ilgi karşılaştırması için
  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isUpdatingMode = false;
  bool _isFollowing = false;
  bool _isFriend = false;
  bool _isBlockedByMe = false;
  bool _hasBlockedMe = false;
  bool _hasPendingIncomingFriendRequest = false;
  bool _hasPendingOutgoingFriendRequest = false;
  String _incomingFriendRequestId = '';
  String _outgoingFriendRequestId = '';

  List<UserModel> _followersList = [];
  List<UserModel> _followingList = [];
  List<UserModel> _friendsList = [];

  /// Rail StreamBuilder'larından güncellenir; immersive viewer açılırken
  /// tüm kategoriler için güncel listeleri birleştirmek için kullanılır.
  List<HighlightModel> _cachedHighlights = const [];
  List<PostModel> _cachedShorts = const [];

  // Phase 3: profile insights
  PostModel? _pinnedPost;
  List<PlaceVisitModel> _placesVisited = const [];
  SignalCrossingSummaryModel _signalCrossings =
      const SignalCrossingSummaryModel.empty();
  bool _isPinningMoment = false;

  bool _showMiniNav = false;

  /// Yalnızca en son tamamlanan yükleme UI'ı günceller; üst üste çağrılarda atlama olmaz.
  int _profileLoadGeneration = 0;

  bool _loadingFollowers = false;
  bool _loadingFollowing = false;
  bool _loadingFriends = false;

  StreamSubscription<List<UserModel>>? _followersSub;
  StreamSubscription<List<UserModel>>? _followingSub;

  String get _myUid => AuthService().currentUserId;
  String get _targetUid => widget.userId ?? _myUid;
  bool get _isMyProfile => widget.userId == null || widget.userId == _myUid;
  AppLocalizations get _l10n => context.l10n;

  String _copy({required String tr, required String en, required String de}) {
    return switch (_l10n.languageCode) {
      'en' => en,
      'de' => de,
      _ => tr,
    };
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProfile();
  }

  @override
  void dispose() {
    _followersSub?.cancel();
    _followingSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.offset > _miniNavTriggerOffset;
    if (shouldShow == _showMiniNav) return;
    setState(() => _showMiniNav = shouldShow);
  }

  Future<void> _loadProfile({bool silent = false}) async {
    final generation = ++_profileLoadGeneration;
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final user = await _firestoreService.getUser(_targetUid);

      // Ortak ilgi alanı karşılaştırması için kendi profilimi de getir
      // (yalnızca başkasının profiline bakıyorsam gerekiyor).
      UserModel? myUser = _myUser;
      if (!_isMyProfile && _myUid.isNotEmpty && myUser == null) {
        try {
          myUser = await _firestoreService.getUser(_myUid);
        } catch (_) {
          // sessizce geç; ortak ilgi rozetini göstermeyeceğiz o kadar
        }
      }

      bool following = _isFollowing;
      bool friend = _isFriend;
      bool blockedByMe = _isBlockedByMe;
      bool blockedMe = _hasBlockedMe;
      bool hasIncomingRequest = _hasPendingIncomingFriendRequest;
      bool hasOutgoingRequest = _hasPendingOutgoingFriendRequest;
      String incomingRequestId = _incomingFriendRequestId;
      String outgoingRequestId = _outgoingFriendRequestId;

      if (!_isMyProfile && _myUid.isNotEmpty) {
        final relation = await _firestoreService.getRelationshipState(
          _myUid,
          _targetUid,
        );

        following = relation?['isFollowing'] == true;
        friend = relation?['isFriend'] == true;
        blockedByMe = relation?['isBlockedByCurrentUser'] == true;
        blockedMe = relation?['hasBlockedCurrentUser'] == true;
        hasIncomingRequest =
            relation?['hasPendingIncomingFriendRequest'] == true;
        hasOutgoingRequest =
            relation?['hasPendingOutgoingFriendRequest'] == true;
        incomingRequestId =
            relation?['incomingFriendRequestId']?.toString() ?? '';
        outgoingRequestId =
            relation?['outgoingFriendRequestId']?.toString() ?? '';
      }

      if (!mounted || generation != _profileLoadGeneration) return;

      setState(() {
        _user = user;
        _myUser = myUser;
        _isFollowing = following;
        _isFriend = friend;
        _isBlockedByMe = blockedByMe;
        _hasBlockedMe = blockedMe;
        _hasPendingIncomingFriendRequest = hasIncomingRequest;
        _hasPendingOutgoingFriendRequest = hasOutgoingRequest;
        _incomingFriendRequestId = incomingRequestId;
        _outgoingFriendRequestId = outgoingRequestId;
        _isLoading = false;
      });

      unawaited(_loadProfileInsights(user, generation));
    } catch (e, st) {
      debugPrint('Profil yükleme hatası: $e\n$st');
      if (!mounted || generation != _profileLoadGeneration) return;

      setState(() => _isLoading = false);
      _showSnackBar(
        _l10n.phrase('Profil yüklenirken hata oluştu.'),
        color: AppColors.error,
      );
    }
  }

  /// Hero altı signal kartı + pinned moment + places rail için gereken
  /// üç uç birbirinden bağımsız; paralel çekip geldikçe setState ederiz.
  Future<void> _loadProfileInsights(UserModel? user, int generation) async {
    if (user == null) return;

    final futures = <Future<void>>[
      _firestoreService.getPlacesVisited(_targetUid).then((places) {
        if (!mounted || generation != _profileLoadGeneration) return;
        setState(() => _placesVisited = places);
      }).catchError((Object e, StackTrace st) {
        debugPrint('Places yükleme hatası: $e\n$st');
      }),
      // Signal crossings yalnızca başka birinin profilinde mantıklı —
      // kendi profilde kendi ile kesişim olmaz.
      if (!_isMyProfile)
        _firestoreService.getSignalCrossings(_targetUid).then((summary) {
          if (!mounted || generation != _profileLoadGeneration) return;
          setState(() => _signalCrossings = summary);
        }).catchError((Object e, StackTrace st) {
          debugPrint('Signal crossings yükleme hatası: $e\n$st');
        }),
      if (user.pinnedPostId != null && user.pinnedPostId!.isNotEmpty)
        _resolvePinnedPost(user.pinnedPostId!).then((post) {
          if (!mounted || generation != _profileLoadGeneration) return;
          setState(() => _pinnedPost = post);
        }).catchError((Object e, StackTrace st) {
          debugPrint('Pinned post çözme hatası: $e\n$st');
        }),
    ];

    await Future.wait(futures);
  }

  Future<PostModel?> _resolvePinnedPost(String postId) async {
    // Dedicated get-by-id endpoint henüz yok; kullanıcı post listesinden çekip
    // id'ye göre filtreliyoruz. Mevcut listeden bulunamazsa null döner.
    final posts = await _firestoreService.fetchUserPostsOnce(_targetUid);
    for (final post in posts) {
      if (post.id == postId) return post;
    }
    return null;
  }

  // ignore: unused_element
  Future<void> _loadFollowers() async {
    if (_loadingFollowers) return;

    setState(() => _loadingFollowers = true);
    await _followersSub?.cancel();

    _followersSub = _firestoreService
        .getFollowers(_targetUid)
        .listen(
          (users) {
            if (!mounted) return;
            setState(() {
              _followersList = users;
              _loadingFollowers = false;
            });
          },
          onError: (e, st) {
            debugPrint('Takipçiler yükleme hatası: $e\n$st');
            if (!mounted) return;
            setState(() => _loadingFollowers = false);
          },
        );
  }

  // ignore: unused_element
  Future<void> _loadFollowing() async {
    if (_loadingFollowing) return;

    setState(() => _loadingFollowing = true);
    await _followingSub?.cancel();

    _followingSub = _firestoreService
        .getFollowing(_targetUid)
        .listen(
          (users) {
            if (!mounted) return;
            setState(() {
              _followingList = users;
              _loadingFollowing = false;
            });
          },
          onError: (e, st) {
            debugPrint('Takip edilenler yükleme hatası: $e\n$st');
            if (!mounted) return;
            setState(() => _loadingFollowing = false);
          },
        );
  }

  Future<void> _loadFriends() async {
    if (_loadingFriends) return;
    setState(() => _loadingFriends = true);
    try {
      final friends = await _firestoreService.getFriendsList(_targetUid);
      if (!mounted) return;
      setState(() {
        _friendsList = friends;
        _loadingFriends = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFriends = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_myUid.isEmpty || _targetUid.isEmpty) return;

    final oldValue = _isFollowing;

    setState(() => _isFollowing = !oldValue);

    try {
      if (oldValue) {
        await _firestoreService.unfollowUser(_myUid, _targetUid);
      } else {
        await _firestoreService.followUser(_myUid, _targetUid);
      }

      await _loadProfile(silent: true);
    } catch (e, st) {
      debugPrint('Takip hatası: $e\n$st');
      if (!mounted) return;

      setState(() => _isFollowing = oldValue);
      _showSnackBar(
        _l10n.phrase('Takip işlemi sırasında hata oluştu.'),
        color: AppColors.error,
      );
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_myUid.isEmpty || _targetUid.isEmpty) return;

    try {
      await _firestoreService.sendFriendRequest(_myUid, _targetUid);
      await _loadProfile(silent: true);
      if (!mounted) return;

      _showSnackBar(
        _l10n.phrase('Arkadaşlık isteği gönderildi!'),
        color: AppColors.success,
      );
    } catch (e, st) {
      debugPrint('Arkadaş isteği hatası: $e\n$st');
      _showSnackBar(
        _l10n.phrase('Arkadaşlık isteği gönderilemedi.'),
        color: AppColors.error,
      );
    }
  }

  Future<void> _acceptIncomingFriendRequest() async {
    if (_myUid.isEmpty || _incomingFriendRequestId.isEmpty) return;

    try {
      await _firestoreService.acceptFriendRequest(
        _incomingFriendRequestId,
        _myUid,
        _targetUid,
      );
      await _loadProfile(silent: true);
      if (!mounted) return;
      _showSnackBar(
        _copy(
          tr: 'Arkadaşlık isteği kabul edildi.',
          en: 'Friend request accepted.',
          de: 'Freundschaftsanfrage akzeptiert.',
        ),
        color: AppColors.success,
      );
    } catch (e, st) {
      debugPrint('Arkadaşlık isteği kabul hatası: $e\n$st');
      if (!mounted) return;
      _showSnackBar(
        _copy(
          tr: 'İstek kabul edilemedi.',
          en: 'Request could not be accepted.',
          de: 'Anfrage konnte nicht angenommen werden.',
        ),
        color: AppColors.error,
      );
    }
  }

  Future<void> _declineIncomingFriendRequest() async {
    if (_incomingFriendRequestId.isEmpty) return;

    try {
      await _firestoreService.declineFriendRequest(_incomingFriendRequestId);
      await _loadProfile(silent: true);
      if (!mounted) return;
      _showSnackBar(
        _copy(
          tr: 'İstek reddedildi.',
          en: 'Request declined.',
          de: 'Anfrage abgelehnt.',
        ),
      );
    } catch (e, st) {
      debugPrint('Arkadaşlık isteği reddetme hatası: $e\n$st');
      if (!mounted) return;
      _showSnackBar(
        _copy(
          tr: 'İstek reddedilemedi.',
          en: 'Request could not be declined.',
          de: 'Anfrage konnte nicht abgelehnt werden.',
        ),
        color: AppColors.error,
      );
    }
  }

  Future<void> _cancelOutgoingFriendRequest() async {
    if (_myUid.isEmpty || _outgoingFriendRequestId.isEmpty) return;

    try {
      final success = await _firestoreService.cancelOutgoingFriendRequest(
        _myUid,
        _outgoingFriendRequestId,
      );
      await _loadProfile(silent: true);
      if (!mounted) return;
      _showSnackBar(
        success
            ? _copy(
                tr: 'Arkadaşlık isteği iptal edildi.',
                en: 'Friend request cancelled.',
                de: 'Freundschaftsanfrage abgebrochen.',
              )
            : _copy(
                tr: 'İstek iptal edilemedi.',
                en: 'Request could not be cancelled.',
                de: 'Anfrage konnte nicht abgebrochen werden.',
              ),
        color: success ? AppColors.success : AppColors.error,
      );
    } catch (e, st) {
      debugPrint('Arkadaşlık isteği iptal hatası: $e\n$st');
      if (!mounted) return;
      _showSnackBar(
        _copy(
          tr: 'İstek iptal edilemedi.',
          en: 'Request could not be cancelled.',
          de: 'Anfrage konnte nicht abgebrochen werden.',
        ),
        color: AppColors.error,
      );
    }
  }

  Future<void> _removeFriend() async {
    if (_myUid.isEmpty || _targetUid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _copy(
            tr: 'Arkadaşlıktan çıkar?',
            en: 'Remove friend?',
            de: 'Freund entfernen?',
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          _copy(
            tr: 'Bu kullanıcı arkadaş listenizden çıkarılacak.',
            en: 'This user will be removed from your friends list.',
            de: 'Dieser Nutzer wird aus deiner Freundesliste entfernt.',
          ),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(_copy(tr: 'Kaldır', en: 'Remove', de: 'Entfernen')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final success = await _firestoreService.removeFriend(_myUid, _targetUid);
      await _loadProfile(silent: true);
      if (!mounted) return;
      _showSnackBar(
        success
            ? _copy(
                tr: 'Arkadaşlıktan çıkarıldı.',
                en: 'Removed from friends.',
                de: 'Aus den Freunden entfernt.',
              )
            : _copy(
                tr: 'Arkadaşlıktan çıkarılamadı.',
                en: 'Friend could not be removed.',
                de: 'Freund konnte nicht entfernt werden.',
              ),
        color: success ? AppColors.success : AppColors.error,
      );
    } catch (e, st) {
      debugPrint('Arkadaş kaldırma hatası: $e\n$st');
      if (!mounted) return;
      _showSnackBar(
        _copy(
          tr: 'Arkadaşlıktan çıkarılamadı.',
          en: 'Friend could not be removed.',
          de: 'Freund konnte nicht entfernt werden.',
        ),
        color: AppColors.error,
      );
    }
  }

  Future<void> _unblockUser() async {
    if (_myUid.isEmpty || _targetUid.isEmpty) return;

    try {
      final success = await _firestoreService.unblockUser(_myUid, _targetUid);
      await _loadProfile(silent: true);
      if (!mounted) return;
      _showSnackBar(
        success
            ? _copy(
                tr: 'Kullanıcının engeli kaldırıldı.',
                en: 'User unblocked.',
                de: 'Nutzer entsperrt.',
              )
            : _copy(
                tr: 'Engel kaldırılamadı.',
                en: 'User could not be unblocked.',
                de: 'Nutzer konnte nicht entsperrt werden.',
              ),
        color: success ? AppColors.success : AppColors.error,
      );
    } catch (e, st) {
      debugPrint('Engel kaldırma hatası: $e\n$st');
      if (!mounted) return;
      _showSnackBar(
        _copy(
          tr: 'Engel kaldırılamadı.',
          en: 'User could not be unblocked.',
          de: 'Nutzer konnte nicht entsperrt werden.',
        ),
        color: AppColors.error,
      );
    }
  }

  void _showSnackBar(String message, {Color color = AppColors.primary}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _describeActionError(
    Object error, {
    required String fallbackTr,
    required String fallbackEn,
    required String fallbackDe,
  }) {
    if (error is ApiException) {
      final message = error.message.trim();
      if (message.isNotEmpty) {
        return message;
      }
    }

    return _copy(tr: fallbackTr, en: fallbackEn, de: fallbackDe);
  }

  String _getModeName(String? mode) {
    return _l10n.modeLabel(ModeConfig.normalizeId(mode));
  }

  Color _getModeColor(String? mode) => ModeConfig.byId(mode).color;

  void _handleShareProfile() {
    unawaited(_shareProfileLive());
  }

  Future<void> _shareProfileLive() async {
    final user = _user;
    if (user == null) return;

    final displayName = user.hasProfile ? user.displayName : user.username;
    final shareText = [
      '$displayName ${_l10n.phrase("profilini PulseCity'de keşfet.")}',
      '@${user.username}',
      if (user.bio.isNotEmpty) user.bio,
      if (user.city.isNotEmpty) '${_l10n.phrase('Şehir')}: ${user.city}',
      '${_l10n.phrase('Profil Kodu')}: ${user.uid}',
    ].join('\n');

    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: '$displayName ${_l10n.phrase('profili')}',
      ),
    );
  }

  Future<void> _showProfileCodeDialog() async {
    final user = _user;
    if (user == null) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _l10n.phrase('Profil Kodu'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Container(
          width: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgMain,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                size: 86,
                color: AppColors.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 12),
              SelectableText(
                user.uid,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _l10n.t('close'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: user.uid));
              if (!mounted) return;
              Navigator.pop(context);
              _showSnackBar(_l10n.phrase('Profil kodu panoya kopyalandı.'));
            },
            child: Text(
              _l10n.phrase('Kopyala'),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMessagesLive() async {
    if (_myUid.isEmpty || _targetUid.isEmpty || _myUid == _targetUid) return;

    try {
      final chat = await _firestoreService.createOrGetDirectChat(
        _myUid,
        _targetUid,
        isTemporary: !_isFriend,
      );
      final otherUser = _user;
      if (!mounted || otherUser == null) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            user: {
              'uid': otherUser.uid,
              'name': otherUser.hasProfile
                  ? otherUser.displayName
                  : otherUser.username,
              'username': '@${otherUser.username}',
              'bio': otherUser.bio,
              'pulse': otherUser.pulseScore,
              'commonInterests': otherUser.interests,
              'anonymous': false,
              'dist': otherUser.city,
              'compatibility': widget.compatibilityScore ?? 0,
              'color': _getModeColor(otherUser.mode),
              'chatId': chat.id,
            },
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Mesaj ekranı açılamadı: $e\n$st');
      _showSnackBar(
        _l10n.phrase('Mesaj ekranı açılamadı.'),
        color: AppColors.error,
      );
    }
  }

  // ignore: unused_element
  Future<void> _openPeopleSearch() async {
    final searchCtrl = TextEditingController();
    List<UserModel> users = [];
    bool loading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> runSearch() async {
            final query = searchCtrl.text.trim();
            if (query.isEmpty) {
              setModalState(() => users = []);
              return;
            }

            setModalState(() => loading = true);
            final result = await _firestoreService.searchUsers(
              query,
              excludeUid: _myUid,
            );
            if (!sheetContext.mounted) return;
            setModalState(() {
              users = result;
              loading = false;
            });
          }

          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
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
                const SizedBox(height: 14),
                Text(
                  _l10n.phrase('Kişi Bul'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgMain,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: searchCtrl,
                    onSubmitted: (_) => runSearch(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _l10n.phrase('Kullanıcı adı veya şehir ara'),
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      suffixIcon: IconButton(
                        onPressed: runSearch,
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : users.isEmpty
                      ? Center(
                          child: Text(
                            _l10n.phrase(
                              'Arama yaparak kullanıcıları bulabilirsin.',
                            ),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (_, index) {
                            final person = users[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                backgroundImage:
                                    person.profilePhotoUrl.isNotEmpty
                                    ? NetworkMediaHeaders.imageProvider(
                                        person.profilePhotoUrl,
                                      )
                                    : null,
                                child: person.profilePhotoUrl.isEmpty
                                    ? const Icon(
                                        Icons.person_rounded,
                                        color: AppColors.primary,
                                      )
                                    : null,
                              ),
                              title: Text(
                                person.hasProfile
                                    ? person.displayName
                                    : person.username,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '@${person.username}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              trailing: FilledButton(
                                onPressed: () async {
                                  await _firestoreService.sendFriendRequest(
                                    _myUid,
                                    person.uid,
                                  );
                                  if (!mounted) return;
                                  _showSnackBar(
                                    '@${person.username} ${_l10n.phrase('için arkadaşlık isteği gönderildi.')}',
                                    color: AppColors.success,
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                child: Text(_l10n.phrase('Arkadaş Ekle')),
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProfileScreen(userId: person.uid),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );

    searchCtrl.dispose();
  }

  static const int _maxProfilePhotos = 6;

  Future<void> _pickAndUploadProfilePhoto() async {
    final user = _user;
    if (user == null || !_isMyProfile) return;

    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _isSavingProfile = true);
    try {
      final url = await _storageService.uploadXFile(
        file: file,
        path:
            'users/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final nextPhotos = [url, ...user.photoUrls.where((item) => item != url)];
      await _firestoreService.updateProfile(user.uid, {
        'profilePhotoUrl': url,
        'photoUrls': nextPhotos,
      });
      if (!mounted) return;
      setState(() => _user = user.copyWith(
            profilePhotoUrl: url,
            photoUrls: nextPhotos,
          ));
      _showSnackBar(
        _l10n.phrase('Profil fotoğrafı güncellendi.'),
        color: AppColors.success,
      );
      unawaited(_loadProfile(silent: true));
    } catch (e, st) {
      debugPrint('Profil fotoğrafı yüklenemedi: $e\n$st');
      _showSnackBar(
        _l10n.phrase('Profil fotoğrafı yüklenemedi.'),
        color: AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _pickAndAppendProfilePhoto() async {
    final user = _user;
    if (user == null || !_isMyProfile) return;
    if (user.photoUrls.length >= _maxProfilePhotos) {
      _showSnackBar(
        _l10n.phrase('En fazla 6 fotoğraf ekleyebilirsin.'),
        color: AppColors.error,
      );
      return;
    }

    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _isSavingProfile = true);
    try {
      final url = await _storageService.uploadXFile(
        file: file,
        path:
            'users/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final nextPhotos = [
        ...user.photoUrls.where((item) => item != url),
        url,
      ];
      final primary = user.profilePhotoUrl.isNotEmpty
          ? user.profilePhotoUrl
          : url;
      await _firestoreService.updateProfile(user.uid, {
        'profilePhotoUrl': primary,
        'photoUrls': nextPhotos,
      });
      if (!mounted) return;
      setState(() => _user = user.copyWith(
            profilePhotoUrl: primary,
            photoUrls: nextPhotos,
          ));
      _showSnackBar(
        _l10n.phrase('Fotoğraf eklendi.'),
        color: AppColors.success,
      );
      unawaited(_loadProfile(silent: true));
    } catch (e, st) {
      debugPrint('Fotoğraf eklenemedi: $e\n$st');
      _showSnackBar(
        _l10n.phrase('Fotoğraf eklenemedi.'),
        color: AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _setAsPrimaryPhoto(String url) async {
    final user = _user;
    if (user == null || !_isMyProfile || url.isEmpty) return;
    if (user.profilePhotoUrl == url) return;

    final reordered = [
      url,
      ...user.photoUrls.where((item) => item != url),
    ];

    setState(() => _isSavingProfile = true);
    try {
      await _firestoreService.updateProfile(user.uid, {
        'profilePhotoUrl': url,
        'photoUrls': reordered,
      });
      if (!mounted) return;
      setState(() => _user = user.copyWith(
            profilePhotoUrl: url,
            photoUrls: reordered,
          ));
      _showSnackBar(
        _l10n.phrase('Ana fotoğraf güncellendi.'),
        color: AppColors.success,
      );
      unawaited(_loadProfile(silent: true));
    } catch (e, st) {
      debugPrint('Ana fotoğraf ayarlanamadı: $e\n$st');
      _showSnackBar(
        _l10n.phrase('Ana fotoğraf ayarlanamadı.'),
        color: AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _removeProfilePhoto(String url) async {
    final user = _user;
    if (user == null || !_isMyProfile || url.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(
          _l10n.phrase('Fotoğrafı sil?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _l10n.phrase('Bu fotoğraf profilinden kaldırılsın mı?'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l10n.phrase('Vazgeç')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _l10n.phrase('Sil'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final nextPhotos = user.photoUrls.where((item) => item != url).toList();
    final nextPrimary = user.profilePhotoUrl == url
        ? (nextPhotos.isNotEmpty ? nextPhotos.first : '')
        : user.profilePhotoUrl;

    setState(() => _isSavingProfile = true);
    try {
      await _firestoreService.updateProfile(user.uid, {
        'profilePhotoUrl': nextPrimary,
        'photoUrls': nextPhotos,
      });
      if (!mounted) return;
      setState(() => _user = user.copyWith(
            profilePhotoUrl: nextPrimary,
            photoUrls: nextPhotos,
          ));
      _showSnackBar(
        _l10n.phrase('Fotoğraf silindi.'),
        color: AppColors.success,
      );
      unawaited(_loadProfile(silent: true));
    } catch (e, st) {
      debugPrint('Fotoğraf silinemedi: $e\n$st');
      _showSnackBar(
        _l10n.phrase('Fotoğraf silinemedi.'),
        color: AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  void _showPhotoActionsSheet(String url, bool isPrimary) {
    if (!_isMyProfile) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPrimary)
              ListTile(
                leading: const Icon(Icons.star_rounded,
                    color: AppColors.primary),
                title: Text(
                  _l10n.phrase('Ana fotoğraf yap'),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setAsPrimaryPhoto(url);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              title: Text(
                _l10n.phrase('Fotoğrafı sil'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _removeProfilePhoto(url);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addHighlightLive() async {
    if (!_isMyProfile || _targetUid.isEmpty) return;

    final draft = await Navigator.of(context).push<StoryStatusDraft>(
      MaterialPageRoute(
        builder: (_) => StoryStatusPickerScreen(
          initialModeId: _user?.mode ?? ModeConfig.defaultId,
          initialCity: _user?.city ?? '',
          publishKind: StoryStatusPublishKind.highlight,
        ),
        fullscreenDialog: true,
      ),
    );
    if (draft == null) return;

    setState(() => _isSavingProfile = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uploadedUrls = <String>[];
      for (var index = 0; index < draft.files.length; index++) {
        final file = draft.files[index];
        final extension = _fileExtension(file.path);
        final url = await _storageService.uploadXFile(
          file: file,
          path: 'users/$_targetUid/highlights/$timestamp-$index.$extension',
        );
        uploadedUrls.add(url);
      }
      if (uploadedUrls.isEmpty) {
        throw Exception('Durum için görsel yüklenemedi.');
      }
      await _firestoreService.addHighlight(
        HighlightModel(
          id: '',
          userId: _targetUid,
          title: draft.title,
          coverUrl: uploadedUrls.first,
          mediaUrls: uploadedUrls,
          type: 'image',
          textColorHex: draft.textColorHex,
          textOffsetX: draft.textOffsetX,
          textOffsetY: draft.textOffsetY,
          modeTag: draft.modeTag,
          locationLabel: draft.locationLabel,
          placeId: draft.placeId,
          showModeOverlay: draft.showModeOverlay,
          showLocationOverlay: draft.showLocationOverlay,
        ),
      );
      if (!mounted) return;
      await _loadProfile(silent: true);
      if (!mounted) return;
      _showSnackBar(
        _l10n.phrase('Highlight eklendi.'),
        color: AppColors.success,
      );
    } catch (e, st) {
      debugPrint('Highlight eklenemedi: $e\n$st');
      _showSnackBar(
        _describeActionError(
          e,
          fallbackTr: 'Highlight eklenemedi.',
          fallbackEn: 'Highlight could not be added.',
          fallbackDe: 'Highlight konnte nicht hinzugefugt werden.',
        ),
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _addStoryLive() async {
    if (!_isMyProfile || _targetUid.isEmpty) return;

    final draft = await Navigator.of(context).push<StoryStatusDraft>(
      MaterialPageRoute(
        builder: (_) => StoryStatusPickerScreen(
          initialModeId: _user?.mode ?? ModeConfig.defaultId,
          initialCity: _user?.city ?? '',
          publishKind: StoryStatusPublishKind.story,
          durationHours: 24,
        ),
        fullscreenDialog: true,
      ),
    );
    if (draft == null) return;

    setState(() => _isSavingProfile = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uploadedUrls = <String>[];
      for (var index = 0; index < draft.files.length; index++) {
        final file = draft.files[index];
        final extension = _fileExtension(file.path);
        final url = await _storageService.uploadXFile(
          file: file,
          path: 'users/$_targetUid/stories/$timestamp-$index.$extension',
        );
        uploadedUrls.add(url);
      }

      if (uploadedUrls.isEmpty) {
        throw Exception('Story media could not be uploaded.');
      }

      await _firestoreService.addStory(
        HighlightModel(
          id: '',
          userId: _targetUid,
          title: draft.title,
          coverUrl: uploadedUrls.first,
          mediaUrls: uploadedUrls,
          type: 'image',
          textColorHex: draft.textColorHex,
          textOffsetX: draft.textOffsetX,
          textOffsetY: draft.textOffsetY,
          modeTag: draft.modeTag,
          locationLabel: draft.locationLabel,
          placeId: draft.placeId,
          showModeOverlay: draft.showModeOverlay,
          showLocationOverlay: draft.showLocationOverlay,
          entryKind: 'story',
        ),
        durationHours: draft.durationHours,
      );
      if (!mounted) return;
      await _loadProfile(silent: true);
      if (!mounted) return;
      _showSnackBar(_l10n.phrase('Durum eklendi.'), color: AppColors.success);
    } catch (e, st) {
      debugPrint('Durum eklenemedi: $e\n$st');
      _showSnackBar(
        _describeActionError(
          e,
          fallbackTr: 'Durum eklenemedi.',
          fallbackEn: 'Story could not be added.',
          fallbackDe: 'Story konnte nicht hinzugefugt werden.',
        ),
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _deleteHighlightLive(HighlightModel highlight) async {
    if (!_isMyProfile || _targetUid.isEmpty || highlight.id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(
          _l10n.phrase('Öne çıkanı sil'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _l10n.phrase('Bu öne çıkan kalıcı olarak kaldırılacak.'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              _l10n.phrase('Vazgeç'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Sil',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.deleteHighlight(_targetUid, highlight.id);
      if (!mounted) return;
      _showSnackBar(
        _l10n.phrase('Öne çıkan silindi.'),
        color: AppColors.success,
      );
    } catch (e, st) {
      debugPrint('Highlight silinemedi: $e\n$st');
      if (!mounted) return;
      _showSnackBar(
        _l10n.phrase('Öne çıkan silinemedi.'),
        color: AppColors.error,
      );
    }
  }

  String _fileExtension(String path) {
    final sanitized = path.split('?').first;
    final dotIndex = sanitized.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == sanitized.length - 1) {
      return 'jpg';
    }
    return sanitized.substring(dotIndex + 1).toLowerCase();
  }

  Future<void> _createPostLive({required String type}) async {
    if (!_isMyProfile || _targetUid.isEmpty) return;

    final user = _user;
    if (user == null) return;
    final didCreate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          kind: type == 'short' ? CreatePostKind.short : CreatePostKind.post,
          currentUser: user,
        ),
        fullscreenDialog: true,
      ),
    );
    if (didCreate != true || !mounted) return;
    _showSnackBar(
      type == 'short'
          ? _l10n.phrase('Short yayında.')
          : _l10n.phrase('Gönderi feede eklendi.'),
      color: AppColors.success,
    );
  }

  Future<void> _editPostLive(PostModel post) async {
    if (!_isMyProfile || _targetUid.isEmpty) return;

    final user = _user;
    if (user == null) return;
    final didUpdate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          kind: post.type == 'short'
              ? CreatePostKind.short
              : CreatePostKind.post,
          currentUser: user,
          initialPost: post,
        ),
        fullscreenDialog: true,
      ),
    );
    if (didUpdate != true || !mounted) return;
    _showSnackBar(
      post.type == 'short'
          ? _l10n.phrase('Short güncellendi.')
          : _l10n.phrase('Gönderi güncellendi.'),
      color: AppColors.success,
    );
  }

  Future<void> _focusPostPlace(PostModel post) async {
    if (post.placeId.isEmpty && post.location.trim().isEmpty) return;
    await PlaceFocusService.instance.focusPlace(
      placeId: post.placeId,
      placeName: post.location,
      latitude: post.lat,
      longitude: post.lng,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleReportUser() async {
    Navigator.pop(context);
    if (_myUid.isEmpty || _targetUid.isEmpty || _myUid == _targetUid) return;

    final detailsCtrl = TextEditingController();
    String reason = 'Rahatsız edici davranış';

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _l10n.phrase('Kullanıcıyı Şikayet Et'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                dropdownColor: AppColors.bgSurface,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bgMain,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Rahatsız edici davranış',
                    child: Text(_l10n.phrase('Rahatsız edici davranış')),
                  ),
                  DropdownMenuItem(
                    value: 'Sahte profil',
                    child: Text(_l10n.phrase('Sahte profil')),
                  ),
                  DropdownMenuItem(
                    value: 'İstenmeyen içerik',
                    child: Text(_l10n.phrase('İstenmeyen içerik')),
                  ),
                  DropdownMenuItem(
                    value: 'Güvenlik endişesi',
                    child: Text(_l10n.phrase('Güvenlik endişesi')),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => reason = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _l10n.phrase('Kısa bir not ekleyebilirsin'),
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  filled: true,
                  fillColor: AppColors.bgMain,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              _l10n.phrase('Vazgeç'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: Text(_l10n.phrase('Gönder')),
          ),
        ],
      ),
    );

    if (submitted != true) {
      detailsCtrl.dispose();
      return;
    }

    try {
      await _firestoreService.createUserReport(
        reporterUid: _myUid,
        targetUid: _targetUid,
        reason: reason,
        details: detailsCtrl.text,
      );
      if (!mounted) return;
      _showSnackBar(
        _l10n.phrase('Şikayet kaydı oluşturuldu.'),
        color: AppColors.success,
      );
    } catch (e, st) {
      debugPrint('Sikayet gonderilemedi: $e\n$st');
      _showSnackBar(
        _l10n.phrase('Şikayet gönderilemedi.'),
        color: AppColors.error,
      );
    } finally {
      detailsCtrl.dispose();
    }
  }

  Future<void> _confirmDeletePost(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _l10n.phrase('Gönderiyi sil'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          _l10n.phrase(
            'Bu gönderi kalıcı olarak silinecek. Devam etmek istiyor musun?',
          ),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _l10n.phrase('Vazgeç'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sil',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await _firestoreService.deletePost(post.id, _myUid);
    if (!mounted) return;

    if (success) {
      AppSnackbar.showSuccess(context, _l10n.phrase('Gönderi silindi.'));
      await _loadProfile(silent: true);
    } else {
      AppSnackbar.showError(context, _l10n.phrase('Gönderi silinemedi.'));
    }
  }

  /// Açar: 2-eksen immersive viewer (foto/story/highlight/shorts arası dikey,
  /// kategori içinde yatay). [categoryId]: 'photos' | 'stories' | 'highlights'
  /// | 'shorts'. Kategori bulunamazsa sessizce iptal eder.
  Future<void> _openImmersiveViewer({
    required String categoryId,
    int itemIndex = 0,
  }) async {
    final user = _user;
    if (user == null) return;

    final categories = <ImmersiveMediaCategory>[];

    // Photos — user.photoUrls sırasıyla; profilePhotoUrl ayrı tutulmuyor
    // çünkü zaten Hero gösterir.
    if (user.photoUrls.isNotEmpty) {
      categories.add(ImmersiveMediaCategory(
        id: 'photos',
        label: _l10n.phrase('Fotoğraflar'),
        items: [
          for (var i = 0; i < user.photoUrls.length; i++)
            ImmersiveMediaItem(
              id: 'photo-$i',
              kind: ImmersiveMediaKind.photo,
              mediaUrl: user.photoUrls[i],
            ),
        ],
      ));
    }

    // Stories (aktif) + Highlights (kalıcı) ayrı kategoriler.
    final storyItems = <ImmersiveMediaItem>[];
    final highlightItems = <ImmersiveMediaItem>[];
    for (final h in _cachedHighlights) {
      final bucket = h.isStory ? storyItems : highlightItems;
      final media = h.storyMedia;
      for (var i = 0; i < media.length; i++) {
        final url = media[i];
        if (url.isEmpty) continue;
        final isVideo = h.type == 'video';
        bucket.add(ImmersiveMediaItem(
          id: '${h.id}-$i',
          kind: isVideo
              ? ImmersiveMediaKind.storyVideo
              : ImmersiveMediaKind.storyImage,
          mediaUrl: url,
          thumbnailUrl: h.coverUrl.isEmpty ? null : h.coverUrl,
          caption: h.title.trim().isEmpty ? null : h.title,
          locationLabel:
              h.locationLabel.trim().isEmpty ? null : h.locationLabel,
          placeId: h.placeId.trim().isEmpty ? null : h.placeId,
          modeTag: h.modeTag.trim().isEmpty ? null : h.modeTag,
          highlight: h,
        ));
      }
    }
    if (storyItems.isNotEmpty) {
      categories.add(ImmersiveMediaCategory(
        id: 'stories',
        label: _l10n.phrase('Storyler'),
        items: storyItems,
      ));
    }
    if (highlightItems.isNotEmpty) {
      categories.add(ImmersiveMediaCategory(
        id: 'highlights',
        label: _l10n.phrase('Öne çıkanlar'),
        items: highlightItems,
      ));
    }

    // Shorts — videoUrl boş olanlar atlanır.
    if (_cachedShorts.isNotEmpty) {
      final shortItems = <ImmersiveMediaItem>[];
      for (final p in _cachedShorts) {
        final url = p.videoUrl ?? '';
        if (url.isEmpty) continue;
        shortItems.add(ImmersiveMediaItem(
          id: 'short-${p.id}',
          kind: ImmersiveMediaKind.shortVideo,
          mediaUrl: url,
          thumbnailUrl:
              p.photoUrls.isNotEmpty ? p.photoUrls.first : null,
          caption: p.text.trim().isEmpty ? null : p.text,
          locationLabel: p.location.trim().isEmpty ? null : p.location,
          placeId: p.placeId.trim().isEmpty ? null : p.placeId,
          modeTag: p.userMode.trim().isEmpty ? null : p.userMode,
          post: p,
        ));
      }
      if (shortItems.isNotEmpty) {
        categories.add(ImmersiveMediaCategory(
          id: 'shorts',
          label: _l10n.phrase('Shorts'),
          items: shortItems,
        ));
      }
    }

    if (categories.isEmpty) return;

    final categoryIndex = categories.indexWhere((c) => c.id == categoryId);
    if (categoryIndex == -1) return;

    final safeItemIndex = itemIndex.clamp(
      0,
      categories[categoryIndex].items.length - 1,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImmersiveProfileViewerScreen(
          categories: categories,
          initialCategoryIndex: categoryIndex,
          initialItemIndex: safeItemIndex,
          accentColor: _getModeColor(user.mode),
          ownerDisplayName: user.hasProfile ? user.displayName : user.username,
          ownerProfilePhotoUrl: user.profilePhotoUrl,
          isOwnProfile: _isMyProfile,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _openProfileShorts(
    List<PostModel> shorts,
    int initialIndex,
  ) async {
    if (shorts.isEmpty) return;
    final user = _user;
    final title = user == null
        ? _l10n.t('shorts')
        : '${user.hasProfile ? user.displayName : user.username} • ${_l10n.t('shorts')}';
    final subtitle = _isMyProfile
        ? _l10n.phrase('Kendi kısa video akışın')
        : _l10n.phrase('Bu kullanıcının kısa video akışı');

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShortsScreen(
          scope: ShortsFeedScope.personal,
          initialPosts: shorts,
          initialIndex: initialIndex,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD ROOT
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScaffold();
    }

    final user = _user;
    if (user == null) {
      return _buildMissingUserScaffold();
    }

    final modeColor = _getModeColor(user.mode);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Ana kaydırılabilir içerik
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.bgCard,
            onRefresh: () => _loadProfile(silent: true),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildHero(user, modeColor)),
                SliverToBoxAdapter(child: _buildSignalCrossingCard()),
                SliverToBoxAdapter(child: _buildActionRow(user)),
                SliverToBoxAdapter(child: _buildStatsCard(user)),
                SliverToBoxAdapter(
                  child: BadgesProfileRail(
                    userId: _targetUid,
                    isOwnProfile: _isMyProfile,
                  ),
                ),
                SliverToBoxAdapter(child: _buildVibesSection(user)),
                SliverToBoxAdapter(child: _buildPinnedMomentPlaceholder()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ActivityProfileRail(
                      hostUserId: _targetUid,
                      isOwnProfile: _isMyProfile,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildPhotosRail(user)),
                SliverToBoxAdapter(child: _buildStoriesRail()),
                SliverToBoxAdapter(child: _buildShortsRail()),
                SliverToBoxAdapter(child: _buildPlacesPlaceholder()),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),

          // Üst overlay: back + more + sticky mini-nav
          _buildTopOverlay(user, modeColor),

          // Kaydetme overlay'i
          if (_isSavingProfile)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.18),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _l10n.phrase('Profil kaydediliyor...'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildMissingUserScaffold() {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Text(
          _l10n.phrase('Kullanıcı bulunamadı'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  // ==========================================================================
  // HERO + ÜSTTE KALAN ÖĞELER
  // ==========================================================================
  Widget _buildHero(UserModel user, Color modeColor) {
    final displayName = user.hasProfile ? user.displayName : user.username;
    final heroImage = user.photoUrls.isNotEmpty
        ? user.photoUrls.first
        : user.profilePhotoUrl;

    final hasCompat = !_isMyProfile && widget.compatibilityScore != null;

    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Arkaplan fotoğrafı
          _buildHeroBackground(heroImage, user, modeColor),

          // Alt-üst gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.bgMain.withValues(alpha: 0.98),
                  ],
                  stops: const [0.0, 0.28, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Uyum rozeti (sol üst) — yalnızca başkasının profilinde ve skor varsa
          if (hasCompat)
            Positioned(
              top: MediaQuery.of(context).padding.top + 58,
              left: 20,
              child: _buildCompatBadge(widget.compatibilityScore!),
            ),

          // Signal göstergesi (sağ üst)
          Positioned(
            top: MediaQuery.of(context).padding.top + 58,
            right: 20,
            child: _buildSignalIndicator(user),
          ),

          // İsim, yaş, mod, şehir, bio (alt kısım)
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: _buildHeroContent(user, modeColor, displayName),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBackground(String imageUrl, UserModel user, Color modeColor) {
    if (imageUrl.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              modeColor.withValues(alpha: 0.28),
              AppColors.bgMain,
              AppColors.bgCard,
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.person_rounded,
          color: modeColor.withValues(alpha: 0.45),
          size: 120,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // Kendi profilim: foto yoksa yükle, varsa immersive viewer.
        if (_isMyProfile && user.photoUrls.isEmpty) {
          _pickAndUploadProfilePhoto();
          return;
        }
        if (user.photoUrls.isNotEmpty) {
          _openImmersiveViewer(categoryId: 'photos', itemIndex: 0);
        }
      },
      onLongPress: _isMyProfile ? _pickAndUploadProfilePhoto : null,
      child: Image.network(
        imageUrl,
        headers: NetworkMediaHeaders.forUrl(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppColors.bgCard,
          alignment: Alignment.center,
          child: Icon(
            Icons.person_rounded,
            color: Colors.white.withValues(alpha: 0.2),
            size: 90,
          ),
        ),
      ),
    );
  }

  Widget _buildCompatBadge(int score) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryGlow],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$score',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _l10n.phrase('Uyum'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalIndicator(UserModel user) {
    final online = user.isOnline;
    final color = online ? AppColors.success : Colors.white.withValues(alpha: 0.6);
    final bg = online
        ? AppColors.success.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.35);
    final borderColor = online
        ? AppColors.success.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.14);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: online
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.8),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online
                ? _l10n.phrase('SIGNAL AKTİF')
                : _l10n.phrase('ÇEVRİMDIŞI'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroContent(
    UserModel user,
    Color modeColor,
    String displayName,
  ) {
    final age = user.age;
    final cityText = user.city.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                displayName.isEmpty ? user.username : displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
            ),
            if (age > 0) ...[
              Text(
                ', $age',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (user.isPhotoVerified) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.neonCyan],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonCyan.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            GestureDetector(
              onTap: _isMyProfile ? _showModePickerSheet : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: modeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: modeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _getModeName(user.mode),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: modeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (cityText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '·',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  cityText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (user.bio.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            user.bio,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ] else if (_isMyProfile) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showEditProfileSheet,
            child: Text(
              _l10n.phrase('+ Bio ekle'),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================================================
  // SIGNAL CROSSING (placeholder - backend desteği gelecek)
  // ==========================================================================
  Widget _buildSignalCrossingCard() {
    if (_isMyProfile) return const SizedBox.shrink();

    final summary = _signalCrossings;
    final hasAny = summary.hasAny;
    final lastLabel = summary.lastCrossedAt == null
        ? null
        : _formatRelativeTime(summary.lastCrossedAt!);

    final mainLine = hasAny
        ? '${summary.totalCount} ${_l10n.phrase('kez yolunuz kesişti')}'
        : _l10n.phrase('Signal kesişimleri');

    final subLine = hasAny
        ? (lastLabel == null
            ? _l10n.phrase('Son buluşma — tarih bilinmiyor')
            : '${_l10n.phrase('Son buluşma')} · $lastLabel')
        : _l10n.phrase('Henüz kesişen bir sinyal yok');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primaryGlow.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryGlow],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.sensors_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainLine,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLine,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                  if (hasAny && summary.recent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: summary.recent.take(3).map((crossing) {
                        final label = crossing.locationLabel.trim().isEmpty
                            ? _l10n.phrase('Bilinmeyen konum')
                            : crossing.locationLabel;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "N dakika/saat/gün önce" için küçük bir formatlayıcı. İngilizce/Almanca
  /// metinler l10n üzerinden uygun karşılıklarına düşer.
  String _formatRelativeTime(DateTime when) {
    final now = DateTime.now().toUtc();
    final delta = now.difference(when.toUtc());

    if (delta.inSeconds < 60) {
      return _l10n.phrase('şimdi');
    }
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes} ${_l10n.phrase('dk önce')}';
    }
    if (delta.inHours < 24) {
      return '${delta.inHours} ${_l10n.phrase('saat önce')}';
    }
    if (delta.inDays < 7) {
      return '${delta.inDays} ${_l10n.phrase('gün önce')}';
    }
    if (delta.inDays < 30) {
      return '${(delta.inDays / 7).floor()} ${_l10n.phrase('hafta önce')}';
    }
    if (delta.inDays < 365) {
      return '${(delta.inDays / 30).floor()} ${_l10n.phrase('ay önce')}';
    }
    return '${(delta.inDays / 365).floor()} ${_l10n.phrase('yıl önce')}';
  }

  // ==========================================================================
  // ACTION ROW
  // ==========================================================================
  Widget _buildActionRow(UserModel user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: _isMyProfile
            ? [
                Expanded(
                  child: _buildPrimaryActionButton(
                    label: _l10n.phrase('Profili Düzenle'),
                    icon: Icons.edit_rounded,
                    onTap: _showEditProfileSheet,
                  ),
                ),
                const SizedBox(width: 8),
                _buildGhostActionButton(
                  icon: Icons.add_a_photo_rounded,
                  onTap: _addStoryLive,
                  tooltip: _l10n.phrase('Story paylaş'),
                ),
                const SizedBox(width: 8),
                _buildGhostActionButton(
                  icon: Icons.share_rounded,
                  onTap: _shareProfileLive,
                  tooltip: _l10n.phrase('Profili Paylaş'),
                ),
              ]
            : _buildOtherProfileActions(user),
      ),
    );
  }

  List<Widget> _buildOtherProfileActions(UserModel user) {
    // Gelen istek varsa: Kabul Et + Reddet + More
    if (_hasPendingIncomingFriendRequest) {
      return [
        Expanded(
          child: _buildPrimaryActionButton(
            label: _copy(tr: 'Kabul Et', en: 'Accept', de: 'Akzeptieren'),
            icon: Icons.check_rounded,
            onTap: _acceptIncomingFriendRequest,
          ),
        ),
        const SizedBox(width: 8),
        _buildGhostActionButton(
          icon: Icons.close_rounded,
          onTap: _declineIncomingFriendRequest,
          tooltip: _copy(tr: 'Reddet', en: 'Decline', de: 'Ablehnen'),
        ),
        const SizedBox(width: 8),
        _buildGhostActionButton(
          icon: Icons.more_horiz_rounded,
          onTap: _showUserOptionsSheet,
        ),
      ];
    }

    // Engellendiysem: Şikayet Et + More
    if (_hasBlockedMe) {
      return [
        Expanded(
          child: _buildPrimaryActionButton(
            label: _copy(tr: 'Erişim Kısıtlı', en: 'Restricted', de: 'Eingeschränkt'),
            icon: Icons.block_rounded,
            onTap: () {},
            disabled: true,
          ),
        ),
        const SizedBox(width: 8),
        _buildGhostActionButton(
          icon: Icons.flag_rounded,
          onTap: _showUserOptionsSheet,
          tooltip: _copy(tr: 'Şikayet', en: 'Report', de: 'Melden'),
        ),
        const SizedBox(width: 8),
        _buildGhostActionButton(
          icon: Icons.more_horiz_rounded,
          onTap: _showUserOptionsSheet,
        ),
      ];
    }

    // Ben engellediysem: Engeli Kaldır + More
    if (_isBlockedByMe) {
      return [
        Expanded(
          child: _buildPrimaryActionButton(
            label: _copy(tr: 'Engeli Kaldır', en: 'Unblock', de: 'Entsperren'),
            icon: Icons.lock_open_rounded,
            onTap: _unblockUser,
          ),
        ),
        const SizedBox(width: 8),
        _buildGhostActionButton(
          icon: Icons.more_horiz_rounded,
          onTap: _showUserOptionsSheet,
        ),
      ];
    }

    // Giden istek varsa: İsteği İptal Et + Mesaj + More
    if (_hasPendingOutgoingFriendRequest) {
      return [
        Expanded(
          child: _buildPrimaryActionButton(
            label: _copy(
              tr: 'İsteği İptal Et',
              en: 'Cancel Request',
              de: 'Anfrage abbrechen',
            ),
            icon: Icons.undo_rounded,
            onTap: _cancelOutgoingFriendRequest,
            secondary: true,
          ),
        ),
        const SizedBox(width: 8),
        _buildGhostActionButton(
          icon: Icons.chat_bubble_rounded,
          onTap: _openMessagesLive,
          tooltip: _l10n.phrase('Mesaj'),
        ),
        const SizedBox(width: 8),
        _buildGhostActionButton(
          icon: Icons.more_horiz_rounded,
          onTap: _showUserOptionsSheet,
        ),
      ];
    }

    // Varsayılan: Eşleş/Takip + Mesaj + More
    final primaryLabel = _isFollowing
        ? _l10n.phrase('Takipten Çık')
        : (_isFriend ? _l10n.phrase('Eşleş') : _l10n.phrase('Takip Et'));
    final primaryIcon = _isFollowing
        ? Icons.person_remove_rounded
        : (_isFriend ? Icons.favorite_rounded : Icons.person_add_rounded);

    return [
      Expanded(
        child: _buildPrimaryActionButton(
          label: primaryLabel,
          icon: primaryIcon,
          onTap: _isFriend && !_isFollowing ? _sendFriendRequest : _toggleFollow,
          secondary: _isFollowing,
        ),
      ),
      const SizedBox(width: 8),
      _buildGhostActionButton(
        icon: Icons.chat_bubble_rounded,
        onTap: _openMessagesLive,
        tooltip: _l10n.phrase('Mesaj'),
      ),
      const SizedBox(width: 8),
      _buildGhostActionButton(
        icon: Icons.more_horiz_rounded,
        onTap: _showUserOptionsSheet,
      ),
    ];
  }

  Widget _buildPrimaryActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool secondary = false,
    bool disabled = false,
  }) {
    if (secondary || disabled) {
      return SizedBox(
        height: 44,
        child: Material(
          color: Colors.white.withValues(alpha: disabled ? 0.04 : 0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: Colors.white.withValues(alpha: disabled ? 0.4 : 0.92),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: disabled ? 0.4 : 0.92),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: Material(
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryGlow],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                offset: const Offset(0, 4),
                blurRadius: 18,
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGhostActionButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  // ==========================================================================
  // STATS CARD
  // ==========================================================================
  Widget _buildStatsCard(UserModel user) {
    final hasRating = user.activityRatingCount > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStat(
                value: '${user.pulseScore}',
                label: _l10n.phrase('PULS'),
                accent: AppColors.primaryGlow,
              ),
            ),
            _buildStatDivider(),
            Expanded(
              child: _buildStat(
                value: '${user.friendsCount}',
                label: _l10n.phrase('EŞLEŞME'),
                onTap: () async {
                  await _loadFriends();
                  if (!mounted) return;
                  _showPeopleSheet(_l10n.phrase('Arkadaşlar'), 'friends');
                },
              ),
            ),
            _buildStatDivider(),
            Expanded(
              child: _buildStat(
                value: '${user.placesVisited}',
                label: _l10n.phrase('MEKAN'),
              ),
            ),
            if (hasRating) ...[
              _buildStatDivider(),
              Expanded(
                child: _buildRatingStat(user),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingStat(UserModel user) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.star_rounded,
              color: AppColors.warning,
              size: 16,
            ),
            const SizedBox(width: 2),
            Text(
              user.activityRatingAverage.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.warning,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'PUAN · ${user.activityRatingCount}',
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.white.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildStat({
    required String value,
    required String label,
    Color? accent,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent ?? Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  // ==========================================================================
  // SECTION HEADERS (ortak)
  // ==========================================================================
  Widget _buildSectionHead({
    required String title,
    String? meta,
    String? moreLabel,
    VoidCallback? onMore,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (meta != null && meta.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      meta,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (moreLabel != null && onMore != null)
            InkWell(
              onTap: onMore,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      moreLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ],
                ),
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing,
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // VIBE CHIPS
  // ==========================================================================
  Widget _buildVibesSection(UserModel user) {
    final interests = user.interests;
    if (interests.isEmpty && !_isMyProfile) {
      return const SizedBox.shrink();
    }

    final myInterests = _myUser?.interests ?? const <String>[];
    final shared = myInterests.isEmpty
        ? const <String>{}
        : interests.where((item) => myInterests.contains(item)).toSet();

    final metaText = !_isMyProfile && shared.isNotEmpty
        ? '${shared.length} ${_l10n.phrase('ortak')}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHead(
          title: _l10n.phrase('Vibe'),
          meta: metaText.isEmpty ? null : metaText,
          moreLabel: _isMyProfile ? _l10n.phrase('Düzenle') : null,
          onMore: _isMyProfile ? _showInterestsEditorSheet : null,
        ),
        if (interests.isEmpty && _isMyProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: GestureDetector(
              onTap: _showInterestsEditorSheet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_rounded,
                      color: AppColors.primary.withValues(alpha: 0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _l10n.phrase(
                          'Profilini şehirde daha görünür yapacak ilgi alanlarını ekle.',
                        ),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: interests.map((tag) {
                final isShared = shared.contains(tag);
                return _buildVibeChip(tag, isShared);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildVibeChip(String tag, bool shared) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: shared
            ? LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.22),
                  AppColors.primaryGlow.withValues(alpha: 0.15),
                ],
              )
            : null,
        color: shared ? null : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: shared
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shared) ...[
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            _interestLabel(tag),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: shared
                  ? const Color(0xFFFFC3D4)
                  : Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PINNED MOMENT (backend: PUT /api/users/me/pinned-moment)
  // ==========================================================================
  Widget _buildPinnedMomentPlaceholder() {
    final user = _user;
    if (user == null) return const SizedBox.shrink();

    final hasPin = user.pinnedPostId != null && user.pinnedPostId!.isNotEmpty;

    // Başka kullanıcıda pin yoksa hiç section gösterme — yerleşim gereksizce
    // şişmesin.
    if (!hasPin && !_isMyProfile) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHead(
          title: _l10n.phrase('Öne çıkan an'),
          meta: hasPin
              ? (user.pinnedAt == null
                  ? null
                  : _formatRelativeTime(user.pinnedAt!))
              : (_isMyProfile ? _l10n.phrase('sabitle') : null),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: hasPin
              ? _buildPinnedMomentContent(user)
              : _buildPinnedMomentEmpty(),
        ),
      ],
    );
  }

  Widget _buildPinnedMomentContent(UserModel user) {
    final post = _pinnedPost;
    final videoUrl = post?.videoUrl ?? '';
    final coverUrl = () {
      if (post != null && post.photoUrls.isNotEmpty) return post.photoUrls.first;
      if (videoUrl.isNotEmpty) return videoUrl;
      if (user.photoUrls.isNotEmpty) return user.photoUrls.first;
      return '';
    }();
    final label = () {
      if (post != null && post.text.trim().isNotEmpty) return post.text;
      if (post != null && post.location.trim().isNotEmpty) return post.location;
      if (user.city.trim().isNotEmpty) return user.city;
      return _l10n.phrase('Öne çıkan an');
    }();

    return GestureDetector(
      onLongPress: _isMyProfile ? _confirmUnpinMoment : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl.isEmpty)
                Container(
                  color: AppColors.bgCard,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.push_pin_rounded,
                    color: Colors.white.withValues(alpha: 0.2),
                    size: 40,
                  ),
                )
              else
                Image.network(
                  coverUrl,
                  headers: NetworkMediaHeaders.forUrl(coverUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.bgCard,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_rounded,
                      color: Colors.white.withValues(alpha: 0.15),
                      size: 40,
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    const Icon(
                      Icons.push_pin_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_isMyProfile) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _confirmUnpinMoment,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            _l10n.phrase('Kaldır'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedMomentEmpty() {
    return GestureDetector(
      onTap: _isPinningMoment ? null : _showPinMomentPicker,
      child: Container(
        height: 120,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.push_pin_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _l10n.phrase('Bir an sabitle'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _l10n.phrase('Profilinin en üstünde öne çıkar — bir post seç, kısayol olarak görünsün.'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            _isPinningMoment
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPinMomentPicker() async {
    if (_isPinningMoment) return;
    final posts = await _firestoreService.fetchUserPostsOnce(_myUid);
    if (!mounted) return;

    if (posts.isEmpty) {
      _showSnackBar(
        _l10n.phrase('Henüz sabitlenecek bir post yok.'),
      );
      return;
    }

    final selected = await showModalBottomSheet<PostModel>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.push_pin_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _l10n.phrase('Bir an seç'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (gridCtx, index) {
                      final post = posts[index];
                      final cover = post.photoUrls.isNotEmpty
                          ? post.photoUrls.first
                          : (post.videoUrl ?? '');
                      return GestureDetector(
                        onTap: () => Navigator.of(gridCtx).pop(post),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: cover.isEmpty
                              ? Container(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.image_rounded,
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                )
                              : Image.network(
                                  cover,
                                  headers: NetworkMediaHeaders.forUrl(cover),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color:
                                        Colors.white.withValues(alpha: 0.04),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.broken_image_rounded,
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    await _applyPinnedMoment(selected.id);
  }

  Future<void> _confirmUnpinMoment() async {
    if (_isPinningMoment) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(
          _l10n.phrase('Sabiti kaldır?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _l10n.phrase('Bu anı öne çıkarmayı durdur. İstediğinde tekrar sabitleyebilirsin.'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(_l10n.phrase('Vazgeç')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              _l10n.phrase('Kaldır'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _applyPinnedMoment(null);
    }
  }

  Future<void> _applyPinnedMoment(String? postId) async {
    setState(() => _isPinningMoment = true);
    try {
      final updated = await _firestoreService.setPinnedMoment(postId);
      if (!mounted) return;
      setState(() {
        _user = updated ?? _user;
        _pinnedPost = null; // yeniden çözülecek
        _isPinningMoment = false;
      });
      if (updated != null &&
          updated.pinnedPostId != null &&
          updated.pinnedPostId!.isNotEmpty) {
        final post = await _resolvePinnedPost(updated.pinnedPostId!);
        if (!mounted) return;
        setState(() => _pinnedPost = post);
      }
      _showSnackBar(
        postId == null
            ? _l10n.phrase('Sabit kaldırıldı.')
            : _l10n.phrase('An sabitlendi.'),
      );
    } catch (e, st) {
      debugPrint('Pinned moment hatası: $e\n$st');
      if (!mounted) return;
      setState(() => _isPinningMoment = false);
      _showSnackBar(
        _l10n.phrase('Sabit güncellenemedi.'),
        color: AppColors.error,
      );
    }
  }

  // ==========================================================================
  // PHOTOS RAIL
  // ==========================================================================
  Widget _buildPhotosRail(UserModel user) {
    final photos = user.photoUrls;
    if (photos.isEmpty && !_isMyProfile) {
      return const SizedBox.shrink();
    }

    // Kendi profilinde + tile her zaman index 0'da; başkasının profilinde
    // sadece foto thumbnail'ları render edilir.
    final itemCount = photos.length + (_isMyProfile ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHead(
          title: _l10n.phrase('Fotoğraflar'),
          meta: photos.isEmpty ? null : '${photos.length}',
          moreLabel: _isMyProfile ? _l10n.phrase('Düzenle') : null,
          onMore: _isMyProfile ? _showEditProfileSheet : null,
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              if (_isMyProfile && index == 0) {
                return _buildAddPhotoTile();
              }
              final photoIndex = _isMyProfile ? index - 1 : index;
              return _buildPhotoTile(photos[photoIndex], user, photoIndex);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoTile(String url, UserModel user, int index) {
    final isPrimary = user.profilePhotoUrl == url;
    return GestureDetector(
      onTap: () => _openImmersiveViewer(
        categoryId: 'photos',
        itemIndex: index,
      ),
      onLongPress:
          _isMyProfile ? () => _showPhotoActionsSheet(url, isPrimary) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 130,
          height: 170,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                headers: NetworkMediaHeaders.forUrl(url),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.bgCard,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white.withValues(alpha: 0.2),
                    size: 24,
                  ),
                ),
              ),
              if (isPrimary)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          _l10n.phrase('Ana'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isMyProfile)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _showPhotoActionsSheet(url, isPrimary),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPhotoTile() {
    final hasExisting = (_user?.photoUrls.isNotEmpty ?? false);
    return GestureDetector(
      onTap: hasExisting
          ? _pickAndAppendProfilePhoto
          : _pickAndUploadProfilePhoto,
      child: Container(
        width: 130,
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_rounded,
              color: AppColors.primary.withValues(alpha: 0.8),
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              _l10n.phrase('Foto ekle'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // STORIES RAIL (HighlightModel – aktif storyler)
  // ==========================================================================
  Widget _buildStoriesRail() {
    return StreamBuilder<List<HighlightModel>>(
      stream: _firestoreService.getHighlights(_targetUid),
      builder: (context, snapshot) {
        final highlights = snapshot.data ?? const <HighlightModel>[];
        _cachedHighlights = highlights;
        if (highlights.isEmpty && !_isMyProfile) {
          return const SizedBox.shrink();
        }

        final activeCount = highlights.where((h) => h.isActiveStory).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHead(
              title: _l10n.phrase('Storyler & Öne çıkanlar'),
              meta: highlights.isEmpty
                  ? null
                  : '${highlights.length}${activeCount > 0 ? ' · $activeCount ${_l10n.phrase('aktif')}' : ''}',
              // Story ekleme rail'in başındaki "+" tile ile yapılır.
              // Highlight (kalıcı koleksiyon) konsepti farklı, section
              // head'deki bookmark ikonu ayrı bir composer açar.
              trailing: _isMyProfile
                  ? _buildHighlightComposerIcon()
                  : null,
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount:
                    highlights.length + (_isMyProfile && highlights.isEmpty ? 1 : 0) + (_isMyProfile ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  if (_isMyProfile && index == 0) {
                    return _buildAddStoryTile();
                  }
                  final actualIndex = _isMyProfile ? index - 1 : index;
                  if (actualIndex >= highlights.length) {
                    return const SizedBox.shrink();
                  }
                  return _buildStoryTile(highlights[actualIndex]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Stories section head'inde duran küçük "Highlight oluştur" ikonu.
  /// Story (24h, geçici) ile Highlight (kalıcı koleksiyon) ayrı konsept;
  /// + tile story için, bu ikon highlight için.
  Widget _buildHighlightComposerIcon() {
    return InkWell(
      onTap: _addHighlightLive,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.modeUretkenlik.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.modeUretkenlik.withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.collections_bookmark_rounded,
          color: AppColors.modeUretkenlik,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildAddStoryTile() {
    return GestureDetector(
      onTap: _addStoryLive,
      child: Container(
        width: 108,
        height: 172,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.18),
              AppColors.bgSurface,
            ],
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: AppColors.primary,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              _l10n.phrase('Yeni'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryTile(HighlightModel highlight) {
    final isActive = highlight.isActiveStory;
    final imageUrl = highlight.coverUrl;
    final title = highlight.title.trim().isNotEmpty
        ? highlight.title
        : highlight.locationLabel.trim().isNotEmpty
            ? highlight.locationLabel
            : _l10n.t('profile_highlights_title');

    return GestureDetector(
      onTap: () {
        // Immersive viewer: dokunulan highlight'ın ilk medyasına denk
        // gelen düzleşmiş item index'ini hesapla.
        final bucketId = highlight.isStory ? 'stories' : 'highlights';
        var itemIndex = 0;
        for (final h in _cachedHighlights) {
          if (h.id == highlight.id) break;
          if (h.isStory == highlight.isStory) {
            itemIndex += h.storyMedia.where((u) => u.isNotEmpty).length;
          }
        }
        _openImmersiveViewer(categoryId: bucketId, itemIndex: itemIndex);
      },
      onLongPress: _isMyProfile ? () => _deleteHighlightLive(highlight) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 108,
          height: 172,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.08),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  headers: NetworkMediaHeaders.forUrl(imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.bgCard,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_rounded,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                )
              else
                Container(
                  color: AppColors.bgCard,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_rounded,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              // Gradient for label readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Active story dot
              if (isActive)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              // Label
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SHORTS RAIL
  // ==========================================================================
  Widget _buildShortsRail() {
    return StreamBuilder<List<PostModel>>(
      stream: _firestoreService.getUserPosts(_targetUid, type: 'short'),
      builder: (context, snapshot) {
        final shorts = snapshot.data ?? const <PostModel>[];
        _cachedShorts = shorts;
        if (shorts.isEmpty && !_isMyProfile) {
          return const SizedBox.shrink();
        }

        // Kendi profilinde + tile her zaman index 0'da; başkasının profilinde
        // sadece short thumbnail'ları.
        final itemCount = shorts.length + (_isMyProfile ? 1 : 0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHead(
              title: _l10n.phrase('Shorts'),
              meta: shorts.isEmpty
                  ? null
                  : '${shorts.length} ${_l10n.phrase('video')}',
              moreLabel: shorts.isEmpty
                  ? null
                  : _l10n.phrase('Tümü'),
              onMore: shorts.isEmpty
                  ? null
                  : () => _openProfileShorts(shorts, 0),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: itemCount,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  if (_isMyProfile && index == 0) {
                    return _buildAddShortTile();
                  }
                  final shortIndex = _isMyProfile ? index - 1 : index;
                  return _buildShortRailTile(shorts, shortIndex);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddShortTile() {
    return GestureDetector(
      onTap: () => _createPostLive(type: 'short'),
      child: Container(
        width: 115,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.modeEglence.withValues(alpha: 0.22),
              AppColors.bgSurface,
            ],
          ),
          border: Border.all(
            color: AppColors.modeEglence.withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.modeEglence.withValues(alpha: 0.18),
                border: Border.all(
                  color: AppColors.modeEglence.withValues(alpha: 0.5),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.videocam_rounded,
                color: AppColors.modeEglence,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _l10n.phrase('Shorts çek'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortRailTile(List<PostModel> shorts, int index) {
    final post = shorts[index];
    final imageUrl = post.photoUrls.isNotEmpty ? post.photoUrls.first : '';

    return GestureDetector(
      onTap: () {
        // Immersive viewer yalnızca videoUrl'si dolu shortları alır.
        // İlgili post'un filtreli listedeki konumunu bul.
        var itemIndex = 0;
        for (final p in _cachedShorts) {
          if (p.id == post.id) break;
          if ((p.videoUrl ?? '').isNotEmpty) itemIndex++;
        }
        _openImmersiveViewer(categoryId: 'shorts', itemIndex: itemIndex);
      },
      onLongPress: _isMyProfile ? () => _showShortContextSheet(post) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 115,
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  headers: NetworkMediaHeaders.forUrl(imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.bgCard,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.play_circle_rounded,
                      color: Colors.white.withValues(alpha: 0.25),
                      size: 24,
                    ),
                  ),
                )
              else
                Container(
                  color: AppColors.bgCard,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.play_circle_rounded,
                    color: Colors.white.withValues(alpha: 0.25),
                    size: 32,
                  ),
                ),
              // Gradient for text
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),
              // Play icon center
              Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              // Likes bottom-left
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${post.likesCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (post.location.isNotEmpty) ...[
                      const Spacer(),
                      Flexible(
                        child: GestureDetector(
                          onTap: () => _focusPostPlace(post),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              post.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShortContextSheet(PostModel post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                ),
                title: Text(
                  _l10n.phrase('Düzenle'),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_editPostLive(post));
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: Text(
                  _l10n.phrase('Sil'),
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_confirmDeletePost(post));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PLACES RAIL (placeholder)
  // ==========================================================================
  Widget _buildPlacesPlaceholder() {
    final places = _placesVisited;

    if (places.isEmpty) {
      // Başka birinin profilinde veri yoksa hiç gösterme; kendi profilde
      // boş hint bırak.
      if (!_isMyProfile) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHead(
            title: _l10n.phrase('Sık gittiği yerler'),
            meta: _l10n.phrase('henüz yok'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              height: 92,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                _l10n.phrase('Bir mekan paylaş — burada ziyaret geçmişin oluşmaya başlayacak.'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHead(
          title: _l10n.phrase('Sık gittiği yerler'),
          meta: '${places.length}',
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: places.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              return _buildPlaceTile(places[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceTile(PlaceVisitModel place) {
    final cover = place.coverPhotoUrl;

    return GestureDetector(
      onTap: () => _openPlaceFocus(place),
      child: SizedBox(
        width: 156,
        height: 108,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover.isEmpty)
                Container(
                  color: AppColors.bgCard,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.place_rounded,
                    color: Colors.white.withValues(alpha: 0.18),
                    size: 32,
                  ),
                )
              else
                Image.network(
                  cover,
                  headers: NetworkMediaHeaders.forUrl(cover),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.bgCard,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white.withValues(alpha: 0.18),
                      size: 28,
                    ),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.68),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      place.name.isEmpty
                          ? _l10n.phrase('Bilinmeyen mekan')
                          : place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 10,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${place.visitCount}×',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatRelativeTime(place.lastVisitedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlaceFocus(PlaceVisitModel place) {
    if (place.placeId.isEmpty && place.name.trim().isEmpty) return;
    unawaited(
      PlaceFocusService.instance.focusPlace(
        placeName: place.name,
        placeId: place.placeId,
        latitude: place.latitude,
        longitude: place.longitude,
      ),
    );
  }


  // ==========================================================================
  // TOP OVERLAY (back/more + sticky mini-nav)
  // ==========================================================================
  Widget _buildTopOverlay(UserModel user, Color modeColor) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            // Sticky mini-nav (AnimatedOpacity)
            AnimatedOpacity(
              opacity: _showMiniNav ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !_showMiniNav,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(8, topPadding + 6, 10, 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgMain.withValues(alpha: 0.92),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      child: _buildMiniNavContent(user, modeColor),
                    ),
                  ),
                ),
              ),
            ),

            // Her zaman görünen back & more butonları (mini-nav kapalıyken)
            Positioned(
              top: topPadding + 8,
              left: 12,
              child: AnimatedOpacity(
                opacity: _showMiniNav ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: _buildCircularGlassButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Positioned(
              top: topPadding + 8,
              right: 12,
              child: AnimatedOpacity(
                opacity: _showMiniNav ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: Row(
                  children: [
                    if (_isMyProfile) ...[
                      _buildCircularGlassButton(
                        icon: Icons.qr_code_rounded,
                        onTap: _showProfileCodeDialog,
                      ),
                      const SizedBox(width: 8),
                      _buildCircularGlassButton(
                        icon: Icons.settings_rounded,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                          await _loadProfile();
                        },
                      ),
                    ] else
                      _buildCircularGlassButton(
                        icon: Icons.more_horiz_rounded,
                        onTap: _showUserOptionsSheet,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniNavContent(UserModel user, Color modeColor) {
    final avatarUrl = user.profilePhotoUrl.isNotEmpty
        ? user.profilePhotoUrl
        : (user.photoUrls.isNotEmpty ? user.photoUrls.first : '');
    final displayName = user.hasProfile ? user.displayName : user.username;

    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    headers: NetworkMediaHeaders.forUrl(avatarUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  )
                : const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            displayName.isEmpty ? user.username : displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildMiniNavCta(user),
        const SizedBox(width: 6),
        GestureDetector(
          onTap:
              _isMyProfile ? _showProfileCodeDialog : _showUserOptionsSheet,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              _isMyProfile ? Icons.qr_code_rounded : Icons.more_horiz_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniNavCta(UserModel user) {
    if (_isMyProfile) {
      return GestureDetector(
        onTap: _showEditProfileSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            _l10n.phrase('Düzenle'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final label = _hasPendingIncomingFriendRequest
        ? _copy(tr: 'Kabul Et', en: 'Accept', de: 'Akzeptieren')
        : (_hasPendingOutgoingFriendRequest
            ? _copy(tr: 'İptal', en: 'Cancel', de: 'Abbrechen')
            : (_isFriend ? _l10n.phrase('Mesaj') : _l10n.phrase('Eşleş')));
    final callback = _hasPendingIncomingFriendRequest
        ? _acceptIncomingFriendRequest
        : (_hasPendingOutgoingFriendRequest
            ? _cancelOutgoingFriendRequest
            : (_isFriend ? _openMessagesLive : _toggleFollow));

    return GestureDetector(
      onTap: callback,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryGlow],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildCircularGlassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.35),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PEOPLE SHEETS (followers/following/friends)
  // ==========================================================================
  void _showPeopleSheet(String title, String type) {
    final searchCtrl = TextEditingController();
    List<UserModel> filtered = [];
    bool initialized = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<UserModel> source;
            bool loading;

            switch (type) {
              case 'followers':
                source = _followersList;
                loading = _loadingFollowers;
                break;
              case 'following':
                source = _followingList;
                loading = _loadingFollowing;
                break;
              case 'friends':
                source = _friendsList;
                loading = _loadingFriends;
                break;
              default:
                source = [];
                loading = false;
            }

            if (!initialized) {
              filtered = List<UserModel>.from(source);
              initialized = true;
            }

            void applyFilter(String query) {
              final q = query.trim().toLowerCase();
              setModalState(() {
                filtered = source.where((person) {
                  final displayName = person.displayName.toLowerCase();
                  final username = person.username.toLowerCase();
                  return displayName.contains(q) || username.contains(q);
                }).toList();
              });
            }

            if (searchCtrl.text.isNotEmpty) {
              filtered = source.where((person) {
                final q = searchCtrl.text.trim().toLowerCase();
                final displayName = person.displayName.toLowerCase();
                final username = person.username.toLowerCase();
                return displayName.contains(q) || username.contains(q);
              }).toList();
            } else {
              filtered = List<UserModel>.from(source);
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Column(
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.bgMain,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: searchCtrl,
                                onChanged: applyFilter,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: _l10n.phrase('Ara...'),
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _buildPeopleListView(
                          filtered,
                          loading,
                          type == 'friends',
                          scrollController,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(searchCtrl.dispose);
  }

  Widget _buildPeopleListView(
    List<UserModel> people,
    bool loading,
    bool isFriends,
    ScrollController scrollController,
  ) {
    if (loading) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: const [
          ShimmerCard(),
          SizedBox(height: 12),
          ShimmerCard(),
          SizedBox(height: 12),
          ShimmerCard(),
        ],
      );
    }

    if (people.isEmpty) {
      return EmptyStateCard(
        icon: isFriends
            ? Icons.group_off_rounded
            : Icons.people_outline_rounded,
        message: _l10n.phrase('Henüz kimse yok'),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: people.length,
      itemBuilder: (_, i) => _buildPersonTile(people[i], isFriends),
    );
  }

  Widget _buildPersonTile(UserModel person, bool isFriends) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: person.uid)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgMain.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: person.profilePhotoUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        person.profilePhotoUrl,
                        headers: NetworkMediaHeaders.forUrl(
                          person.profilePhotoUrl,
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person_rounded,
                              size: 22,
                              color: AppColors.primary,
                            ),
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      size: 22,
                      color: AppColors.primary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.hasProfile ? person.displayName : person.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${person.username}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 10,
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${person.pulseScore}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isFriends
                        ? Colors.white.withValues(alpha: 0.06)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isFriends ? _l10n.phrase('Mesaj') : _l10n.phrase('Profil'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isFriends
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppColors.primary,
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

  // ==========================================================================
  // USER OPTIONS SHEET (block/report/share)
  // ==========================================================================
  void _showUserOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 16),
            _optionRow(
              Icons.share_rounded,
              _l10n.phrase('Profili Paylaş'),
              Colors.white.withValues(alpha: 0.5),
              () {
                Navigator.pop(context);
                _handleShareProfile();
              },
            ),
            if (_hasPendingOutgoingFriendRequest)
              _optionRow(
                Icons.undo_rounded,
                _copy(
                  tr: 'İsteği İptal Et',
                  en: 'Cancel Request',
                  de: 'Anfrage abbrechen',
                ),
                Colors.white.withValues(alpha: 0.72),
                () {
                  Navigator.pop(context);
                  _cancelOutgoingFriendRequest();
                },
              ),
            if (_hasPendingIncomingFriendRequest)
              _optionRow(
                Icons.close_rounded,
                _copy(
                  tr: 'İsteği Reddet',
                  en: 'Decline Request',
                  de: 'Anfrage ablehnen',
                ),
                Colors.white.withValues(alpha: 0.72),
                () {
                  Navigator.pop(context);
                  _declineIncomingFriendRequest();
                },
              ),
            if (_isFriend)
              _optionRow(
                Icons.person_remove_rounded,
                _copy(
                  tr: 'Arkadaşlıktan Çıkar',
                  en: 'Remove Friend',
                  de: 'Freund entfernen',
                ),
                Colors.white.withValues(alpha: 0.72),
                () {
                  Navigator.pop(context);
                  _removeFriend();
                },
              ),
            _optionRow(
              Icons.report_rounded,
              _l10n.phrase('Şikayet Et'),
              AppColors.warning,
              _handleReportUser,
            ),
            _optionRow(
              _isBlockedByMe ? Icons.lock_open_rounded : Icons.block_rounded,
              _isBlockedByMe
                  ? _copy(tr: 'Engeli Kaldır', en: 'Unblock', de: 'Entsperren')
                  : _l10n.phrase('Engelle'),
              _isBlockedByMe ? AppColors.success : AppColors.error,
              () {
                Navigator.pop(context);
                if (_isBlockedByMe) {
                  _unblockUser();
                } else {
                  _showBlockDialog();
                }
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _optionRow(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgMain.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog() {
    final name = _user?.hasProfile == true
        ? _user!.displayName
        : _user?.username ?? _l10n.phrase('Bu kullanıcı');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _l10n.phrase('Engelle'),
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name ${_l10n.phrase('engellenecek:')}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 12),
            _blockInfo(_l10n.phrase('Tüm mesajlar silinir')),
            _blockInfo(_l10n.phrase('Seni göremez, sen onu göremezsin')),
            _blockInfo(_l10n.phrase('Takip ve arkadaşlık kaldırılır')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _l10n.phrase('Vazgeç'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.blockUser(_myUid, _targetUid);
                if (!mounted) return;
                await _loadProfile(silent: true);
                _showSnackBar(
                  _copy(
                    tr: 'Kullanıcı engellendi.',
                    en: 'User blocked.',
                    de: 'Nutzer blockiert.',
                  ),
                  color: AppColors.success,
                );
              } catch (e, st) {
                debugPrint('Engelleme hatası: $e\n$st');
                _showSnackBar(
                  _l10n.phrase('Kullanıcı engellenemedi.'),
                  color: AppColors.error,
                );
              }
            },
            child: Text(
              _l10n.phrase('Engelle'),
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockInfo(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // EDIT PROFILE & INTERESTS & MODE
  // ==========================================================================
  Future<void> _showEditProfileSheet() async {
    final currentUser = _user;
    if (currentUser == null || !_isMyProfile || _targetUid.isEmpty) return;

    final draft = await Navigator.of(context).push<EditProfileDraft>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(user: currentUser),
        fullscreenDialog: true,
      ),
    );

    if (draft == null || !mounted) return;
    await _saveProfileDraft(currentUser, draft);
  }

  Future<void> _saveProfileDraft(
    UserModel currentUser,
    EditProfileDraft draft,
  ) async {
    if (_isSavingProfile) return;

    final previousUser = _user;
    final optimisticUser = currentUser.copyWith(
      userName: draft.userName,
      displayName: draft.displayName,
      firstName: draft.firstName,
      lastName: draft.lastName,
      bio: draft.bio,
      city: draft.city,
      website: draft.website,
      gender: draft.gender,
      birthDate: draft.birthDate,
      age: draft.birthDate != null
          ? _calculateAge(draft.birthDate!)
          : currentUser.age,
      purpose: draft.purpose,
      matchPreference: draft.matchPreference,
      mode: draft.mode,
      privacyLevel: draft.privacyLevel,
      preferredLanguage: draft.preferredLanguage,
      locationGranularity: draft.locationGranularity,
      enableDifferentialPrivacy: draft.enableDifferentialPrivacy,
      kAnonymityLevel: draft.kAnonymityLevel,
      allowAnalytics: draft.allowAnalytics,
      isVisible: draft.isVisible,
      interests: draft.interests,
      orientation: draft.orientation,
      relationshipIntent: draft.relationshipIntent,
      heightCm: draft.heightCm,
      clearHeight: draft.heightCm == null,
      drinkingStatus: draft.drinkingStatus,
      smokingStatus: draft.smokingStatus,
      lookingForModes: draft.lookingForModes,
      dealbreakers: draft.dealbreakers,
      datingPrompts: draft.datingPrompts,
    );

    setState(() {
      _isSavingProfile = true;
      _user = optimisticUser;
    });

    try {
      await _firestoreService
          .updateProfile(_targetUid, {
            'userName': draft.userName,
            'displayName': draft.displayName,
            'firstName': draft.firstName,
            'lastName': draft.lastName,
            'bio': draft.bio,
            'city': draft.city,
            'website': draft.website,
            'gender': draft.gender,
            'birthDate': draft.birthDate?.toIso8601String(),
            'purpose': draft.purpose,
            'matchPreference': draft.matchPreference,
            'mode': draft.mode,
            'privacyLevel': draft.privacyLevel,
            'preferredLanguage': draft.preferredLanguage,
            'locationGranularity': draft.locationGranularity,
            'enableDifferentialPrivacy': draft.enableDifferentialPrivacy,
            'kAnonymityLevel': draft.kAnonymityLevel,
            'allowAnalytics': draft.allowAnalytics,
            'isVisible': draft.isVisible,
            'interests': draft.interests,
            'orientation': draft.orientation,
            'relationshipIntent': draft.relationshipIntent,
            'heightCm': draft.heightCm,
            'drinkingStatus': draft.drinkingStatus,
            'smokingStatus': draft.smokingStatus,
            'lookingForModes': draft.lookingForModes,
            'dealbreakers': draft.dealbreakers,
            'datingPrompts': draft.datingPrompts,
          })
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      await AppLocaleService.instance.setLanguageCode(draft.preferredLanguage);
      if (!mounted) return;
      _showSnackBar(
        _l10n.phrase('Profil başarıyla güncellendi.'),
        color: AppColors.success,
      );
      unawaited(_loadProfile(silent: true));
    } catch (e, st) {
      debugPrint('Profil güncelleme hatası: $e\n$st');
      if (!mounted) return;

      setState(() => _user = previousUser);
      _showSnackBar(
        _describeActionError(
          e,
          fallbackTr: 'Profil güncellenemedi.',
          fallbackEn: 'Profile could not be updated.',
          fallbackDe: 'Profil konnte nicht aktualisiert werden.',
        ),
        color: AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    final hasBirthdayPassed =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hasBirthdayPassed) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  Future<void> _updateProfileMode(String modeId) async {
    final currentUser = _user;
    if (!_isMyProfile ||
        currentUser == null ||
        _targetUid.isEmpty ||
        currentUser.mode == modeId ||
        _isUpdatingMode) {
      return;
    }

    final previousUser = currentUser;
    setState(() {
      _isUpdatingMode = true;
      _user = currentUser.copyWith(mode: modeId);
    });

    try {
      await _firestoreService
          .updateMode(_targetUid, modeId)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      unawaited(_loadProfile(silent: true));
    } catch (e, st) {
      debugPrint('Mod güncelleme hatası: $e\n$st');
      if (!mounted) return;
      setState(() => _user = previousUser);
      _showSnackBar(
        _l10n.phrase('Mod güncellenemedi.'),
        color: AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingMode = false);
      }
    }
  }

  Future<void> _showModePickerSheet() async {
    final user = _user;
    if (!_isMyProfile || user == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _profileModeSheetTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                ...ModeConfig.all.map((mode) {
                  final isActive = user.mode == mode.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        unawaited(_updateProfileMode(mode.id));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? mode.color.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isActive
                                ? mode.color.withValues(alpha: 0.32)
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: mode.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                mode.icon,
                                size: 18,
                                color: mode.color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _l10n.modeLabel(mode.id),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ),
                            if (isActive)
                              Icon(
                                Icons.check_circle_rounded,
                                color: mode.color,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInterestsEditorSheet() async {
    final currentUser = _user;
    if (!_isMyProfile || currentUser == null || _isSavingProfile) return;

    final selected = {...currentUser.interests};
    final updatedInterests = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _l10n.phrase('İlgi Alanları'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _l10n.phrase(
                        'Profilinde görünen alanları ekle, kaldır ve güncelle.',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(sheetContext).size.height * 0.45,
                      ),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _interestOptions.map((interest) {
                            final isSelected = selected.contains(interest);
                            return GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  if (isSelected) {
                                    selected.remove(interest);
                                  } else {
                                    selected.add(interest);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(
                                          alpha: 0.14,
                                        )
                                      : Colors.white.withValues(alpha: 0.045),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary.withValues(
                                            alpha: 0.3,
                                          )
                                        : Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Text(
                                  _interestLabel(interest),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.white.withValues(alpha: 0.66),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, selected.toList());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _l10n.phrase('Kaydet'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (updatedInterests == null || !mounted) return;

    final previousUser = _user;
    setState(() {
      _isSavingProfile = true;
    });

    try {
      await _firestoreService
          .updateProfile(_targetUid, {'interests': updatedInterests})
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      _showSnackBar(
        _l10n.phrase('İlgi alanları güncellendi.'),
        color: AppColors.success,
      );
      unawaited(_loadProfile(silent: true));
    } catch (e, st) {
      debugPrint('İlgi alanları güncelleme hatası: $e\n$st');
      if (!mounted) return;
      setState(() => _user = previousUser);
      _showSnackBar(
        _l10n.phrase('İlgi alanları güncellenemedi.'),
        color: AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  String get _profileModeSheetTitle => _l10n.t('profile_mode_title');

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
      'Yoga & Meditasyon': 'Yoga & Meditation',
      'Teknoloji': 'Technology',
      'Board Game': 'Board Games',
      'Workshop & Etkinlik': 'Workshops & Events',
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
      'Yoga & Meditasyon': 'Yoga & Meditation',
      'Teknoloji': 'Technologie',
      'Board Game': 'Brettspiele',
      'Workshop & Etkinlik': 'Workshops & Events',
    };

    return switch (_l10n.languageCode) {
      'en' => en[label] ?? label,
      'de' => de[label] ?? label,
      _ => label,
    };
  }
}
