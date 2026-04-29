import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/badge_model.dart';
import '../../screens/badges_screen.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../theme/colors.dart';
import '../animated_press.dart';

/// Profile sayfası için kompakt rozet rayı.
///
/// Kullanıcının kazandığı rozetlerin yatay önizlemesi + "Tümünü gör" CTA.
/// Hiç rozet kazanılmamışsa bile kataloğun ilk kilitli rozetlerini gri olarak
/// gösterir, böylece keşfedilebilirlik korunur.
class BadgesProfileRail extends StatefulWidget {
  const BadgesProfileRail({
    super.key,
    required this.userId,
    required this.isOwnProfile,
    this.maxItems = 6,
  });

  final String userId;
  final bool isOwnProfile;
  final int maxItems;

  @override
  State<BadgesProfileRail> createState() => _BadgesProfileRailState();
}

class _BadgesProfileRailState extends State<BadgesProfileRail> {
  bool _loading = true;
  BadgeCatalogResponse? _catalog;
  UserBadgesResponse? _userBadges;

  bool get _isSelf {
    if (widget.userId.isEmpty) return widget.isOwnProfile;
    return widget.userId == AuthService().currentUserId;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant BadgesProfileRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final svc = BadgeService.instance;
    final results = await Future.wait<dynamic>([
      svc.getCatalog(),
      _isSelf ? svc.getMine() : svc.getForUser(widget.userId),
    ]);
    if (!mounted) return;
    setState(() {
      _catalog = results[0] as BadgeCatalogResponse?;
      _userBadges = (results[1] as UserBadgesResponse?) ??
          UserBadgesResponse.empty();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final user = _userBadges;
    if (_loading && (catalog == null || user == null)) {
      return _buildLoading();
    }
    if (catalog == null || catalog.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = user?.items ?? const <UserBadge>[];
    final earned = items.where((b) => b.earned).toList();
    final locked = items.where((b) => !b.earned).toList();
    final preview = [...earned, ...locked].take(widget.maxItems).toList();
    if (preview.isEmpty) return const SizedBox.shrink();

    final byCode = catalog.byCode;
    final earnedCount = earned.length;
    final totalCount = (user?.totalCount ?? catalog.items.length);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(earnedCount, totalCount),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: preview.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final ub = preview[i];
                final def = byCode[ub.code];
                if (def == null) return const SizedBox.shrink();
                return _BadgeChip(definition: def, userBadge: ub);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int earned, int total) {
    return Row(
      children: [
        const Icon(
          Icons.emoji_events_rounded,
          color: AppColors.primaryGlow,
          size: 18,
        ),
        const SizedBox(width: 6),
        const Text(
          'Rozetler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.bgChip,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$earned / $total',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        AnimatedPress(
          onTap: _openAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Text(
                  _isSelf ? 'Tümünü gör' : 'Hepsi',
                  style: const TextStyle(
                    color: AppColors.primaryGlow,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primaryGlow,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openAll() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BadgesScreen(
          userId: _isSelf ? null : widget.userId,
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(14)),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.definition, required this.userBadge});

  final BadgeDefinition definition;
  final UserBadge userBadge;

  @override
  Widget build(BuildContext context) {
    final earned = userBadge.earned;
    final accent = _parseHex(definition.color);
    final tierLabel = userBadge.tierLabel;

    return Container(
      width: 92,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: earned ? accent.withAlpha(120) : Colors.white.withAlpha(14),
        ),
        gradient: earned
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withAlpha(56),
                  AppColors.bgCard.withAlpha(0),
                ],
              )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned
                  ? accent.withAlpha(70)
                  : Colors.white.withAlpha(10),
              border: Border.all(
                color: earned
                    ? accent.withAlpha(160)
                    : Colors.white.withAlpha(28),
                width: 1.4,
              ),
            ),
            child: Icon(
              badgeIcon(definition.iconKey),
              size: 19,
              color: earned ? accent : AppColors.textHint,
            ),
          ),
          Text(
            definition.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: earned ? Colors.white : AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (earned && tierLabel.isNotEmpty)
            Text(
              tierLabel,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            )
          else
            const Icon(
              Icons.lock_rounded,
              size: 11,
              color: AppColors.textHint,
            ),
        ],
      ),
    );
  }
}

Color _parseHex(String value) {
  var hex = value.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return AppColors.primaryGlow;
  return Color(parsed);
}
