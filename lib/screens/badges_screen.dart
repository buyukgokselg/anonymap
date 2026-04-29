import 'dart:async';

import 'package:flutter/material.dart';

import '../models/badge_model.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';
import '../theme/colors.dart';
import '../widgets/animated_press.dart';

/// Bir kullanıcının (varsayılan: caller) tüm rozetlerini grid + ilerleme
/// barlarıyla gösterir. Kazanılmış rozetler renkli, kazanılmamışlar grilenmiş
/// olarak listelenir; karta basınca alt sayfada detay açılır.
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key, this.userId, this.title});

  /// Hangi kullanıcının rozetleri gösterilecek; null/empty → caller (me).
  final String? userId;

  /// AppBar başlığı; null ise default başlık ("Rozetlerim" / "Rozetler").
  final String? title;

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  bool _loading = true;
  String? _error;
  BadgeCatalogResponse? _catalog;
  UserBadgesResponse? _userBadges;

  bool get _isSelf {
    final uid = widget.userId;
    if (uid == null || uid.isEmpty) return true;
    return uid == AuthService().currentUserId;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = BadgeService.instance;
      final catalogFuture = svc.getCatalog();
      final userBadgesFuture = _isSelf
          ? svc.getMine()
          : svc.getForUser(widget.userId!);
      final results = await Future.wait([catalogFuture, userBadgesFuture]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0] as BadgeCatalogResponse?;
        _userBadges = (results[1] as UserBadgesResponse?) ??
            UserBadgesResponse.empty();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        title: Text(
          widget.title ?? (_isSelf ? 'Rozetlerim' : 'Rozetler'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.bgCard,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _userBadges == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null && _userBadges == null) {
      return _buildErrorState();
    }

    final catalog = _catalog;
    final userBadges = _userBadges ?? UserBadgesResponse.empty();
    if (catalog == null || catalog.items.isEmpty) {
      return _buildEmptyState();
    }

    final byCode = catalog.byCode;
    final earned = userBadges.items.where((b) => b.earned).toList();
    final locked = userBadges.items.where((b) => !b.earned).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(userBadges, catalog.items.length),
        ),
        if (earned.isNotEmpty) ...[
          _buildSectionHeader('Kazanıldı', earned.length),
          _buildGrid(earned, byCode),
        ],
        if (locked.isNotEmpty) ...[
          _buildSectionHeader('Henüz kilitli', locked.length),
          _buildGrid(locked, byCode),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildHeader(UserBadgesResponse summary, int totalInCatalog) {
    final earned = summary.earnedCount;
    final total = summary.totalCount > 0 ? summary.totalCount : totalInCatalog;
    final ratio = total == 0 ? 0.0 : (earned / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(64),
            AppColors.primaryGlow.withAlpha(38),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.primaryGlow,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSelf ? 'Yolculuğun' : 'Bu profilin rozetleri',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$earned / $total rozet kazanıldı',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
                  color: AppColors.primary.withAlpha(56),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '%${(ratio * 100).round()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white.withAlpha(20),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryGlow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(String label, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgChip,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverPadding _buildGrid(
    List<UserBadge> badges,
    Map<String, BadgeDefinition> byCode,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final ub = badges[index];
            final def = byCode[ub.code];
            if (def == null) return const SizedBox.shrink();
            return _BadgeCard(
              definition: def,
              userBadge: ub,
              onTap: () => _showDetail(def, ub),
            );
          },
          childCount: badges.length,
        ),
      ),
    );
  }

  void _showDetail(BadgeDefinition def, UserBadge ub) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _BadgeDetailSheet(definition: def, userBadge: ub),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Icon(
          Icons.emoji_events_outlined,
          size: 72,
          color: AppColors.textHint,
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Rozet kataloğu yüklenemedi',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.textHint),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _error ?? 'Rozetler yüklenemedi',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.definition,
    required this.userBadge,
    required this.onTap,
  });

  final BadgeDefinition definition;
  final UserBadge userBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final earned = userBadge.earned;
    final accent = _parseHex(definition.color);
    final tierLabel = userBadge.tierLabel;
    final iconData = badgeIcon(definition.iconKey);
    final progressRatio = userBadge.progressRatio(definition);

    return AnimatedPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: earned
                ? accent.withAlpha(110)
                : Colors.white.withAlpha(14),
          ),
          gradient: earned
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withAlpha(60),
                    AppColors.bgCard.withAlpha(0),
                  ],
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: earned
                        ? accent.withAlpha(64)
                        : Colors.white.withAlpha(10),
                    border: Border.all(
                      color: earned
                          ? accent.withAlpha(140)
                          : Colors.white.withAlpha(24),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    iconData,
                    size: 26,
                    color: earned ? accent : AppColors.textHint,
                  ),
                ),
                if (earned && tierLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(70),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tierLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: AppColors.textHint,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              definition.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: earned ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                definition.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressRatio,
                minHeight: 5,
                backgroundColor: Colors.white.withAlpha(16),
                valueColor: AlwaysStoppedAnimation<Color>(
                  earned ? accent : AppColors.textHint,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _progressLabel(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _progressLabel() {
    if (userBadge.nextThreshold == null) {
      return 'Maksimum tier';
    }
    return '${userBadge.progress} / ${userBadge.nextThreshold}';
  }
}

class _BadgeDetailSheet extends StatelessWidget {
  const _BadgeDetailSheet({required this.definition, required this.userBadge});

  final BadgeDefinition definition;
  final UserBadge userBadge;

  @override
  Widget build(BuildContext context) {
    final accent = _parseHex(definition.color);
    final earned = userBadge.earned;
    final tierLabel = userBadge.tierLabel;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: earned
                        ? accent.withAlpha(70)
                        : Colors.white.withAlpha(10),
                    border: Border.all(
                      color: earned
                          ? accent.withAlpha(160)
                          : Colors.white.withAlpha(24),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    badgeIcon(definition.iconKey),
                    size: 34,
                    color: earned ? accent : AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        definition.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (earned && tierLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(70),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tierLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Henüz kilitli',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              definition.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _buildTiers(accent),
          ],
        ),
      ),
    );
  }

  Widget _buildTiers(Color accent) {
    final thresholds = definition.tierThresholds;
    if (thresholds.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İlerleme',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < thresholds.length; i++) _buildTierRow(i, accent),
      ],
    );
  }

  Widget _buildTierRow(int tierIndex, Color accent) {
    final earnedHere = userBadge.tier > tierIndex;
    final threshold = definition.tierThresholds[tierIndex];
    final tierName = _tierNameFor(tierIndex + 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earnedHere
                  ? accent.withAlpha(160)
                  : Colors.white.withAlpha(14),
              border: Border.all(
                color: earnedHere
                    ? accent
                    : Colors.white.withAlpha(40),
              ),
            ),
            child: Icon(
              earnedHere ? Icons.check_rounded : Icons.lock_outline_rounded,
              size: 12,
              color: earnedHere ? Colors.white : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tierName,
              style: TextStyle(
                color: earnedHere ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$threshold',
            style: TextStyle(
              color: earnedHere ? accent : AppColors.textHint,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _tierNameFor(int tier) {
    switch (tier) {
      case 1:
        return 'Bronze';
      case 2:
        return 'Silver';
      case 3:
        return 'Gold';
      case 4:
        return 'Platinum';
    }
    return 'Tier $tier';
  }
}

/// Backend'den gelen iconKey değerlerini Material ikonlarına eşler.
IconData badgeIcon(String key) {
  switch (key) {
    case 'host':
    case 'event':
      return Icons.celebration_rounded;
    case 'social':
    case 'group':
      return Icons.groups_rounded;
    case 'rated':
    case 'star':
      return Icons.star_rounded;
    case 'verified':
    case 'shield':
      return Icons.verified_rounded;
    case 'pioneer':
    case 'flag':
      return Icons.flag_rounded;
    case 'connector':
    case 'people':
      return Icons.diversity_3_rounded;
    case 'fire':
      return Icons.local_fire_department_rounded;
    case 'sparkle':
      return Icons.auto_awesome_rounded;
  }
  return Icons.emoji_events_rounded;
}

Color _parseHex(String value) {
  var hex = value.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return AppColors.primaryGlow;
  return Color(parsed);
}
