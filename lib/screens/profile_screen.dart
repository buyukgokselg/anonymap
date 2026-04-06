import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';
import '../services/firestore_service.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  late TabController _tabController;

  // Profil bilgileri
  String _displayName = '';
  String _bio = '';
  String _city = 'Hamburg';
  String _website = '';

  // Stats
  final int _pulseScore = 72;
  final int _placesVisited = 23;
  final int _vibeTagsCreated = 8;

  // Sosyal
  final int _followers = 128;
  final int _following = 94;
  final int _friends = 31;

  // Demo takipçi listesi
  final List<Map<String, dynamic>> _followersList = [
    {'name': 'Ayşe K.', 'username': '@ayse_k', 'pulse': 65, 'mutual': true},
    {'name': 'Mehmet D.', 'username': '@mehmet_d', 'pulse': 82, 'mutual': false},
    {'name': 'Lena S.', 'username': '@lena_s', 'pulse': 44, 'mutual': true},
    {'name': 'Emre B.', 'username': '@emre_b', 'pulse': 91, 'mutual': false},
    {'name': 'Julia M.', 'username': '@julia_m', 'pulse': 57, 'mutual': true},
    {'name': 'Can T.', 'username': '@can_t', 'pulse': 73, 'mutual': false},
    {'name': 'Sophie W.', 'username': '@sophie_w', 'pulse': 38, 'mutual': true},
  ];

  final List<Map<String, dynamic>> _followingList = [
    {'name': 'Ayşe K.', 'username': '@ayse_k', 'pulse': 65, 'mutual': true},
    {'name': 'Lena S.', 'username': '@lena_s', 'pulse': 44, 'mutual': true},
    {'name': 'Deniz A.', 'username': '@deniz_a', 'pulse': 78, 'mutual': false},
    {'name': 'Max H.', 'username': '@max_h', 'pulse': 55, 'mutual': false},
    {'name': 'Sophie W.', 'username': '@sophie_w', 'pulse': 38, 'mutual': true},
  ];

  final List<Map<String, dynamic>> _friendsList = [
    {'name': 'Ayşe K.', 'username': '@ayse_k', 'pulse': 65, 'since': 'Mart 2026'},
    {'name': 'Lena S.', 'username': '@lena_s', 'pulse': 44, 'since': 'Şubat 2026'},
    {'name': 'Sophie W.', 'username': '@sophie_w', 'pulse': 38, 'since': 'Nisan 2026'},
    {'name': 'Julia M.', 'username': '@julia_m', 'pulse': 57, 'since': 'Mart 2026'},
  ];

  // Highlights
  final List<Map<String, dynamic>> _highlights = [
    {'icon': Icons.coffee_rounded, 'label': 'Kafeler', 'color': AppColors.modeUretkenlik},
    {'icon': Icons.nightlife_rounded, 'label': 'Gece', 'color': AppColors.modeEglence},
    {'icon': Icons.park_rounded, 'label': 'Parklar', 'color': AppColors.modeAcikAlan},
    {'icon': Icons.restaurant_rounded, 'label': 'Yemek', 'color': AppColors.modeTopluluk},
    {'icon': Icons.music_note_rounded, 'label': 'Müzik', 'color': AppColors.modeSosyal},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final data = await _firestoreService.getUserProfile(uid);
      if (mounted) {
        setState(() {
          _profile = data;
          _displayName = data?['displayName'] ?? '';
          _bio = data?['bio'] ?? '';
          _city = data?['city'] ?? 'Hamburg';
          _website = data?['website'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getModeName(String? mode) {
    final modes = {
      'kesif': 'Keşif', 'sakinlik': 'Sakinlik', 'sosyal': 'Sosyal',
      'uretkenlik': 'Üretkenlik', 'eglence': 'Eğlence', 'acik_alan': 'Açık Alan',
      'topluluk': 'Topluluk', 'aile': 'Aile & Çocuk',
    };
    return modes[mode] ?? 'Keşif';
  }

  Color _getModeColor(String? mode) {
    final colors = {
      'kesif': AppColors.modeKesif, 'sakinlik': AppColors.modeSakinlik,
      'sosyal': AppColors.modeSosyal, 'uretkenlik': AppColors.modeUretkenlik,
      'eglence': AppColors.modeEglence, 'acik_alan': AppColors.modeAcikAlan,
      'topluluk': AppColors.modeTopluluk, 'aile': AppColors.modeAcikAlan,
    };
    return colors[mode] ?? AppColors.modeKesif;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final username = email.split('@').first;
    final interests = List<String>.from(_profile?['interests'] ?? []);
    final mode = _profile?['mode'] ?? 'kesif';
    final modeColor = _getModeColor(mode);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // ── App Bar ──
                  SliverAppBar(
                    backgroundColor: AppColors.bgMain,
                    elevation: 0,
                    pinned: true,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text('@$username',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    centerTitle: true,
                    actions: [
                      IconButton(icon: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 22), onPressed: () {}),
                      IconButton(
                        icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      ),
                    ],
                  ),

                  // ── Profil Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // ── Avatar + Stats ──
                          Row(
                            children: [
                              // Avatar
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.5), AppColors.accentLight],
                                      ),
                                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20)],
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bgMain),
                                      child: Container(
                                        margin: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bgCard),
                                        child: const Icon(Icons.person_rounded, size: 36, color: AppColors.primary),
                                      ),
                                    ),
                                  ),
                                  // Online indicator
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.bgMain, width: 3),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: 20),

                              // Takipçi / Takip / Arkadaş
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatTap('$_followers', 'Takipçi', () => _showPeopleSheet('Takipçiler', _followersList, false)),
                                    _buildStatTap('$_following', 'Takip', () => _showPeopleSheet('Takip Edilenler', _followingList, false)),
                                    _buildStatTap('$_friends', 'Arkadaş', () => _showPeopleSheet('Arkadaşlar', _friendsList, true)),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ── İsim + Verified ──
                          Row(
                            children: [
                              Text(
                                _displayName.isNotEmpty ? _displayName : username,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 18, height: 18,
                                decoration: const BoxDecoration(color: AppColors.modeSosyal, shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // ── Mod Badge + Pulse Score Inline ──
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: modeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 6, height: 6, decoration: BoxDecoration(color: modeColor, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(_getModeName(mode), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: modeColor)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.favorite_rounded, size: 12, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text('$_pulseScore', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.explore_rounded, size: 12, color: Colors.white.withOpacity(0.4)),
                                    const SizedBox(width: 4),
                                    Text('$_placesVisited keşif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4))),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // ── Bio ──
                          if (_bio.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(_bio, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), height: 1.4)),
                            )
                          else
                            GestureDetector(
                              onTap: () => _showEditProfileSheet(),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('+ Bio ekle', style: TextStyle(fontSize: 14, color: AppColors.primary.withOpacity(0.6), fontWeight: FontWeight.w500)),
                              ),
                            ),

                          // ── Konum + Website + Tarih ──
                          Wrap(
                            spacing: 16, runSpacing: 6,
                            children: [
                              if (_city.isNotEmpty) _buildInfoChip(Icons.location_on_rounded, _city),
                              if (_website.isNotEmpty) _buildInfoChip(Icons.link_rounded, _website),
                              _buildInfoChip(Icons.calendar_today_rounded, 'Nisan 2026\'da katıldı'),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // ── Ortak Arkadaşlar ──
                          GestureDetector(
                            onTap: () => _showPeopleSheet('Ortak Arkadaşlar', _friendsList, true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  // Mini avatar stack
                                  SizedBox(
                                    width: 52, height: 24,
                                    child: Stack(
                                      children: [
                                        _buildMiniAvatar(0, AppColors.primary),
                                        _buildMiniAvatar(14, AppColors.modeEglence),
                                        _buildMiniAvatar(28, AppColors.modeSosyal),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_friendsList.length} ortak arkadaş',
                                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ── Butonlar ──
                          Row(
                            children: [
                              Expanded(child: _buildActionButton('Profili Düzenle', Icons.edit_rounded, false, () => _showEditProfileSheet())),
                              const SizedBox(width: 10),
                              Expanded(child: _buildActionButton('Profili Paylaş', Icons.share_rounded, false, () {})),
                              const SizedBox(width: 10),
                              _buildIconActionButton(Icons.person_add_alt_rounded, () {}),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // ── Highlights ──
                          SizedBox(
                            height: 82,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _highlights.length + 1,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (_, i) {
                                if (i == 0) return _buildAddHighlight();
                                final h = _highlights[i - 1];
                                return _buildHighlight(h);
                              },
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ── İlgi Alanları ──
                          if (interests.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 32,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: interests.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                                    child: Text(interests[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.45))),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Tab Bar ──
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
                  _buildEmptyGrid(Icons.camera_alt_rounded, 'Henüz paylaşım yok', 'Keşiflerini fotoğraf ve kısa videolarla paylaş.', 'İlk Paylaşımını Yap'),
                  _buildEmptyGrid(Icons.play_circle_rounded, 'Henüz video yok', 'Şehir anlarını kısa videolarla paylaş.', 'Video Çek'),
                  _buildEmptyGrid(Icons.bookmark_rounded, 'Kayıtlı içerik yok', 'Beğendiğin mekanları ve önerileri kaydet.', null),
                ],
              ),
            ),
    );
  }

  // ══════════════════════════════════════
  // WIDGETS
  // ══════════════════════════════════════

  Widget _buildStatTap(String value, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35))),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 24, height: 24,
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
        Text(text, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4))),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: isPrimary ? null : Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: isPrimary ? Colors.white : Colors.white.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isPrimary ? Colors.white : Colors.white.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildIconActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Icon(icon, size: 18, color: Colors.white.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildAddHighlight() {
    return Column(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.bgCard, border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: Icon(Icons.add_rounded, size: 26, color: Colors.white.withOpacity(0.4)),
        ),
        const SizedBox(height: 6),
        Text('Yeni', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35))),
      ],
    );
  }

  Widget _buildHighlight(Map<String, dynamic> h) {
    final color = h['color'] as Color;
    return Column(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, color.withOpacity(0.5)])),
          child: Container(
            margin: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bgMain),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.1)),
              child: Icon(h['icon'] as IconData, size: 22, color: color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(h['label'] as String, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45))),
      ],
    );
  }

  Widget _buildEmptyGrid(IconData icon, String title, String subtitle, String? buttonLabel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: AppColors.bgCard, shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: Icon(icon, size: 32, color: Colors.white.withOpacity(0.15)),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.3), height: 1.4)),
            if (buttonLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(buttonLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // BOTTOM SHEETS
  // ══════════════════════════════════════

  void _showPeopleSheet(String title, List<Map<String, dynamic>> people, bool isFriends) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
                  ),
                  // Başlık + Arama
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 12),
                        Container(
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.bgMain, borderRadius: BorderRadius.circular(12)),
                          child: TextField(
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ara...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
                              prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.white.withOpacity(0.2)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Liste
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: people.length,
                      itemBuilder: (_, i) {
                        final p = people[i];
                        return _buildPersonTile(p, isFriends);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPersonTile(Map<String, dynamic> person, bool isFriends) {
    final isMutual = person['mutual'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgMain.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: const Icon(Icons.person_rounded, size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(person['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    if (isMutual && !isFriends) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.modeSosyal.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Karşılıklı', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.modeSosyal)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(person['username'], style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35))),
                    if (isFriends && person['since'] != null) ...[
                      Text('  •  ', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.2))),
                      Text(person['since'], style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Pulse + Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, size: 10, color: AppColors.primary.withOpacity(0.5)),
                  const SizedBox(width: 3),
                  Text('${person['pulse']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary.withOpacity(0.7))),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isFriends ? Colors.white.withOpacity(0.06) : AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFriends ? 'Mesaj' : (isMutual ? 'Arkadaş' : 'Takip Et'),
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: isFriends ? Colors.white.withOpacity(0.5) : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // EDIT PROFILE
  // ══════════════════════════════════════

  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _displayName);
    final bioCtrl = TextEditingController(text: _bio);
    final cityCtrl = TextEditingController(text: _city);
    final webCtrl = TextEditingController(text: _website);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('Profili Düzenle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 20),
                _buildEditField('Ad Soyad', nameCtrl, Icons.person_rounded),
                _buildEditField('Hakkında', bioCtrl, Icons.info_outline_rounded, maxLines: 3),
                _buildEditField('Şehir', cityCtrl, Icons.location_on_rounded),
                _buildEditField('Website', webCtrl, Icons.link_rounded),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                      if (uid.isNotEmpty) {
                        await _firestoreService.updateProfile(uid, {
                          'displayName': nameCtrl.text.trim(), 'bio': bioCtrl.text.trim(),
                          'city': cityCtrl.text.trim(), 'website': webCtrl.text.trim(),
                        });
                        setState(() {
                          _displayName = nameCtrl.text.trim(); _bio = bioCtrl.text.trim();
                          _city = cityCtrl.text.trim(); _website = webCtrl.text.trim();
                        });
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                    ),
                    child: const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: AppColors.bgMain, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: TextField(
              controller: controller, maxLines: maxLines,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.2), size: 18),
                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
  @override double get minExtent => 48;
  @override double get maxExtent => 48;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override bool shouldRebuild(covariant _StickyTabDelegate oldDelegate) => false;
}