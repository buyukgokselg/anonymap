import 'package:flutter/material.dart';

import '../../../theme/colors.dart';

/// Kayıt wizard'ı için üstte görünen ince ilerleme çubuğu.
///
/// `OnboardingScreen` ile aynı görsel dili kullanır: tamamlanmış adımlar
/// primary renkte ve hafif glow ile, kalan adımlar koyu kart renginde.
/// Welcome (0) ve success (totalSteps-1) adımlarında gizlenir; sadece
/// "iş yapılan" adımlarda kullanıcı ilerleme hissi alır.
class RegisterProgressBar extends StatelessWidget {
  const RegisterProgressBar({
    super.key,
    required this.currentIndex,
    required this.totalSteps,
  });

  /// 0-tabanlı sayfa indeksi (PageView ile aynı).
  final int currentIndex;

  /// Toplam sayfa sayısı (welcome ve success dâhil).
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    // Welcome ve success ekranlarında bar boş alan kaplamasın.
    final isFirstOrLast = currentIndex == 0 || currentIndex == totalSteps - 1;
    if (isFirstOrLast) {
      return const SizedBox(height: 3);
    }

    // Welcome'ı saymıyoruz: ortadaki "iş ekranları" 1..(total-2).
    final workingSteps = totalSteps - 2;
    final progressedIndex = currentIndex - 1; // 0..workingSteps-1

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
      child: Row(
        children: List.generate(workingSteps, (i) {
          final reached = i <= progressedIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: EdgeInsets.only(right: i < workingSteps - 1 ? 6 : 0),
              height: 3,
              decoration: BoxDecoration(
                color: reached ? AppColors.primary : AppColors.bgCard,
                borderRadius: BorderRadius.circular(2),
                boxShadow: reached
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
