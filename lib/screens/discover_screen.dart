import 'package:flutter/material.dart';
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

  final List<Map<String, dynamic>> _vibes = [
    {'label': '#chill', 'count': 42},
    {'label': '#energetic', 'count': 78},
    {'label': '#arty', 'count': 23},
    {'label': '#cozy', 'count': 56},
    {'label': '#loud', 'count': 31},
    {'label': '#hipster', 'count': 44},
    {'label': '#family', 'count': 19},
    {'label': '#romantic', 'count': 27},
  ];

  final List<Map<String, dynamic>> _trendingAreas = [
    {
      'name': 'Sternschanze',
      'pulse': 82,
      'density': 'Yoğun',
      'trend': 'Yükseliyor',
      'trendIcon': Icons.trending_up_rounded,
      'vibe': '#energetic',
      'color': AppColors.pulseVeryHigh,
      'visitors': '~320 kişi',
      'topActivity': 'Bar & Kafe',
    },
    {
      'name': 'HafenCity',
      'pulse': 64,
      'density': 'Orta',
      'trend': 'Sabit',
      'trendIcon': Icons.trending_flat_rounded,
      'vibe': '#arty',
      'color': AppColors.pulseMedium,
      'visitors': '~180 kişi',
      'topActivity': 'Yürüyüş & Müze',
    },
    {
      'name': 'St. Pauli',
      'pulse': 91,
      'density': 'Çok Yoğun',
      'trend': 'Patlıyor',
      'trendIcon': Icons.local_fire_department_rounded,
      'vibe': '#loud',
      'color': AppColors.pulseVeryHigh,
      'visitors': '~540 kişi',
      'topActivity': 'Gece Hayatı',
    },
    {
      'name': 'Ottensen',
      'pulse': 55,
      'density': 'Orta',
      'trend': 'Yükseliyor',
      'trendIcon': Icons.trending_up_rounded,
      'vibe': '#hipster',
      'color': AppColors.pulseMedium,
      'visitors': '~140 kişi',
      'topActivity': 'Kafe & Brunch',
    },
    {
      'name': 'Planten un Blomen',
      'pulse': 38,
      'density': 'Düşük',
      'trend': 'Sakin',
      'trendIcon': Icons.spa_rounded,
      'vibe': '#chill',
      'color': AppColors.pulseLow,
      'visitors': '~60 kişi',
      'topActivity': 'Park & Doğa',
    },
  ];

  final List<Map<String, dynamic>> _hotspots = [
    {
      'title': 'Spontan Müzik',
      'location': 'Schanzenpark',
      'time': '3 dk önce',
      'people': '~30 kişi toplandı',
      'icon': Icons.music_note_rounded,
      'color': AppColors.modeEglence,
    },
    {
      'title': 'Food Truck Festivali',
      'location': 'Reeperbahn',
      'time': '12 dk önce',
      'people': '~80 kişi',
      'icon': Icons.fastfood_rounded,
      'color': AppColors.modeTopluluk,
    },
    {
      'title': 'Açık Hava Yoga',
      'location': 'Alsterwiese',
      'time': '25 dk önce',
      'people': '~20 kişi',
      'icon': Icons.self_improvement_rounded,
      'color': AppColors.modeSakinlik,
    },
  ];

  final List<Map<String, dynamic>> _timeForecasts = [
    {
      'time': 'Şu an',
      'icon': Icons.access_time_rounded,
      'text': 'Sternschanze ve St. Pauli en aktif bölgeler.',
      'color': AppColors.primary,
    },
    {
      'time': '1 saat sonra',
      'icon': Icons.update_rounded,
      'text': 'HafenCity\'de hareket artacak, akşam yemeği saati.',
      'color': AppColors.warning,
    },
    {
      'time': 'Bu akşam',
      'icon': Icons.nightlife_rounded,
      'text': 'St. Pauli ve Reeperbahn pik yapacak.',
      'color': AppColors.modeEglence,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Keşfet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(Icons.search_rounded,
                      color: Colors.white.withOpacity(0.6), size: 24),
                  onPressed: () {},
                ),
              ],
            ),

            // ── Vibe Tags ──
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: Text(
                      'VIBE TAGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.25),
                        letterSpacing: 1.5,
                      ),
                    ),
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
                          onTap: () => setState(() =>
                              _selectedVibe = isSelected ? -1 : i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.15)
                                  : AppColors.bgCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.4)
                                    : Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _vibes[i]['label'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_vibes[i]['count']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.7)
                                        : Colors.white.withOpacity(0.2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                    indicatorWeight: 2.5,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.3),
                    dividerColor: Colors.white.withOpacity(0.06),
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    tabs: const [
                      Tab(text: 'Trending'),
                      Tab(text: 'Hotspots'),
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
            _buildTrendingTab(),
            _buildHotspotsTab(),
            _buildForecastTab(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // TAB 1: Trending Bölgeler
  // ══════════════════════════════════════
  Widget _buildTrendingTab() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: _trendingAreas.length,
      itemBuilder: (_, i) {
        final area = _trendingAreas[i];
        final color = area['color'] as Color;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst satır
              Row(
                children: [
                  // Sıra numarası
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: i < 3
                          ? AppColors.primary.withOpacity(0.15)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: i < 3
                              ? AppColors.primary
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      area['name'],
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Pulse Score
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_rounded,
                            size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(
                          '${area['pulse']}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Alt bilgiler
              Row(
                children: [
                  _buildMiniTag(
                    area['trendIcon'] as IconData,
                    area['trend'],
                    color,
                  ),
                  const SizedBox(width: 8),
                  _buildMiniTag(
                    Icons.people_rounded,
                    area['visitors'],
                    Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  _buildMiniTag(
                    Icons.local_activity_rounded,
                    area['topActivity'],
                    Colors.white.withOpacity(0.5),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Vibe + Density
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      area['vibe'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    area['density'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════
  // TAB 2: Canlı Hotspotlar
  // ══════════════════════════════════════
  Widget _buildHotspotsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Canlı banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.15),
                AppColors.bgCard,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'CANLI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_hotspots.length} aktif hotspot tespit edildi',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),

        ..._hotspots.map((h) => _buildHotspotCard(h)),
      ],
    );
  }

  Widget _buildHotspotCard(Map<String, dynamic> h) {
    final color = h['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // İkon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(h['icon'] as IconData, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h['title'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 12, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(width: 4),
                    Text(
                      h['location'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.access_time_rounded,
                        size: 12, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(width: 4),
                    Text(
                      h['time'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  h['people'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.15)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // TAB 3: Zaman Tahmini
  // ══════════════════════════════════════
  Widget _buildForecastTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Açıklama
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 20, color: AppColors.primary.withOpacity(0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Geçmiş verilerden öğrenilen tahminler. Güven aralığı ile sunulur.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.4),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tahmin kartları
        ..._timeForecasts.map((f) {
          final color = f['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(f['icon'] as IconData,
                      color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f['time'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        f['text'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.5),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 8),

        // Haftalık pattern
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Haftalık Ritim',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
                    .asMap()
                    .entries
                    .map((e) {
                  final levels = [0.3, 0.35, 0.4, 0.5, 0.85, 0.95, 0.6];
                  final isToday = e.key == DateTime.now().weekday - 1;
                  return Column(
                    children: [
                      Container(
                        width: 32,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            width: 32,
                            height: 80 * levels[e.key],
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppColors.primary.withOpacity(0.6)
                                  : AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w400,
                          color: isToday
                              ? AppColors.primary
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniTag(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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