import 'package:flutter/material.dart';

import '../../../localization/app_localizations.dart';
import '../../../models/registration_draft.dart';
import '../../../theme/colors.dart';
import '../widgets/register_step_scaffold.dart';
import '../widgets/selectable_card.dart';

/// Adım 3: Cinsiyet seçimi.
///
/// 3 büyük tap-tile (Kadın / Erkek / Belirtmek istemiyorum).
/// `matchPreference` `auto` ise SharedHelpers backend'de cinsiyete göre
/// otomatik türetir; bu yüzden bu adımdan ayrı bir "kim ile?" sorusu yok.
class GenderStep extends StatelessWidget {
  const GenderStep({super.key, required this.draft, required this.onChanged});

  final RegistrationDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <_GenderOption>[
      _GenderOption(
        id: 'female',
        icon: Icons.female_rounded,
        label: context.tr3(tr: 'Kadın', en: 'Woman', de: 'Frau'),
      ),
      _GenderOption(
        id: 'male',
        icon: Icons.male_rounded,
        label: context.tr3(tr: 'Erkek', en: 'Man', de: 'Mann'),
      ),
      _GenderOption(
        id: 'nonbinary',
        icon: Icons.transgender_rounded,
        label: context.tr3(
          tr: 'Non-binary',
          en: 'Non-binary',
          de: 'Non-binary',
        ),
      ),
    ];

    return RegisterStepScaffold(
      heroIcon: Icons.diversity_3_rounded,
      titleSpans: [
        TextSpan(
          text: context.tr3(
            tr: 'Kendini nasıl\n',
            en: 'How do you\n',
            de: 'Wie identifizierst\n',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        TextSpan(
          text: context.tr3(
            tr: 'tanımlıyorsun?',
            en: 'identify?',
            de: 'du dich?',
          ),
          style: const TextStyle(color: AppColors.primary),
        ),
      ],
      subtitle: context.tr3(
        tr: 'Sonradan değiştirebilirsin.',
        en: 'You can change this later.',
        de: 'Du kannst das später ändern.',
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                Expanded(
                  child: CompactSelectableTile(
                    icon: options[i].icon,
                    label: options[i].label,
                    selected: draft.gender == options[i].id,
                    onTap: () {
                      draft.gender = options[i].id;
                      onChanged();
                    },
                  ),
                ),
                if (i < options.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgCard.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr3(
                      tr: 'Cinsiyetin profilinde gösterilmez. Sadece eşleşme önerileri için kullanılır.',
                      en: 'Your gender is not shown on your profile. It is only used for match recommendations.',
                      de: 'Dein Geschlecht wird nicht in deinem Profil angezeigt. Es wird nur für Empfehlungen verwendet.',
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderOption {
  const _GenderOption({
    required this.id,
    required this.icon,
    required this.label,
  });
  final String id;
  final IconData icon;
  final String label;
}
