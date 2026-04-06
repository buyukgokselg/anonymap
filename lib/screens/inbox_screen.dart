import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Demo geçici chatler (24 saat)
  final List<Map<String, dynamic>> _tempChats = [
    {
      'name': 'Lena S.',
      'username': '@lena_s',
      'emoji': '👩',
      'color': AppColors.modeSosyal,
      'dist': '120m',
      'compatibility': 87,
      'pulse': 65,
      'commonInterests': ['Müzik & Konser', 'Kafeler', 'Fotoğrafçılık'],
      'bio': 'Hamburg keşfetmeyi seven biri ☕',
      'anonymous': false,
      'lastMessage': 'Buluşalım mı? ☕',
      'time': '14:22',
      'unread': 2,
      'hoursLeft': 18,
      'mode': 'Sosyal',
      'modeColor': AppColors.modeSosyal,
    },
    {
      'name': null,
      'username': null,
      'emoji': '🧑',
      'color': AppColors.modeKesif,
      'dist': '240m',
      'compatibility': 72,
      'pulse': 48,
      'commonInterests': ['Seyahat', 'Fotoğrafçılık'],
      'bio': null,
      'anonymous': true,
      'lastMessage': 'Merhaba! 👋',
      'time': '13:45',
      'unread': 1,
      'hoursLeft': 22,
      'mode': 'Keşif',
      'modeColor': AppColors.modeKesif,
    },
  ];

  // Demo kalıcı DM'ler (arkadaş eklendi)
  final List<Map<String, dynamic>> _dmChats = [
    {
      'name': 'Emre B.',
      'username': '@emre_b',
      'emoji': '🧑',
      'color': AppColors.modeEglence,
      'dist': '380m',
      'compatibility': 65,
      'pulse': 91,
      'commonInterests': ['Barlar & Gece', 'Müzik & Konser'],
      'bio': 'Gece kuşu 🦉',
      'anonymous': false,
      'lastMessage': 'Harika gece oldu! 🎵',
      'time': 'Dün',
      'unread': 0,
      'online': true,
      'mode': 'Eğlence',
      'modeColor': AppColors.modeEglence,
    },
    {
      'name': 'Sophie W.',
      'username': '@sophie_w',
      'emoji': '👩',
      'color': AppColors.modeTopluluk,
      'dist': '520m',
      'compatibility': 48,
      'pulse': 55,
      'commonInterests': ['Yoga & Meditasyon', 'Parklar & Doğa'],
      'bio': 'Doğa ve huzur 🌿',
      'anonymous': false,
      'lastMessage': 'Yarın parka gidelim mi?',
      'time': 'Pazartesi',
      'unread': 0,
      'online': false,
      'mode': 'Topluluk',
      'modeColor': AppColors.modeTopluluk,
    },
    {
      'name': 'Julia M.',
      'username': '@julia_m',
      'emoji': '👩',
      'color': AppColors.modeSakinlik,
      'dist': '290m',
      'compatibility': 76,
      'pulse': 44,
      'commonInterests': ['Yoga & Meditasyon', 'Kitap & Okuma', 'Kafeler'],
      'bio': 'Kitap kurdu 📚',
      'anonymous': false,
      'lastMessage': 'O kitabı bitirdim, süperdi!',
      'time': 'Geçen hafta',
      'unread': 0,
      'online': false,
      'mode': 'Sakinlik',
      'modeColor': AppColors.modeSakinlik,
    },
  ];

  // Arkadaş istekleri
  final List<Map<String, dynamic>> _friendRequests = [
    {
      'name': 'Can T.',
      'username': '@can_t',
      'emoji': '🧑',
      'color': AppColors.modeUretkenlik,
      'compatibility': 43,
      'pulse': 62,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _totalUnread {
    int count = 0;
    for (final c in _tempChats) { count += (c['unread'] as int? ?? 0); }
    for (final c in _dmChats) { count += (c['unread'] as int? ?? 0); }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mesajlar', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5), size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Arkadaş istekleri
          if (_friendRequests.isNotEmpty) _buildFriendRequestBanner(),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white.withOpacity(0.35),
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Geçici'),
                      if (_tempChats.any((c) => (c['unread'] as int) > 0)) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 18, height: 18,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Center(child: Text('${_tempChats.where((c) => (c['unread'] as int) > 0).length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Mesajlar'),
                      if (_dmChats.any((c) => (c['unread'] as int) > 0)) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 18, height: 18,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Center(child: Text('${_dmChats.where((c) => (c['unread'] as int) > 0).length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // İçerik
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTempChats(),
                _buildDmChats(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Arkadaş İsteği Banner ──
  Widget _buildFriendRequestBanner() {
    return GestureDetector(
      onTap: () => _showFriendRequests(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.12), AppColors.bgCard]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.person_add_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Arkadaş İstekleri', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('${_friendRequests.length} yeni istek', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                ],
              ),
            ),
            Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Center(child: Text('${_friendRequests.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }

  // ── Geçici Chatler (24 saat) ──
  Widget _buildTempChats() {
    if (_tempChats.isEmpty) {
      return _buildEmptyState(Icons.schedule_rounded, 'Geçici sohbet yok', 'Sinyal ekranından eşleşme bul.\n24 saat içinde arkadaş eklenmezse sohbet silinir.');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Bilgi
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.04))),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning.withOpacity(0.6)),
              const SizedBox(width: 10),
              Expanded(child: Text('Geçici sohbetler 24 saat sonra otomatik silinir. Devam etmek için arkadaş ekleyin.', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3), height: 1.4))),
            ],
          ),
        ),
        ..._tempChats.map((chat) => _buildTempChatTile(chat)),
      ],
    );
  }

  Widget _buildTempChatTile(Map<String, dynamic> chat) {
    final color = chat['color'] as Color;
    final isAnon = chat['anonymous'] == true;
    final name = isAnon ? 'Anonim Kullanıcı' : (chat['name'] ?? 'Anonim');
    final unread = chat['unread'] as int;
    final hoursLeft = chat['hoursLeft'] as int;
    final timeColor = hoursLeft <= 6 ? AppColors.error : (hoursLeft <= 12 ? AppColors.warning : Colors.white.withOpacity(0.3));

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: chat))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: unread > 0 ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            // Avatar + timer
            Stack(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12), border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
                  child: isAnon
                      ? Icon(Icons.person_rounded, size: 24, color: color.withOpacity(0.5))
                      : Center(child: Text(chat['emoji'] ?? '🧑', style: const TextStyle(fontSize: 24))),
                ),
                // Geri sayım badge
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.bgMain, borderRadius: BorderRadius.circular(8), border: Border.all(color: timeColor, width: 1)),
                    child: Text('${hoursLeft}sa', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: timeColor)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Bilgi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white), overflow: TextOverflow.ellipsis)),
                      if (isAnon) ...[const SizedBox(width: 4), Icon(Icons.visibility_off_rounded, size: 12, color: Colors.white.withOpacity(0.2))],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(chat['lastMessage'] ?? '', style: TextStyle(fontSize: 13, color: unread > 0 ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.35)), overflow: TextOverflow.ellipsis, maxLines: 1),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Sağ taraf
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(chat['time'] ?? '', style: TextStyle(fontSize: 11, color: unread > 0 ? AppColors.primary : Colors.white.withOpacity(0.2))),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: Center(child: Text('$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── DM Chatler (kalıcı) ──
  Widget _buildDmChats() {
    if (_dmChats.isEmpty) {
      return _buildEmptyState(Icons.chat_rounded, 'Henüz mesaj yok', 'Geçici sohbetlerden arkadaş ekleyerek\nkalıcı mesajlaşmaya başla.');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Online arkadaşlar (yatay)
        if (_dmChats.any((c) => c['online'] == true)) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _dmChats.where((c) => c['online'] == true).map((chat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (chat['color'] as Color).withOpacity(0.12),
                                border: Border.all(color: AppColors.success, width: 2),
                              ),
                              child: Center(child: Text(chat['emoji'] ?? '🧑', style: const TextStyle(fontSize: 26))),
                            ),
                            Positioned(
                              bottom: 2, right: 2,
                              child: Container(width: 14, height: 14, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: AppColors.bgMain, width: 2.5))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(chat['name']?.split(' ').first ?? '', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        // Chat listesi
        ..._dmChats.map((chat) => _buildDmChatTile(chat)),
      ],
    );
  }

  Widget _buildDmChatTile(Map<String, dynamic> chat) {
    final color = chat['color'] as Color;
    final unread = chat['unread'] as int? ?? 0;
    final online = chat['online'] == true;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: chat))),
      onLongPress: () => _showChatOptions(chat),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: unread > 0 ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12), border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
                  child: Center(child: Text(chat['emoji'] ?? '🧑', style: const TextStyle(fontSize: 24))),
                ),
                if (online)
                  Positioned(
                    bottom: 2, right: 2,
                    child: Container(width: 14, height: 14, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: AppColors.bgCard, width: 2.5))),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chat['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Mesaj durumu ikonu
                      Icon(Icons.done_all_rounded, size: 14, color: AppColors.modeSosyal.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Flexible(child: Text(chat['lastMessage'] ?? '', style: TextStyle(fontSize: 13, color: unread > 0 ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.35)), overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(chat['time'] ?? '', style: TextStyle(fontSize: 11, color: unread > 0 ? AppColors.primary : Colors.white.withOpacity(0.2))),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: Center(child: Text('$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
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
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.3), height: 1.5)),
          ],
        ),
      ),
    );
  }

  void _showFriendRequests() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('Arkadaş İstekleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 16),
              ..._friendRequests.map((req) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.bgMain.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: (req['color'] as Color).withOpacity(0.15)),
                      child: Center(child: Text(req['emoji'] ?? '🧑', style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(req['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text(req['username'] ?? '', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35))),
                    ])),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Kabul', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                        child: Text('Reddet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.4))),
                      ),
                    ),
                  ],
                ),
              )),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  void _showChatOptions(Map<String, dynamic> chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              _chatOption(Icons.notifications_off_rounded, 'Sessize Al', Colors.white.withOpacity(0.5), () => Navigator.pop(context)),
              _chatOption(Icons.archive_rounded, 'Arşivle', Colors.white.withOpacity(0.5), () => Navigator.pop(context)),
              _chatOption(Icons.delete_rounded, 'Sohbeti Sil', AppColors.error, () { Navigator.pop(context); _showDeleteChatDialog(chat); }),
              _chatOption(Icons.block_rounded, 'Engelle', AppColors.error, () { Navigator.pop(context); _showBlockChatDialog(chat); }),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Widget _chatOption(IconData icon, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.bgMain.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  void _showDeleteChatDialog(Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sohbeti Sil', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
        content: Text('Bu sohbet her iki taraf için de kalıcı olarak silinecek. Bu işlem geri alınamaz.', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Vazgeç', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sil', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  void _showBlockChatDialog(Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Engelle', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${chat['name']} engellenecek:', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            const SizedBox(height: 12),
            _blockInfoRow('Tüm mesajlar her iki tarafta silinir'),
            _blockInfoRow('Karşı taraf seni göremez'),
            _blockInfoRow('Uçtan uca şifreli log yasal süreçler için saklanır'),
            _blockInfoRow('72 saat içinde yedeklerden temizlenir'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.bgMain.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded, size: 14, color: AppColors.primary.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Loglar uçtan uca şifrelidir. Mahkeme kararı olmadan kimse erişemez.', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3), height: 1.4))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Vazgeç', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(onPressed: () { Navigator.pop(context); setState(() => _dmChats.remove(chat)); }, child: const Text('Engelle ve Sil', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _blockInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary.withOpacity(0.5)),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45), height: 1.3))),
        ],
      ),
    );
  }
}