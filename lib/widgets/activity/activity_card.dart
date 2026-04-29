import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../theme/colors.dart';
import '../animated_press.dart';
import 'activity_category_chip.dart';
import 'activity_category_meta.dart';
import 'activity_countdown_pill.dart';
import 'activity_join_button.dart';
import 'participant_avatar_stack.dart';

/// Main feed/list card for an activity. Tapping the body opens detail; the
/// join CTA is its own tap-target.
///
/// Layout (top → bottom):
///   • Cover image (or category-color gradient if no image)
///   • Category chip + status pill (cancelled/full/dolu) overlay
///   • Title
///   • Host row (avatar + name + "düzenliyor")
///   • Time row (gün + saat) — short, friendly format
///   • Location row (icon + name)
///   • Participants row (avatar stack + N/M sayısı)
///   • Action row: optional secondary text + JoinButton
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.onJoin,
    this.onLeave,
    this.onCancelRequest,
    this.actionLoading = false,
    this.showCategory = true,
    this.showCover = true,
  });

  final ActivityModel activity;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final VoidCallback? onCancelRequest;
  final bool actionLoading;
  final bool showCategory;
  final bool showCover;

  @override
  Widget build(BuildContext context) {
    final meta = ActivityCategoryMeta.of(activity.category);

    return AnimatedPress(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activity.isCancelled
                ? AppColors.error.withValues(alpha: 0.3)
                : meta.color.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showCover) _buildCover(meta),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!showCover && showCategory)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ActivityCategoryChip(category: activity.category),
                    ),
                  Text(
                    activity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildHostRow(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          icon: Icons.schedule_rounded,
                          text: _formatWhen(activity.startsAt, activity.endsAt),
                          color: AppColors.neonCyan,
                        ),
                      ),
                      if (activity.isRecurring) ...[
                        const SizedBox(width: 6),
                        _recurrenceBadge(activity.recurrenceRule),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                    icon: Icons.location_on_rounded,
                    text: activity.locationName.isNotEmpty
                        ? activity.locationName
                        : activity.city,
                    color: AppColors.modeFun,
                  ),
                  const SizedBox(height: 14),
                  _buildFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(ActivityCategoryMeta meta) {
    final cover = activity.coverImageUrl;
    return Stack(
      children: [
        SizedBox(
          height: 120,
          width: double.infinity,
          child: cover != null && cover.isNotEmpty
              ? Image.network(
                  cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => _gradientBackground(meta),
                )
              : _gradientBackground(meta),
        ),
        // Bottom shadow for readability if we ever overlay text on cover
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),
        if (showCategory)
          Positioned(
            top: 12,
            left: 12,
            child: ActivityCategoryChip(category: activity.category),
          ),
        if (activity.isCancelled || activity.isFull)
          Positioned(
            top: 12,
            right: 12,
            child: _statusPill(),
          )
        else if (activity.category == ActivityCategory.anlik)
          Positioned(
            top: 12,
            right: 12,
            child: ActivityCountdownPill(
              startsAt: activity.startsAt,
              endsAt: activity.endsAt,
              compact: true,
              color: meta.color,
            ),
          ),
      ],
    );
  }

  Widget _gradientBackground(ActivityCategoryMeta meta) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            meta.color.withValues(alpha: 0.55),
            AppColors.bgCard,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          meta.icon,
          size: 48,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  Widget _statusPill() {
    final isCancelled = activity.isCancelled;
    final color = isCancelled ? AppColors.error : AppColors.warning;
    final label = isCancelled ? 'İptal' : 'Dolu';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _recurrenceBadge(String rule) {
    final label = switch (rule) {
      'weekly' => 'Haftalık',
      'biweekly' => '2 hafta',
      'monthly' => 'Aylık',
      _ => 'Tekrarlı',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.neonCyan.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.replay_rounded,
            color: AppColors.neonCyan,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostRow() {
    final url = activity.hostPhotoUrl;
    final name = activity.hostDisplayName.isEmpty
        ? 'Anonim'
        : activity.hostDisplayName;

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.bgChip,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null && url.isNotEmpty
              ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, e, s) {
                  return const Icon(
                    Icons.person_rounded,
                    color: AppColors.textHint,
                    size: 14,
                  );
                })
              : const Icon(
                  Icons.person_rounded,
                  color: AppColors.textHint,
                  size: 14,
                ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(
                  text: '  düzenliyor',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final cap = activity.maxParticipants;
    final cur = activity.currentParticipantCount;
    final countLabel = cap == null ? '$cur kişi' : '$cur / $cap';

    return Row(
      children: [
        ParticipantAvatarStack(
          users: activity.sampleParticipants,
          totalCount: activity.currentParticipantCount,
          avatarSize: 26,
          maxVisible: 3,
          borderColor: AppColors.bgCard,
        ),
        const SizedBox(width: 10),
        Text(
          countLabel,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        ActivityJoinButton(
          activity: activity,
          onJoin: onJoin,
          onLeave: onLeave,
          onCancelRequest: onCancelRequest,
          loading: actionLoading,
          compact: true,
        ),
      ],
    );
  }

  static String _formatWhen(DateTime startsAt, DateTime? endsAt) {
    final local = startsAt.toLocal();
    final now = DateTime.now();
    final isSameDay =
        now.year == local.year && now.month == local.month && now.day == local.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = tomorrow.year == local.year &&
        tomorrow.month == local.month &&
        tomorrow.day == local.day;

    String day;
    if (isSameDay) {
      day = 'Bugün';
    } else if (isTomorrow) {
      day = 'Yarın';
    } else {
      day = '${local.day}.${local.month.toString().padLeft(2, '0')}';
      const weekdayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      day = '${weekdayLabels[local.weekday - 1]} $day';
    }

    final time =
        '${local.hour.toString().padLeft(2, '0')}.${local.minute.toString().padLeft(2, '0')}';
    if (endsAt != null) {
      final end = endsAt.toLocal();
      final endTime =
          '${end.hour.toString().padLeft(2, '0')}.${end.minute.toString().padLeft(2, '0')}';
      return '$day · $time → $endTime';
    }
    return '$day · $time';
  }
}
