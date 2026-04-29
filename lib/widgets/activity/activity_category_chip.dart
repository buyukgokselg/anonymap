import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../theme/colors.dart';
import '../animated_press.dart';
import 'activity_category_meta.dart';

/// Compact pill chip for showing an activity category. Two variants:
/// - [ActivityCategoryChipVariant.tag]: small read-only chip on cards.
/// - [ActivityCategoryChipVariant.filter]: larger tappable chip used in
///   filter bars / category pickers; renders a selected state when [selected]
///   is true.
enum ActivityCategoryChipVariant { tag, filter }

class ActivityCategoryChip extends StatelessWidget {
  const ActivityCategoryChip({
    super.key,
    required this.category,
    this.variant = ActivityCategoryChipVariant.tag,
    this.selected = false,
    this.onTap,
  });

  final ActivityCategory category;
  final ActivityCategoryChipVariant variant;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = ActivityCategoryMeta.of(category);

    switch (variant) {
      case ActivityCategoryChipVariant.tag:
        return _buildTag(meta);
      case ActivityCategoryChipVariant.filter:
        return AnimatedPress(
          onTap: onTap,
          child: _buildFilter(meta),
        );
    }
  }

  Widget _buildTag(ActivityCategoryMeta meta) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: meta.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 12, color: meta.color),
          const SizedBox(width: 5),
          Text(
            meta.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: meta.color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter(ActivityCategoryMeta meta) {
    final accent = meta.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.22)
            : AppColors.bgChip.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.06),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
              ]
            : const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            meta.icon,
            size: 16,
            color: selected ? accent : Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 7),
          Text(
            meta.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? accent : Colors.white.withValues(alpha: 0.85),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
