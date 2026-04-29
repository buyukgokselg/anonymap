import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/pulse_api_service.dart';
import '../theme/colors.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

/// Dating-app "Matches" screen with two tabs:
///   1. "Eşleşmeler" — mutual (accepted) matches that open the auto-created
///      direct chat on tap.
///   2. "Beni Beğenenler" — pending incoming likes; tap a row to view the
///      liker's profile, accept (opens chat), or pass.
///
/// The pending tab is backed by `GET /api/matches/likes-me`, which returns a
/// projected `LikesMeEntryDto` (liker summary + compat + common interests),
/// avoiding the heavier full-match payload used elsewhere.
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  static const int _likesMePageLimit = 20;

  final _api = PulseApiService.instance;
  late final TabController _tabController;

  List<Map<String, dynamic>> _accepted = [];
  List<Map<String, dynamic>> _likesMe = [];
  int _likesMeTotalCount = 0;
  bool _likesMeHasMore = false;

  bool _loading = true;
  String? _errorMessage;

  String get _myUid => AuthService().currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _api.getAllMatches(),
        _api.getLikesMe(limit: _likesMePageLimit),
      ]);
      if (!mounted) return;
      final all = results[0] as List<Map<String, dynamic>>;
      final likesMe = results[1] as Map<String, dynamic>;
      final accepted = all
          .where((m) => (m['status'] ?? '').toString() == 'accepted')
          .toList();
      final items = (likesMe['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      setState(() {
        _accepted = accepted;
        _likesMe = items;
        _likesMeTotalCount = (likesMe['totalCount'] as int?) ?? items.length;
        _likesMeHasMore = (likesMe['hasMore'] as bool?) ?? false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Map<String, dynamic>? _otherUserOfAccepted(Map<String, dynamic> match) {
    final user1 = match['user1'];
    final user2 = match['user2'];
    final user1Id = user1 is Map ? (user1['id'] ?? '').toString() : '';
    if (user1Id == _myUid) {
      return user2 is Map ? Map<String, dynamic>.from(user2) : null;
    }
    return user1 is Map ? Map<String, dynamic>.from(user1) : null;
  }

  Future<void> _respondToLike(
    Map<String, dynamic> entry,
    bool accept,
  ) async {
    final matchId = (entry['matchId'] ?? '').toString();
    if (matchId.isEmpty) return;

    // Optimistic removal so the row disappears immediately while the network
    // call is in flight; we restore it if the server rejects the response.
    final removedIndex = _likesMe.indexWhere(
      (item) => (item['matchId'] ?? '').toString() == matchId,
    );
    if (removedIndex >= 0) {
      setState(() {
        _likesMe = List.of(_likesMe)..removeAt(removedIndex);
        _likesMeTotalCount =
            _likesMeTotalCount > 0 ? _likesMeTotalCount - 1 : 0;
      });
    }

    final ok = await _api.respondToMatch(
      matchId,
      status: accept ? 'accepted' : 'declined',
    );
    if (!mounted) return;

    if (!ok) {
      // Roll back the optimistic removal.
      if (removedIndex >= 0) {
        setState(() {
          _likesMe = List.of(_likesMe)..insert(removedIndex, entry);
          _likesMeTotalCount += 1;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.phrase('İşlem tamamlanamadı')),
        ),
      );
      return;
    }

    if (accept) {
      // Refetch accepted list so we get the server-assigned chatId, then jump
      // straight into the chat for the newly-accepted match.
      try {
        final all = await _api.getAllMatches();
        if (!mounted) return;
        final accepted = all
            .where((m) => (m['status'] ?? '').toString() == 'accepted')
            .toList();
        setState(() => _accepted = accepted);
        final fresh = accepted.firstWhere(
          (m) => (m['id'] ?? '').toString() == matchId,
          orElse: () => const {},
        );
        if (fresh.isNotEmpty) _openChat(fresh);
      } catch (_) {
        // Non-fatal — user can pull to refresh.
      }
    }
  }

  void _openChat(Map<String, dynamic> match) {
    final other = _otherUserOfAccepted(match);
    if (other == null) return;
    final chatId = (match['chatId'] ?? '').toString();
    if (chatId.isEmpty) return;
    final displayName = (other['displayName'] ?? '').toString();
    final userName = (other['userName'] ?? '').toString();
    final bio = (other['bio'] ?? '').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          user: {
            'uid': (other['id'] ?? '').toString(),
            'chatId': chatId,
            'name': displayName.isEmpty ? userName : displayName,
            'username': '@$userName',
            'bio': bio,
            'isTemporary': false,
          },
        ),
      ),
    );
  }

  void _openLikerProfile(Map<String, dynamic> entry) {
    final liker = entry['liker'];
    if (liker is! Map) return;
    final userId = (liker['id'] ?? '').toString();
    if (userId.isEmpty) return;
    final compatibility = entry['compatibility'] is num
        ? (entry['compatibility'] as num).toInt()
        : null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userId: userId,
          compatibilityScore: compatibility,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final likesMeBadge = _likesMeTotalCount > _likesMe.length
        ? '$_likesMeTotalCount+'
        : '${_likesMe.length}';
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        title: Text(l10n.phrase('Eşleşmeler')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.modeFlirt,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: '${l10n.phrase('Eşleşmeler')} (${_accepted.length})'),
            Tab(text: '${l10n.phrase('Beni Beğenenler')} ($likesMeBadge)'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.modeFlirt),
            )
          : _errorMessage != null
              ? _buildError(l10n)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAcceptedList(l10n),
                    _buildLikesMeList(l10n),
                  ],
                ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: AppColors.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(
              l10n.phrase('Eşleşmeler yüklenemedi'),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _load,
              child: Text(l10n.phrase('Tekrar dene')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedList(AppLocalizations l10n) {
    if (_accepted.isEmpty) {
      return _buildEmpty(
        icon: Icons.favorite_rounded,
        text: l10n.phrase('Henüz eşleşmen yok. Keşfet ve sağa kaydırmayı dene.'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.modeFlirt,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _accepted.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final match = _accepted[index];
          final other = _otherUserOfAccepted(match);
          return _matchTile(
            displayName: (other?['displayName'] ?? '').toString(),
            userName: (other?['userName'] ?? '').toString(),
            photoUrl: (other?['profilePhotoUrl'] ?? '').toString(),
            compatibility: match['compatibility'] is num
                ? (match['compatibility'] as num).toInt()
                : 0,
            commonInterestsCount:
                (match['commonInterests'] as List? ?? const []).length,
            trailing: const Icon(
              Icons.chat_rounded,
              color: AppColors.modeFlirt,
              size: 20,
            ),
            onTap: () => _openChat(match),
          );
        },
      ),
    );
  }

  Widget _buildLikesMeList(AppLocalizations l10n) {
    if (_likesMe.isEmpty) {
      return _buildEmpty(
        icon: Icons.favorite_border_rounded,
        text: l10n.phrase(
          'Henüz seni beğenen yok. Keşfet ve daha fazla profile bak.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.modeFlirt,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        itemCount: _likesMe.length + (_likesMeHasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          if (index >= _likesMe.length) {
            return _buildHasMoreFooter(l10n);
          }
          final entry = _likesMe[index];
          final liker = entry['liker'] is Map
              ? Map<String, dynamic>.from(entry['liker'] as Map)
              : <String, dynamic>{};
          final commonInterests =
              (entry['commonInterests'] as List? ?? const []).cast<dynamic>();
          return _matchTile(
            displayName: (liker['displayName'] ?? '').toString(),
            userName: (liker['userName'] ?? '').toString(),
            photoUrl: (liker['profilePhotoUrl'] ?? '').toString(),
            compatibility: entry['compatibility'] is num
                ? (entry['compatibility'] as num).toInt()
                : 0,
            commonInterestsCount: commonInterests.length,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: l10n.phrase('Geç'),
                  onPressed: () => _respondToLike(entry, false),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.modeFlirt,
                  ),
                  tooltip: l10n.phrase('Eşleş'),
                  onPressed: () => _respondToLike(entry, true),
                ),
              ],
            ),
            onTap: () => _openLikerProfile(entry),
          );
        },
      ),
    );
  }

  Widget _buildHasMoreFooter(AppLocalizations l10n) {
    final remaining =
        (_likesMeTotalCount - _likesMe.length).clamp(0, _likesMeTotalCount);
    if (remaining <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Center(
        child: Text(
          '+$remaining ${l10n.phrase('kişi daha seni beğendi')}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty({required IconData icon, required String text}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchTile({
    required String displayName,
    required String userName,
    required String photoUrl,
    required int compatibility,
    required int commonInterestsCount,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final shownName = displayName.isEmpty ? userName : displayName;
    final initial = shownName.isEmpty
        ? '?'
        : shownName.characters
            .firstWhere((_) => true, orElse: () => '?')
            .toUpperCase();
    final subtitleParts = <String>[];
    if (compatibility > 0) subtitleParts.add('%$compatibility');
    if (commonInterestsCount > 0) {
      subtitleParts.add('$commonInterestsCount ortak ilgi');
    }
    if (subtitleParts.isEmpty && userName.isNotEmpty) {
      subtitleParts.add('@$userName');
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.bgCard,
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shownName.isEmpty ? '—' : shownName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
