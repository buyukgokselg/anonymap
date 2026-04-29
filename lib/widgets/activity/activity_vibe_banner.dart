import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import 'activity_category_meta.dart';

/// Soft, full-width banner that telegraphs the *tone* of a category to the
/// host while they're creating an activity, and to viewers on the detail
/// screen for sensitive categories (Cesaret, Anlık).
///
/// For Cesaret it explicitly invites vulnerability and sets expectations
/// around verification + low-pressure responses. For Anlık it nudges hosts
/// to give a clear time horizon ("önümüzdeki 2 saat içinde").
class ActivityVibeBanner extends StatelessWidget {
  const ActivityVibeBanner({super.key, required this.category});

  final ActivityCategory category;

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(category);
    if (copy == null) return const SizedBox.shrink();

    final meta = ActivityCategoryMeta.of(category);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            meta.color.withValues(alpha: 0.18),
            meta.color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: meta.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: meta.color.withValues(alpha: 0.45)),
            ),
            alignment: Alignment.center,
            child: Icon(meta.icon, color: meta.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.title,
                  style: TextStyle(
                    color: meta.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  copy.body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _VibeCopy? _copyFor(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.cesaret:
        return const _VibeCopy(
          title: 'Cesaret modunda',
          body: 'Burada kendin gibi olmak güvenli. Yargı yok, baskı yok. '
              'Onay isteme aç, doğrulanmış katılımcı seç — kendini koru.',
        );
      case ActivityCategory.anlik:
        return const _VibeCopy(
          title: 'Anlık etkinlik',
          body: 'Önümüzdeki birkaç saat içinde başlasın. Konum net olsun, '
              'plan kısa olsun — herkes anında karar versin.',
        );
      default:
        return null;
    }
  }
}

class _VibeCopy {
  const _VibeCopy({required this.title, required this.body});
  final String title;
  final String body;
}
