import 'package:flutter/material.dart';
import 'colors.dart';
import 'spacing.dart';

class AppDecorations {
  static BoxDecoration card = BoxDecoration(
    color: AppColors.bgCard,
    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
  );

  static BoxDecoration cardHighlight = BoxDecoration(
    color: AppColors.bgCard,
    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
  );

  static BoxDecoration surface = BoxDecoration(
    color: AppColors.bgSurface,
    borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
  );

  static BoxDecoration chip = BoxDecoration(
    color: AppColors.bgChip,
    borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
  );

  static BoxDecoration sheet = BoxDecoration(
    color: AppColors.bgCard,
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppSpacing.sheetRadius),
    ),
  );

  static BoxDecoration inputField = BoxDecoration(
    color: AppColors.bgMain,
    borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
  );
}
