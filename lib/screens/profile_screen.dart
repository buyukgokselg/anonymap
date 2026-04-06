import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/colors.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();

  late final TabController _tabController;

  UserModel? _user;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isFollowing = false;
  bool _isFriend = false;

  List<UserModel> _followersList = [];
  List<UserModel> _followingList = [];
  List<UserModel> _friendsList = [];

  bool _loadingFollowers = false;
  bool _loadingFollowing = false;
  bool _loadingFriends = false;

  StreamSubscription<List<UserModel>>? _followersSub;
  StreamSubscription<List<UserModel>>? _followingSub;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _targetUid => widget.userId ?? _myUid;
  bool get _isMyProfile => widget.userId == null || widget.userId == _myUid;

  final List<Map<String, dynamic>> _highlights = const [
    {
      'icon': Icons.coffee_rounded,
      'label': 'Kafeler',
      'color': AppColors.modeUretkenlik,
    },
    {
      'icon': Icons.nightlife_rounded,
      'label': 'Gece',
      'color': AppColors.modeEglence,
    },
    {
      'icon': Icons.park_rounded,
      'label': 'Parklar',
      'color': AppColors.modeAcikAlan,
    },
    {
      'icon': Icons.restaurant_rounded,
      'label': 'Yemek',
      'color': AppColors.modeTopluluk,
    },
    {
      'icon': Icons.music_note_rounded,
      'label': 'Müzik',
      'color': AppColors.modeSosyal,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _followersSub?.cancel();
    _followingSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final user = await _firestoreService.getUser(_targetUid);

      bool following = _isFollowing;
      bool friend = _isFriend;

      if (!_isMyProfile && _myUid.isNotEmpty) {
        final results = await Future.wait([
          _firestoreService.isFollowing(_myUid, _targetUid),
          _firestoreService.isFriend(_myUid, _targetUid),
        ]);

        following = results[0];
        friend = results[1];
      }

      if (!mounted) return;

      setState(() {
        _user = user;
        _isFollowing = following;
        _isFriend = friend;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Profil yükleme hatası: $e\n$st');
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showSnackBar(
        'Profil yüklenirken hata oluştu.',
        color: AppColors.error,
      );
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _loadFollowers() async {
    if (_loadingFollowers) return;

    setState(() => _loadingFollowers = true);
    await _followersSub?.cancel();

    _followersSub = _firestoreService.getFollowers(_targetUid).listen(
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

  Future<void> _loadFollowing() async {
    if (_loadingFollowing) return;

    setState(() => _loadingFollowing = true);
    await _followingSub?.cancel();

    _followingSub = _firestoreService.getFollowing(_targetUid).listen(
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
      return;
    } catch (e, st) {
      debugPrint('Arkadaşlar yükleme hatası: $e\n$st');
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
        'Takip işlemi sırasında hata oluştu.',
        color: AppColors.error,
      );
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_myUid.isEmpty || _targetUid.isEmpty) return;

    try {
      await _firestoreService.sendFriendRequest(_myUid, _targetUid);
      if (!mounted) return;

      _showSnackBar(
        'Arkadaşlık isteği gönderildi!',
        color: AppColors.success,
      );
    } catch (e, st) {
      debugPrint('Arkadaş isteği hatası: $e\n$st');
      _showSnackBar(
        'Arkadaşlık isteği gönderilemedi.',
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

  String _getModeName(String? mode) {
    const modes = {
      'kesif': 'Keşif',
      'sakinlik': 'Sakinlik',
      'sosyal': 'Sosyal',
      'uretkenlik': 'Üretkenlik',
      'eglence': 'Eğlence',
      'acik_alan': 'Açık Alan',
      'topluluk': 'Topluluk',
      'aile': 'Aile & Çocuk',
    };
    return modes[mode] ?? 'Keşif';
  }

  Color _getModeColor(String? mode) {
    const colors = {
      'kesif': AppColors.modeKesif,
      'sakinlik': AppColors.modeSakinlik,
      'sosyal': AppColors.modeSosyal,
      'uretkenlik': AppColors.modeUretkenlik,
      'eglence': AppColors.modeEglence,
      'acik_alan': AppColors.modeAcikAlan,
      'topluluk': AppColors.modeTopluluk,
      'aile': AppColors.modeAcikAlan,
    };
    return colors[mode] ?? AppColors.modeKesif;
  }

  String _monthName(int month) {
    const months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return months[month];
  }

  void _handleShareProfile() {
    final username = _user?.username ?? '';
    _showSnackBar('@$username profili paylaşım için hazır.');
  }

  void _handleShowQr() {
    _showSnackBar('QR profil özelliği hazır değil.');
  }

  void _handleOpenMessages() {
    _showSnackBar('Mesaj ekranı entegrasyonu bağlanabilir.');
  }

  void _handleAddPeople() {
    _showSnackBar('Kişi ekleme özelliği bağlanabilir.');
  }

  void _handleReportUser() {
    Navigator.pop(context);
    _showSnackBar(
      'Şikayet işlemi kayıt altına alınabilir.',
      color: AppColors.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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

    final user = _user;
    if (user == null) {
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
            'Kullanıcı bulunamadı',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        ),
      );
    }

    final modeColor = _getModeColor(user.mode);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: AppColors.bgMain,
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                '@${user.username}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              actions: [
                if (!_isMyProfile)
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _showUserOptionsSheet,
                  ),
                if (_isMyProfile) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.qr_code_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _handleShowQr,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                      await _loadProfile();
                    },
                  ),
                ],
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.bottomRight,
                          children: [
                            _buildProfileAvatar(user, modeColor),
                            if (user.isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.bgMain,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            if (_isMyProfile)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: GestureDetector(
                                  onTap: () => _showSnackBar(
                                    'Fotoğraf yükleme bağlanabilir.',
                                  ),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.bgMain,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatTap(
                                '${user.followersCount}',
                                'Takipçi',
                                () async {
                                  await _loadFollowers();
                                  if (!mounted) return;
                                  _showPeopleSheet('Takipçiler', 'followers');
                                },
                              ),
                              _buildStatTap(
                                '${user.followingCount}',
                                'Takip',
                                () async {
                                  await _loadFollowing();
                                  if (!mounted) return;
                                  _showPeopleSheet(
                                    'Takip Edilenler',
                                    'following',
                                  );
                                },
                              ),
                              _buildStatTap(
                                '${user.friendsCount}',
                                'Arkadaş',
                                () async {
                                  await _loadFriends();
                                  if (!mounted) return;
                                  _showPeopleSheet('Arkadaşlar', 'friends');
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.hasProfile ? user.displayName : user.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppColors.modeSosyal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPill(
                          color: modeColor.withOpacity(0.12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: modeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getModeName(user.mode),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: modeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildPill(
                          color: AppColors.primary.withOpacity(0.12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${user.pulseScore}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildPill(
                          color: Colors.white.withOpacity(0.05),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.explore_rounded,
                                size: 12,
                                color: Colors.white.withOpacity(0.4),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${user.placesVisited} keşif',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (user.bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          user.bio,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.4,
                          ),
                        ),
                      )
                    else if (_isMyProfile)
                      GestureDetector(
                        onTap: _showEditProfileSheet,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '+ Bio ekle',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primary.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        if (user.city.isNotEmpty)
                          _buildInfoChip(Icons.location_on_rounded, user.city),
                        if (user.website.isNotEmpty)
                          _buildInfoChip(Icons.link_rounded, user.website),
                        if (user.createdAt != null)
                          _buildInfoChip(
                            Icons.calendar_today_rounded,
                            '${_monthName(user.createdAt!.month)} ${user.createdAt!.year}\'de katıldı',
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (!_isMyProfile && _friendsList.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showPeopleSheet(
                          'Ortak Arkadaşlar',
                          'friends',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 52,
                                height: 24,
                                child: Stack(
                                  children: [
                                    _buildMiniAvatar(0, AppColors.primary),
                                    _buildMiniAvatar(
                                      14,
                                      AppColors.modeEglence,
                                    ),
                                    _buildMiniAvatar(
                                      28,
                                      AppColors.modeSosyal,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_friendsList.length} ortak arkadaş',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (_isMyProfile)
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              'Profili Düzenle',
                              Icons.edit_rounded,
                              false,
                              _showEditProfileSheet,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildActionButton(
                              'Profili Paylaş',
                              Icons.share_rounded,
                              false,
                              _handleShareProfile,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildIconActionButton(
                            Icons.person_add_alt_rounded,
                            _handleAddPeople,
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              _isFollowing ? 'Takipten Çık' : 'Takip Et',
                              _isFollowing
                                  ? Icons.person_remove_rounded
                                  : Icons.person_add_rounded,
                              !_isFollowing,
                              _toggleFollow,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildActionButton(
                              _isFriend ? 'Mesaj' : 'Arkadaş Ekle',
                              _isFriend
                                  ? Icons.chat_rounded
                                  : Icons.group_add_rounded,
                              false,
                              _isFriend
                                  ? _handleOpenMessages
                                  : _sendFriendRequest,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildIconActionButton(
                            Icons.more_horiz_rounded,
                            _showUserOptionsSheet,
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 82,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _highlights.length + (_isMyProfile ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) {
                          if (_isMyProfile && i == 0) {
                            return _buildAddHighlight();
                          }
                          final h = _highlights[_isMyProfile ? i - 1 : i];
                          return _buildHighlight(h);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (user.interests.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: user.interests.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              user.interests[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.45),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabDelegate(
                child: Container(
                  color: AppColors.bgMain,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 2,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.25),
                    dividerColor: Colors.white.withOpacity(0.06),
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on_rounded, size: 22)),
                      Tab(icon: Icon(Icons.play_circle_rounded, size: 22)),
                      Tab(icon: Icon(Icons.bookmark_rounded, size: 22)),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildEmptyGrid(
              Icons.camera_alt_rounded,
              'Henüz paylaşım yok',
              'Keşiflerini fotoğraf ve kısa videolarla paylaş.',
              _isMyProfile ? 'İlk Paylaşımını Yap' : null,
            ),
            _buildEmptyGrid(
              Icons.play_circle_rounded,
              'Henüz video yok',
              'Şehir anlarını kısa videolarla paylaş.',
              _isMyProfile ? 'Video Çek' : null,
            ),
            _buildEmptyGrid(
              Icons.bookmark_rounded,
              'Kayıtlı içerik yok',
              'Beğendiğin mekanları ve önerileri kaydet.',
              null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(UserModel user, Color modeColor) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [modeColor, modeColor.withOpacity(0.5), AppColors.accentLight],
        ),
        boxShadow: [
          BoxShadow(
            color: modeColor.withOpacity(0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgMain,
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgCard,
          ),
          child: user.profilePhotoUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    user.profilePhotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : const Icon(
                  Icons.person_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
        ),
      ),
    );
  }

  Widget _buildPill({required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildStatTap(String value, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.bgMain, width: 2),
        ),
        child: Icon(Icons.person_rounded, size: 12, color: color),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.3)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    bool isPrimary,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isPrimary
                  ? Colors.white
                  : Colors.white.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, size: 18, color: Colors.white.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildAddHighlight() {
    return GestureDetector(
      onTap: () => _showSnackBar('Yeni highlight ekleme bağlanabilir.'),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgCard,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 26,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Yeni',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlight(Map<String, dynamic> h) {
    final color = h['color'] as Color;
    return GestureDetector(
      onTap: () => _showSnackBar('${h['label']} highlight açılabilir.'),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.5)],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgMain,
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.1),
                ),
                child: Icon(h['icon'] as IconData, size: 22, color: color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            h['label'] as String,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyGrid(
    IconData icon,
    String title,
    String subtitle,
    String? buttonLabel,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Icon(
                icon,
                size: 32,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.3),
                height: 1.4,
              ),
            ),
            if (buttonLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    _showSnackBar('$buttonLabel özelliği bağlanabilir.'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
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
                                  hintText: 'Ara...',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.2),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: Colors.white.withOpacity(0.2),
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (people.isEmpty) {
      return Center(
        child: Text(
          'Henüz kimse yok',
          style: TextStyle(color: Colors.white.withOpacity(0.3)),
        ),
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
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: person.uid),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgMain.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: person.profilePhotoUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        person.profilePhotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
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
                      color: Colors.white.withOpacity(0.35),
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
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${person.pulseScore}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary.withOpacity(0.7),
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
                        ? Colors.white.withOpacity(0.06)
                        : AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isFriends ? 'Mesaj' : 'Profil',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isFriends
                          ? Colors.white.withOpacity(0.5)
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
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _optionRow(
              Icons.share_rounded,
              'Profili Paylaş',
              Colors.white.withOpacity(0.5),
              () {
                Navigator.pop(context);
                _handleShareProfile();
              },
            ),
            _optionRow(
              Icons.report_rounded,
              'Şikayet Et',
              AppColors.warning,
              _handleReportUser,
            ),
            _optionRow(
              Icons.block_rounded,
              'Engelle',
              AppColors.error,
              () {
                Navigator.pop(context);
                _showBlockDialog();
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
          color: AppColors.bgMain.withOpacity(0.5),
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
        : _user?.username ?? 'Bu kullanıcı';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Engelle',
          style: TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name engellenecek:',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 12),
            _blockInfo('Tüm mesajlar silinir'),
            _blockInfo('Seni göremez, sen onu göremezsin'),
            _blockInfo('Takip ve arkadaşlık kaldırılır'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Vazgeç',
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.blockUser(_myUid, _targetUid);
                if (!mounted) return;
                Navigator.pop(context);
              } catch (e, st) {
                debugPrint('Engelleme hatası: $e\n$st');
                _showSnackBar(
                  'Kullanıcı engellenemedi.',
                  color: AppColors.error,
                );
              }
            },
            child: const Text(
              'Engelle',
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
            color: AppColors.primary.withOpacity(0.5),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.45),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet() {
  final nameCtrl = TextEditingController(text: _user?.displayName ?? '');
  final bioCtrl = TextEditingController(text: _user?.bio ?? '');
  final cityCtrl = TextEditingController(text: _user?.city ?? '');
  final webCtrl = TextEditingController(text: _user?.website ?? '');

  bool isSaving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> handleSave() async {
            if (isSaving) return;

            final displayName = nameCtrl.text.trim();
            final bio = bioCtrl.text.trim();
            final city = cityCtrl.text.trim();
            final website = webCtrl.text.trim();

            setSheetState(() => isSaving = true);

            try {
              await _firestoreService.updateProfile(_targetUid, {
                'displayName': displayName,
                'bio': bio,
                'city': city,
                'website': website,
              });

              if (!mounted) return;

              Navigator.of(sheetContext).pop();

              await _loadProfile(silent: true);

              if (!mounted) return;
              _showSnackBar(
                'Profil başarıyla güncellendi.',
                color: AppColors.success,
              );
            } catch (e, st) {
              debugPrint('Profil güncelleme hatası: $e\n$st');

              if (mounted) {
                _showSnackBar(
                  'Profil güncellenemedi.',
                  color: AppColors.error,
                );
              }

              if (Navigator.of(sheetContext).canPop()) {
                setSheetState(() => isSaving = false);
              }
            }
          }

          return Container(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 20),
                  const Text(
                    'Profili Düzenle',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildEditField('Ad Soyad', nameCtrl, Icons.person_rounded),
                  _buildEditField(
                    'Hakkında',
                    bioCtrl,
                    Icons.info_outline_rounded,
                    maxLines: 3,
                  ),
                  _buildEditField('Şehir', cityCtrl, Icons.location_on_rounded),
                  _buildEditField('Website', webCtrl, Icons.link_rounded),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Kaydet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
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
  ).whenComplete(() {
    nameCtrl.dispose();
    bioCtrl.dispose();
    cityCtrl.dispose();
    webCtrl.dispose();
  });
}

  Widget _buildEditField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgMain,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color: Colors.white.withOpacity(0.2),
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabDelegate({required this.child});

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyTabDelegate oldDelegate) => false;
}