import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../models/activity_rating_model.dart';
import '../../services/activity_service.dart';
import '../../theme/colors.dart';
import '../animated_press.dart';
import 'activity_rating_sheet.dart';

/// Shows the existing ratings for a past activity + a "Puanla" CTA when the
/// caller still has rateable counterparts. Only renders for activities that
/// have started.
class ActivityRatingsPanel extends StatefulWidget {
  const ActivityRatingsPanel({super.key, required this.activity});

  final ActivityModel activity;

  @override
  State<ActivityRatingsPanel> createState() => _ActivityRatingsPanelState();
}

class _ActivityRatingsPanelState extends State<ActivityRatingsPanel> {
  ActivityRatingListResponse? _ratings;
  List<ActivityRatingUser> _rateable = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ActivityService.instance.listRatings(widget.activity.id),
        ActivityService.instance.listPendingRatings(),
      ]);
      if (!mounted) return;
      final ratings = results[0] as ActivityRatingListResponse;
      final pending = results[1] as PendingRatingListResponse;
      final myEntry = pending.items
          .where((g) => g.activity.id == widget.activity.id)
          .toList();
      setState(() {
        _ratings = ratings;
        _rateable = myEntry.isEmpty ? const [] : myEntry.first.rateableUsers;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSheet(ActivityRatingUser target) async {
    final ok = await ActivityRatingSheet.show(
      context,
      activity: widget.activity,
      target: target,
    );
    if (ok == true) {
      // Optimistically drop from rateable & schedule a refresh for canonical
      // average/count.
      if (mounted) {
        setState(() {
          _rateable = _rateable
              .where((u) => u.id != target.id)
              .toList(growable: false);
        });
      }
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratings = _ratings;
    final hasContent =
        (ratings != null && (ratings.count > 0 || _rateable.isNotEmpty));
    if (_loading && ratings == null) {
      return _shell(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
        ),
      );
    }
    if (_error != null && ratings == null) {
      return _shell(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _load,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }
    if (!hasContent) return const SizedBox.shrink();
    // Past the early-returns above, hasContent==true guarantees ratings != null.
    final r = ratings;
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummary(r),
          if (_rateable.isNotEmpty) _buildRateableSection(),
          if (r.items.isNotEmpty) _buildRatingsList(r.items),
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }

  Widget _buildSummary(ActivityRatingListResponse ratings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning.withValues(alpha: 0.6),
                  AppColors.warning.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Etkinlik puanları',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ratings.count == 0
                      ? 'Henüz puanlama yapılmadı.'
                      : 'Ortalama ${ratings.average.toStringAsFixed(1)} '
                            '· ${ratings.count} puan',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateableSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Senden bekleyen puanlar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          ..._rateable.map(_buildRateableRow),
        ],
      ),
    );
  }

  Widget _buildRateableRow(ActivityRatingUser target) {
    final photo = target.profilePhotoUrl;
    return AnimatedPress(
      onTap: () => _openSheet(target),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 32,
                height: 32,
                child: photo != null && photo.isNotEmpty
                    ? Image.network(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => _initials(target),
                      )
                    : _initials(target),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                target.displayName.isEmpty
                    ? target.userName
                    : target.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryGlow],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Puanla',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initials(ActivityRatingUser target) {
    final name = target.displayName.isEmpty
        ? target.userName
        : target.displayName;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      color: AppColors.bgSurface,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildRatingsList(List<ActivityRatingModel> items) {
    final preview = items.take(3).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Son geri bildirimler',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          ...preview.map(_buildRatingTile),
          if (items.length > preview.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${items.length - preview.length} daha',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingTile(ActivityRatingModel rating) {
    final raterName = rating.rater.displayName.isEmpty
        ? rating.rater.userName
        : rating.rater.displayName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$raterName → ${rating.rated.displayName.isEmpty ? rating.rated.userName : rating.rated.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = (i + 1) <= rating.score;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 13,
                    color: filled
                        ? AppColors.warning
                        : AppColors.textHint.withValues(alpha: 0.6),
                  );
                }),
              ),
            ],
          ),
          if (rating.comment != null && rating.comment!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                rating.comment!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
