import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedVibe = -1;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  // Shorts için mevcut index
  final PageController _shortsController = PageController();
  int _currentShortIndex = 0;

  final List<Map<String, dynamic>> _vibes = [
    {'label': '#chill', 'count': 42},
    {'label': '#energetic', 'count': 78},
    {'label': '#arty', 'count': 23},
    {'label': '#cozy', 'count': 56},
    {'label': '#loud', 'count': 31},
    {'label': '#hipster', 'count': 44},
    {'label': '#family', 'count': 19},
    {'label': '#romantic', 'count': 27},
    {'label': '#underground', 'count': 15},
    {'label': '#upscale', 'count': 33},
  ];

  // Demo Shorts
  final List<Map<String, dynamic>> _shorts = [
    {
      'user': 'Lena S.',
      'username': '@lena_s',
      'emoji': '👩',
      'color': AppColors.modeSosyal,
      'location': 'Sternschanze',
      'caption': 'Bu kafeyi keşfettim, atmosfer inanılmaz! ☕✨',
      'likes': 234,
      'comments': 18,
      'shares': 7,
      'liked': false,
      'saved': false,
      'vibeTag': '#cozy',
      'pulseScore': 72,
      'gradient': [const Color(0xFF1a1a2e), const Color(0xFF16213e), const Color(0xFF0f3460)],
      'icon': Icons.coffee_rounded,
      'timeAgo': '2 saat önce',
    },
    {
      'user': 'Emre B.',
      'username': '@emre_b',
      'emoji': '🧑',
      'color': AppColors.modeEglence,
      'location': 'Reeperbahn',
      'caption': 'Cuma gecesi burayı görmeden gitmeyin! 🔥🎵',
      'likes': 567,
      'comments': 45,
      'shares': 23,
      'liked': false,
      'saved': false,
      'vibeTag': '#energetic',
      'pulseScore': 91,
      'gradient': [const Color(0xFF0f0f24), const Color(0xFF1a0a2e), const Color(0xFF2d1b69)],
      'icon': Icons.nightlife_rounded,
      'timeAgo': '5 saat önce',
    },
    {
      'user': 'Sophie W.',
      'username': '@sophie_w',
      'emoji': '👩',
      'color': AppColors.modeSakinlik,
      'location': 'Planten un Blomen',
      'caption': 'Pazar sabahı yoga için mükemmel bir yer 🧘🌿',
      'likes': 189,
      'comments': 12,
      'shares': 5,
      'liked': false,
      'saved': false,
      'vibeTag': '#chill',
      'pulseScore': 38,
      'gradient': [const Color(0xFF0a1a0a), const Color(0xFF0f2e1a), const Color(0xFF1a3e2e)],
      'icon': Icons.park_rounded,
      'timeAgo': '8 saat önce',
    },
    {
      'user': 'Julia M.',
      'username': '@julia_m',
      'emoji': '👩',
      'color': AppColors.modeKesif,
      'location': 'HafenCity',
      'caption': 'Elbphilharmonie manzarası ile kahve... Daha ne olsun? 🎶',
      'likes': 412,
      'comments': 31,
      'shares': 15,
      'liked': false,
      'saved': false,
      'vibeTag': '#arty',
      'pulseScore': 64,
      'gradient': [const Color(0xFF1a1a2e), const Color(0xFF2e1a2e), const Color(0xFF3e1a3e)],
      'icon': Icons.music_note_rounded,
      'timeAgo': '1 gün önce',
    },
    {
      'user': 'Can T.',
      'username': '@can_t',
      'emoji': '🧑',
      'color': AppColors.modeUretkenlik,
      'location': 'Ottensen',
      'caption': 'En iyi remote çalışma kafesi bulundu! Wi-Fi hızı: 🚀',
      'likes': 156,
      'comments': 22,
      'shares': 11,
      'liked': false,
      'saved': false,
      'vibeTag': '#hipster',
      'pulseScore': 55,
      'gradient': [const Color(0xFF1a1a0a), const Color(0xFF2e2e1a), const Color(0xFF3e3e0f)],
      'icon': Icons.laptop_mac_rounded,
      'timeAgo': '1 gün önce',
    },
  ];

  // Demo Paylaşımlar (Feed)
  final List<Map<String, dynamic>> _posts = [
    {
      'user': 'Lena S.',
      'username': '@lena_s',
      'emoji': '👩',
      'color': AppColors.modeSosyal,
      'location': 'Café Délice, Sternschanze',
      'text': 'Bugün keşfettiğim bu kafe gerçekten harika. Atmosfer çok sıcak, kahveler el yapımı ve personel çok ilgili. Kesinlikle tekrar geleceğim! ☕',
      'rating': 4.5,
      'likes': 87,
      'comments': 14,
      'liked': false,
      'saved': false,
      'vibeTag': '#cozy',
      'timeAgo': '3 saat önce',
      'photos': 3,
    },
    {
      'user': 'Emre B.',
      'username': '@emre_b',
      'emoji': '🧑',
      'color': AppColors.modeEglence,
      'location': 'Molotow Club, Reeperbahn',
      'text': 'Dün gece canlı müzik festivali vardı. Indie rock sahne aldı, kalabalık enerjik, ses sistemi mükemmeldi. 🎸🔥',
      'rating': 5.0,
      'likes': 234,
      'comments': 38,
      'liked': false,
      'saved': false,
      'vibeTag': '#energetic',
      'timeAgo': '12 saat önce',
      'photos': 5,
    },
    {
      'user': 'Sophie W.',
      'username': '@sophie_w',
      'emoji': '👩',
      'color': AppColors.modeSakinlik,
      'location': 'Alsterwiese',
      'text': 'Sabah 7\'de kimse yokken Alster kenarında yürüyüş... Şehrin en huzurlu anı. Kuş sesleri ve hafif sis. 🌅',
      'rating': 4.8,
      'likes': 156,
      'comments': 9,
      'liked': false,
      'saved': false,
      'vibeTag': '#chill',
      'timeAgo': '1 gün önce',
      'photos': 2,
    },
    {
      'user': 'Can T.',
      'username': '@can_t',
      'emoji': '🧑',
      'color': AppColors.modeUretkenlik,
      'location': 'elbgold, Ottensen',
      'text': 'Remote çalışma için en iyi kafe: hızlı Wi-Fi, sessiz ortam, prize her masada var. Flat white muhteşem. 💻☕',
      'rating': 4.7,
      'likes': 98,
      'comments': 21,
      'liked': false,
      'saved': false,
      'vibeTag': '#hipster',
      'timeAgo': '2 gün önce',
      'photos': 1,
    },
  ];

  // Trending
  final List<Map<String, dynamic>> _trending = [
    {'name': 'Sternschanze', 'pulse': 82, 'density': 'Yoğun', 'trend': 'Yükseliyor', 'trendIcon': Icons.trending_up_rounded, 'vibe': '#energetic', 'color': AppColors.pulseVeryHigh, 'visitors': '~320', 'activity': 'Bar & Kafe'},
    {'name': 'St. Pauli', 'pulse': 91, 'density': 'Çok Yoğun', 'trend': 'Patlıyor', 'trendIcon': Icons.local_fire_department_rounded, 'vibe': '#loud', 'color': AppColors.pulseVeryHigh, 'visitors': '~540', 'activity': 'Gece Hayatı'},
    {'name': 'HafenCity', 'pulse': 64, 'density': 'Orta', 'trend': 'Sabit', 'trendIcon': Icons.trending_flat_rounded, 'vibe': '#arty', 'color': AppColors.pulseMedium, 'visitors': '~180', 'activity': 'Yürüyüş & Müze'},
    {'name': 'Ottensen', 'pulse': 55, 'density': 'Orta', 'trend': 'Yükseliyor', 'trendIcon': Icons.trending_up_rounded, 'vibe': '#hipster', 'color': AppColors.pulseMedium, 'visitors': '~140', 'activity': 'Kafe & Brunch'},
    {'name': 'Planten un Blomen', 'pulse': 38, 'density': 'Düşük', 'trend': 'Sakin', 'trendIcon': Icons.spa_rounded, 'vibe': '#chill', 'color': AppColors.pulseLow, 'visitors': '~60', 'activity': 'Park & Doğa'},
  ];

  // Hotspots
  final List<Map<String, dynamic>> _hotspots = [
    {'title': 'Spontan Müzik', 'location': 'Schanzenpark', 'time': '3 dk önce', 'people': '~30 kişi', 'icon': Icons.music_note_rounded, 'color': AppColors.modeEglence},
    {'title': 'Food Truck Festivali', 'location': 'Reeperbahn', 'time': '12 dk önce', 'people': '~80 kişi', 'icon': Icons.fastfood_rounded, 'color': AppColors.modeTopluluk},
    {'title': 'Açık Hava Yoga', 'location': 'Alsterwiese', 'time': '25 dk önce', 'people': '~20 kişi', 'icon': Icons.self_improvement_rounded, 'color': AppColors.modeSakinlik},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _shortsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // App Bar
            SliverAppBar(
              backgroundColor: AppColors.bgMain,
              elevation: 0,
              pinned: true,
              floating: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: _showSearch
                  ? _buildSearchBar()
                  : const Text('Keşfet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              centerTitle: !_showSearch,
              actions: [
                IconButton(
                  icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, color: Colors.white.withOpacity(0.6), size: 24),
                  onPressed: () => setState(() { _showSearch = !_showSearch; if (!_showSearch) _searchController.clear(); }),
                ),
              ],
            ),

            // Vibe Tags
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: Text('VIBE TAGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.25), letterSpacing: 1.5)),
                  ),
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _vibes.length,
                      itemBuilder: (_, i) {
                        final isSelected = _selectedVibe == i;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedVibe = isSelected ? -1 : i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.bgCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.4) : Colors.white.withOpacity(0.06)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(_vibes[i]['label'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.5))),
                              const SizedBox(width: 6),
                              Text('${_vibes[i]['count']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? AppColors.primary.withOpacity(0.7) : Colors.white.withOpacity(0.2))),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabDelegate(
                child: Container(
                  color: AppColors.bgMain,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 2.5,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.3),
                    dividerColor: Colors.white.withOpacity(0.06),
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    tabs: const [
                      Tab(text: 'Shorts'),
                      Tab(text: 'Paylaşım'),
                      Tab(text: 'Trending'),
                      Tab(text: 'Canlı'),
                      Tab(text: 'Tahmin'),
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
            _buildShortsTab(),
            _buildPostsTab(),
            _buildTrendingTab(),
            _buildHotspotsTab(),
            _buildForecastTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Mekan, kişi veya vibe ara...', hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.white.withOpacity(0.2)),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // SHORTS TAB
  // ══════════════════════════════════════
  Widget _buildShortsTab() {
    return PageView.builder(
      controller: _shortsController,
      scrollDirection: Axis.vertical,
      itemCount: _shorts.length,
      onPageChanged: (i) => setState(() => _currentShortIndex = i),
      itemBuilder: (_, i) => _buildShortCard(_shorts[i], i),
    );
  }

  Widget _buildShortCard(Map<String, dynamic> short, int index) {
    final color = short['color'] as Color;
    final gradientColors = short['gradient'] as List<Color>;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: gradientColors),
      ),
      child: Stack(
        children: [
          // Arka plan ikon
          Center(
            child: Icon(short['icon'] as IconData, size: 120, color: color.withOpacity(0.08)),
          ),

          // Pulse Score (sol üst)
          Positioned(
            top: 16, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.favorite_rounded, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('${short['pulseScore']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
            ),
          ),

          // Vibe tag (sol üst, score'un yanı)
          Positioned(
            top: 16, left: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Text(short['vibeTag'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ),

          // Sağ taraf aksiyonlar
          Positioned(
            right: 16, bottom: 180,
            child: Column(
              children: [
                // Profil
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.2), border: Border.all(color: color, width: 2)),
                  child: Center(child: Text(short['emoji'], style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(height: 20),
                // Like
                _shortAction(
                  short['liked'] ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  '${short['likes']}',
                  short['liked'] ? AppColors.primary : Colors.white,
                  () { HapticFeedback.lightImpact(); setState(() => _shorts[index]['liked'] = !_shorts[index]['liked']); },
                ),
                const SizedBox(height: 16),
                // Yorum
                _shortAction(Icons.chat_bubble_outline_rounded, '${short['comments']}', Colors.white, () {}),
                const SizedBox(height: 16),
                // Paylaş
                _shortAction(Icons.send_rounded, '${short['shares']}', Colors.white, () {}),
                const SizedBox(height: 16),
                // Kaydet
                _shortAction(
                  short['saved'] ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  '',
                  short['saved'] ? AppColors.warning : Colors.white,
                  () { HapticFeedback.lightImpact(); setState(() => _shorts[index]['saved'] = !_shorts[index]['saved']); },
                ),
              ],
            ),
          ),

          // Alt bilgi
          Positioned(
            left: 16, right: 72, bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kullanıcı
                Row(children: [
                  Text(short['user'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(width: 6),
                  Text(short['timeAgo'], style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
                ]),
                const SizedBox(height: 4),
                // Konum
                Row(children: [
                  Icon(Icons.location_on_rounded, size: 13, color: color),
                  const SizedBox(width: 4),
                  Text(short['location'], style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                // Açıklama
                Text(short['caption'], style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85), height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          // Sayfa indikatörü
          Positioned(
            right: 8, top: MediaQuery.of(context).size.height * 0.4,
            child: Column(
              children: List.generate(_shorts.length, (i) => Container(
                width: 4, height: i == _currentShortIndex ? 16 : 4,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: i == _currentShortIndex ? AppColors.primary : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shortAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Icon(icon, size: 28, color: color),
        if (label.isNotEmpty) ...[const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))],
      ]),
    );
  }

  // ══════════════════════════════════════
  // PAYLAŞIM TAB (Feed)
  // ══════════════════════════════════════
  Widget _buildPostsTab() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: _posts.length,
      itemBuilder: (_, i) => _buildPostCard(_posts[i], i),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final color = post['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst: Kullanıcı + zaman
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15), border: Border.all(color: color.withOpacity(0.3))),
                child: Center(child: Text(post['emoji'], style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post['user'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  Row(children: [
                    Icon(Icons.location_on_rounded, size: 11, color: color),
                    const SizedBox(width: 3),
                    Flexible(child: Text(post['location'], style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  ]),
                ]),
              ),
              Text(post['timeAgo'], style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25))),
            ],
          ),

          const SizedBox(height: 12),

          // Fotoğraf alanı
          Container(
            width: double.infinity, height: 180,
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Stack(
              children: [
                Center(child: Icon(Icons.image_rounded, size: 48, color: color.withOpacity(0.15))),
                // Fotoğraf sayısı
                if ((post['photos'] as int) > 1)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                      child: Text('1/${post['photos']}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                // Vibe tag
                Positioned(
                  bottom: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(post['vibeTag'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Metin
          Text(post['text'], style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), height: 1.5)),

          const SizedBox(height: 10),

          // Puan
          Row(
            children: [
              ...List.generate(5, (i) {
                final rating = post['rating'] as double;
                if (i < rating.floor()) {
                  return const Icon(Icons.star_rounded, size: 16, color: AppColors.warning);
                } else if (i < rating) {
                  return const Icon(Icons.star_half_rounded, size: 16, color: AppColors.warning);
                }
                return Icon(Icons.star_border_rounded, size: 16, color: Colors.white.withOpacity(0.15));
              }),
              const SizedBox(width: 6),
              Text('${post['rating']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warning)),
            ],
          ),

          const SizedBox(height: 12),

          // Alt: Like, Yorum, Kaydet
          Row(
            children: [
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); setState(() => _posts[index]['liked'] = !_posts[index]['liked']); },
                child: Row(children: [
                  Icon(post['liked'] ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20, color: post['liked'] ? AppColors.primary : Colors.white.withOpacity(0.35)),
                  const SizedBox(width: 5),
                  Text('${post['likes']}', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4))),
                ]),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {},
                child: Row(children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white.withOpacity(0.35)),
                  const SizedBox(width: 5),
                  Text('${post['comments']}', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4))),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); setState(() => _posts[index]['saved'] = !_posts[index]['saved']); },
                child: Icon(post['saved'] ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 20, color: post['saved'] ? AppColors.warning : Colors.white.withOpacity(0.35)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // TRENDING TAB
  // ══════════════════════════════════════
  Widget _buildTrendingTab() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: _trending.length,
      itemBuilder: (_, i) {
        final area = _trending[i];
        final color = area['color'] as Color;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.06))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: i < 3 ? AppColors.primary.withOpacity(0.15) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: i < 3 ? AppColors.primary : Colors.white.withOpacity(0.3))))),
              const SizedBox(width: 12),
              Expanded(child: Text(area['name'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.favorite_rounded, size: 12, color: color), const SizedBox(width: 4),
                  Text('${area['pulse']}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _miniTag(area['trendIcon'] as IconData, area['trend'], color),
              const SizedBox(width: 8),
              _miniTag(Icons.people_rounded, '${area['visitors']} kişi', Colors.white.withOpacity(0.5)),
              const SizedBox(width: 8),
              _miniTag(Icons.local_activity_rounded, area['activity'], Colors.white.withOpacity(0.5)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(area['vibe'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary))),
              const Spacer(),
              Text(area['density'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ]),
          ]),
        );
      },
    );
  }

  // ══════════════════════════════════════
  // CANLI HOTSPOTS TAB
  // ══════════════════════════════════════
  Widget _buildHotspotsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.15), AppColors.bgCard]),
            borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.5), blurRadius: 8)])),
            const SizedBox(width: 10),
            Text('CANLI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.success, letterSpacing: 1.5)),
            const SizedBox(width: 8),
            Text('${_hotspots.length} aktif hotspot', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
          ]),
        ),
        ..._hotspots.map((h) {
          final color = h['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.15))),
            child: Row(children: [
              Container(width: 50, height: 50, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(h['icon'] as IconData, color: color, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h['title'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.location_on_rounded, size: 12, color: Colors.white.withOpacity(0.3)), const SizedBox(width: 4),
                  Text(h['location'], style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                  const SizedBox(width: 10),
                  Icon(Icons.access_time_rounded, size: 12, color: Colors.white.withOpacity(0.3)), const SizedBox(width: 4),
                  Text(h['time'], style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                ]),
                const SizedBox(height: 6),
                Text(h['people'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ])),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.15)),
            ]),
          );
        }),
      ],
    );
  }
  // ══════════════════════════════════════
  // TAHMİN TAB (AI Destekli)
  // ══════════════════════════════════════
  Widget _buildForecastTab() {
    // Seçili vibe'a göre mod belirleme (demo)
    final currentMode = _selectedVibe >= 0 ? _vibes[_selectedVibe]['label'] : 'genel';

    final List<Map<String, dynamic>> timePredictions = [
      {
        'time': 'Şu an',
        'icon': Icons.access_time_rounded,
        'color': AppColors.primary,
        'confidence': 92,
        'predictions': [
          'Sternschanze ve St. Pauli en aktif bölgeler.',
          'Ortalama yoğunluk: yüksek (320+ kişi).',
          'En popüler aktivite: Bar & Kafe.',
        ],
      },
      {
        'time': '30 dakika sonra',
        'icon': Icons.update_rounded,
        'color': AppColors.warning,
        'confidence': 84,
        'predictions': [
          'Sternschanze\'de yoğunluk %15 artacak.',
          'Ottensen\'de kafe trafiği başlayacak.',
          'Reeperbahn henüz sakin, 21:00\'den sonra hareketlenecek.',
        ],
      },
      {
        'time': '2 saat sonra',
        'icon': Icons.schedule_rounded,
        'color': AppColors.modeEglence,
        'confidence': 76,
        'predictions': [
          'HafenCity\'de akşam yemeği yoğunluğu pik yapacak.',
          'Planten un Blomen\'de yürüyüş trafiği düşecek.',
          'St. Georg bölgesinde restoran doluluk oranı %85+.',
        ],
      },
      {
        'time': 'Bu akşam (21:00+)',
        'icon': Icons.nightlife_rounded,
        'color': AppColors.modeEglence,
        'confidence': 71,
        'predictions': [
          'St. Pauli ve Reeperbahn pik yapacak (500+ kişi).',
          'Sternschanze bar bölgesinde kuyruklar oluşabilir.',
          'Altona sakin kalacak — aile dostu ortam devam edecek.',
        ],
      },
      {
        'time': 'Yarın öğlen',
        'icon': Icons.wb_sunny_rounded,
        'color': AppColors.modeUretkenlik,
        'confidence': 65,
        'predictions': [
          'Ottensen brunch mekanları yoğun olacak.',
          'Elbstrand\'da açık hava aktivitesi artacak.',
          'HafenCity\'de turist yoğunluğu bekleniyor.',
        ],
      },
    ];

    // Mod bazlı kişisel öneriler
    final List<Map<String, dynamic>> modeInsights = [
      {
        'mode': 'Senin Modun İçin',
        'icon': Icons.auto_awesome_rounded,
        'color': AppColors.primary,
        'insight': 'Keşif modundasın. Şu an Ottensen ve HafenCity senin için ideal — düşük kalabalık, yüksek keşif potansiyeli.',
        'suggestion': 'Ottensen\'deki yeni açılan kafeyi dene.',
        'bestTime': 'En iyi zaman: şimdi veya yarın 10:00-12:00',
      },
      {
        'mode': 'Sosyal Öneri',
        'icon': Icons.people_rounded,
        'color': AppColors.modeSosyal,
        'insight': 'Sosyal etkileşim için en uygun bölge şu an Sternschanze. Açık ortam, newcomer-friendly mekanlar mevcut.',
        'suggestion': 'Schulterblatt sokağındaki açık hava barlarına göz at.',
        'bestTime': 'Pik sosyal saat: 19:00-22:00',
      },
      {
        'mode': 'Sakinlik Tahmini',
        'icon': Icons.spa_rounded,
        'color': AppColors.modeSakinlik,
        'insight': 'Planten un Blomen şu an çok sakin (Pulse: 38). Kalabalık 16:00\'dan sonra hafif artacak.',
        'suggestion': 'Japonya bahçesi bölgesi en huzurlu alan.',
        'bestTime': 'En sakin zaman: sabah 7:00-10:00',
      },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // AI banner
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.12), AppColors.bgCard]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome_rounded, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('AI Tahmin Motoru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Geçmiş veriler ve pattern analizi ile üretildi. Güven aralığı ile sunulur.',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35), height: 1.4)),
                ]),
              ),
            ],
          ),
        ),

        // Mod bazlı kişisel öneriler
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('KİŞİSEL ÖNERİLER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.25), letterSpacing: 1.5)),
        ),

        ...modeInsights.map((insight) {
          final color = insight['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(insight['icon'] as IconData, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Text(insight['mode'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
              ]),
              const SizedBox(height: 10),
              Text(insight['insight'], style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6), height: 1.5)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.lightbulb_rounded, size: 14, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(insight['suggestion'], style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500))),
                ]),
              ),
              const SizedBox(height: 6),
              Text(insight['bestTime'], style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3))),
            ]),
          );
        }),

        const SizedBox(height: 16),

        // Zaman tahminleri
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('ZAMAN TAHMİNLERİ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.25), letterSpacing: 1.5)),
        ),

        ...timePredictions.map((pred) {
          final color = pred['color'] as Color;
          final predictions = pred['predictions'] as List<String>;
          final confidence = pred['confidence'] as int;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.12)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(pred['icon'] as IconData, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pred['time'], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.auto_awesome_rounded, size: 10, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 4),
                      Text('Güven: %$confidence', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3))),
                    ]),
                  ]),
                ),
                // Güven çemberi
                SizedBox(
                  width: 36, height: 36,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: confidence / 100,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.6)),
                    ),
                    Text('$confidence', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              ...predictions.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 5, height: 5,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(color: color.withOpacity(0.5), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.55), height: 1.4))),
                ]),
              )),
            ]),
          );
        }),

        const SizedBox(height: 16),

        // Haftalık pattern
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Haftalık Ritim', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              Text('Bu hafta', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25))),
            ]),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].asMap().entries.map((e) {
                final levels = [0.3, 0.35, 0.4, 0.5, 0.85, 0.95, 0.6];
                final isToday = e.key == DateTime.now().weekday - 1;
                return Column(children: [
                  Container(
                    width: 32, height: 80,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 32, height: 80 * levels[e.key],
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [
                              isToday ? AppColors.primary.withOpacity(0.7) : AppColors.primary.withOpacity(0.15),
                              isToday ? AppColors.primary.withOpacity(0.3) : AppColors.primary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(e.value, style: TextStyle(fontSize: 11, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400, color: isToday ? AppColors.primary : Colors.white.withOpacity(0.3))),
                ]);
              }).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.insights_rounded, size: 14, color: AppColors.primary.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Bu haftanın en yoğun günü Cumartesi olacak. Cuma akşamı erken çık, en iyi mekanları yakala.',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4), height: 1.4),
                )),
              ]),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // Saatlik akış grafiği
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.timeline_rounded, size: 18, color: AppColors.modeEglence),
              const SizedBox(width: 8),
              const Text('Bugün Saatlik Akış', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [6, 8, 10, 12, 14, 16, 18, 20, 22, 0].asMap().entries.map((e) {
                  final heights = [0.1, 0.15, 0.3, 0.5, 0.45, 0.55, 0.7, 0.9, 1.0, 0.6];
                  final hour = e.value;
                  final now = DateTime.now().hour;
                  final isPast = hour <= now;
                  final isCurrent = hour == (now ~/ 2) * 2;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Container(
                          height: 45 * heights[e.key],
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.primary.withOpacity(0.7)
                                : isPast
                                    ? AppColors.primary.withOpacity(0.25)
                                    : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${hour.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 8, color: isCurrent ? AppColors.primary : Colors.white.withOpacity(0.2))),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.7), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('Şu an', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3))),
              const SizedBox(width: 14),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('Geçmiş', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3))),
              const SizedBox(width: 14),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('Tahmin', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3))),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _miniTag(IconData icon, String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color), const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ]);
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