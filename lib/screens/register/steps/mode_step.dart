import 'package:flutter/material.dart';

import '../../../config/mode_config.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/registration_draft.dart';
import '../../../theme/colors.dart';
import '../widgets/register_step_scaffold.dart';
import '../widgets/selectable_card.dart';

/// Adım 4: Tanışma niyeti (flirt / friends / fun / chill).
///
/// Onboarding'den buraya taşındı — "burada ne arıyorsun?" sorusu
/// kayıt sırasında sorulması gereken bir niyet sorusudur. Onboarding
/// artık sadece privacy + interests + orientation/intent ile sınırlı.
class ModeStep extends StatelessWidget {
  const ModeStep({super.key, required this.draft, required this.onChanged});

  final RegistrationDraft draft;
  final VoidCallback onChanged;

  String _modeTitle(BuildContext context, String id) {
    return switch (id) {
      'flirt' => context.tr3(tr: 'Flört', en: 'Flirt', de: 'Flirt'),
      'friends' => context.tr3(
        tr: 'Arkadaşlık',
        en: 'Friendship',
        de: 'Freundschaft',
      ),
      'fun' => context.tr3(tr: 'Eğlence', en: 'Fun', de: 'Spaß'),
      'chill' => context.tr3(tr: 'Chill', en: 'Chill', de: 'Chill'),
      _ => id,
    };
  }

  String _modeDescription(BuildContext context, String id) {
    return switch (id) {
      'flirt' => context.tr3(
        tr: 'Romantik ilgiye açığım — 1:1 kimya arıyorum.',
        en: 'Open to romance — looking for 1:1 chemistry.',
        de: 'Offen für Romantik — auf der Suche nach 1:1 Chemie.',
      ),
      'friends' => context.tr3(
        tr: 'Yeni arkadaşlar, platonik takılmalar.',
        en: 'New friends, platonic hangouts.',
        de: 'Neue Freunde, platonische Treffen.',
      ),
      'fun' => context.tr3(
        tr: 'Grup, parti, etkinlik partneri arıyorum.',
        en: 'Group, party, looking for an event partner.',
        de: 'Gruppe, Party, suche einen Eventpartner.',
      ),
      'chill' => context.tr3(
        tr: 'Baskısız tanış, doğal akış — açığım ama aramıyorum.',
        en: 'No pressure, natural flow — open but not searching.',
        de: 'Kein Druck, natürlich — offen, aber nicht auf der Suche.',
      ),
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final modes = ModeConfig.all;

    return RegisterStepScaffold(
      heroIcon: Icons.tune_rounded,
      titleSpans: [
        TextSpan(
          text: context.tr3(
            tr: 'Burada ne\n',
            en: 'What are you\n',
            de: 'Wonach suchst\n',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        TextSpan(
          text: context.tr3(
            tr: 'arıyorsun?',
            en: 'looking for?',
            de: 'du hier?',
          ),
          style: const TextStyle(color: AppColors.primary),
        ),
      ],
      subtitle: context.tr3(
        tr: 'Bu seçim haritandaki insanları ve önerileri şekillendirir. Sonradan değiştirebilirsin.',
        en: 'This shapes the people and suggestions on your map. You can change it later.',
        de: 'Das beeinflusst Menschen und Vorschläge auf deiner Karte. Später änderbar.',
      ),
      child: Column(
        children: [
          for (final mode in modes)
            SelectableCard(
              icon: mode.icon,
              title: _modeTitle(context, mode.id),
              description: _modeDescription(context, mode.id),
              color: mode.color,
              selected: draft.mode == mode.id,
              onTap: () {
                draft.mode = mode.id;
                onChanged();
              },
            ),
        ],
      ),
    );
  }
}
