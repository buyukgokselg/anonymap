import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../theme/colors.dart';

/// Display metadata for an [ActivityCategory] — label, icon, and accent color.
///
/// Cesaret has a deliberately warm/intimate accent (primaryGlow) to telegraph
/// its vulnerability-driven UX tone; Anlık uses neonCyan to feel time-pressured.
class ActivityCategoryMeta {
  const ActivityCategoryMeta({
    required this.label,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String subtitle;

  static ActivityCategoryMeta of(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.cesaret:
        return const ActivityCategoryMeta(
          label: 'Cesaret',
          icon: Icons.favorite_rounded,
          color: AppColors.primaryGlow,
          subtitle: 'Açık ol, kırılganlığını paylaş',
        );
      case ActivityCategory.anlik:
        return const ActivityCategoryMeta(
          label: 'Anlık',
          icon: Icons.bolt_rounded,
          color: AppColors.neonCyan,
          subtitle: 'Şimdi bul, şimdi buluş',
        );
      case ActivityCategory.sosyal:
        return const ActivityCategoryMeta(
          label: 'Sosyal',
          icon: Icons.groups_rounded,
          color: AppColors.modeFriends,
          subtitle: 'Yeni insanlarla tanış',
        );
      case ActivityCategory.spor:
        return const ActivityCategoryMeta(
          label: 'Spor',
          icon: Icons.directions_run_rounded,
          color: AppColors.modeAcikAlan,
          subtitle: 'Hareket et, terle',
        );
      case ActivityCategory.sanat:
        return const ActivityCategoryMeta(
          label: 'Sanat',
          icon: Icons.palette_rounded,
          color: AppColors.modeChill,
          subtitle: 'Yarat, izle, dinle',
        );
      case ActivityCategory.egitim:
        return const ActivityCategoryMeta(
          label: 'Eğitim',
          icon: Icons.school_rounded,
          color: AppColors.modeUretkenlik,
          subtitle: 'Birlikte öğren',
        );
      case ActivityCategory.doga:
        return const ActivityCategoryMeta(
          label: 'Doğa',
          icon: Icons.park_rounded,
          color: AppColors.success,
          subtitle: 'Açık havada nefes',
        );
      case ActivityCategory.yemek:
        return const ActivityCategoryMeta(
          label: 'Yemek',
          icon: Icons.restaurant_rounded,
          color: AppColors.modeFun,
          subtitle: 'Yemek paylaş, sohbet et',
        );
      case ActivityCategory.gece:
        return const ActivityCategoryMeta(
          label: 'Gece',
          icon: Icons.nightlife_rounded,
          color: AppColors.accentLight,
          subtitle: 'Çık, dans et, eğlen',
        );
      case ActivityCategory.seyahat:
        return const ActivityCategoryMeta(
          label: 'Seyahat',
          icon: Icons.flight_takeoff_rounded,
          color: AppColors.modeAlisveris,
          subtitle: 'Yola çık, keşfet',
        );
      case ActivityCategory.other:
        return const ActivityCategoryMeta(
          label: 'Diğer',
          icon: Icons.local_activity_rounded,
          color: AppColors.textSecondary,
          subtitle: '',
        );
    }
  }
}
