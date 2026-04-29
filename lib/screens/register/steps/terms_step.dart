import 'package:flutter/material.dart';

import '../../../localization/app_localizations.dart';
import '../../../models/registration_draft.dart';
import '../../../theme/colors.dart';
import '../../legal/privacy_screen.dart';
import '../../legal/terms_screen.dart';
import '../widgets/register_step_scaffold.dart';

/// Adım 6: Kullanım koşulları + 18+ beyanı.
///
/// Submit bu ekrandan değil parent'taki sticky CTA'dan tetiklenir
/// ("Hesabımı oluştur" yazısı ile). Bu ekran sadece bilinçli onay alır.
class TermsStep extends StatefulWidget {
  const TermsStep({super.key, required this.draft, required this.onChanged});

  final RegistrationDraft draft;
  final VoidCallback onChanged;

  @override
  State<TermsStep> createState() => _TermsStepState();
}

class _TermsStepState extends State<TermsStep> {
  String _copy(
    BuildContext context, {
    required String tr,
    required String en,
    required String de,
  }) {
    return switch (AppLocalizations.of(context).languageCode) {
      'en' => en,
      'de' => de,
      _ => tr,
    };
  }

  @override
  Widget build(BuildContext context) {
    return RegisterStepScaffold(
      heroIcon: Icons.verified_user_rounded,
      titleSpans: [
        TextSpan(
          text: _copy(context, tr: 'Son ', en: 'Last ', de: 'Letzter '),
          style: const TextStyle(color: Colors.white),
        ),
        TextSpan(
          text: _copy(context, tr: 'adım', en: 'step', de: 'Schritt'),
          style: const TextStyle(color: AppColors.primary),
        ),
      ],
      subtitle: _copy(
        context,
        tr: 'Devam etmeden önce iki küçük onay.',
        en: 'Two small confirmations before we continue.',
        de: 'Zwei kleine Bestätigungen, bevor wir weitermachen.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Yaş onayı ──
          _ConsentTile(
            value: widget.draft.acceptedAge,
            onChanged: (v) {
              setState(() => widget.draft.acceptedAge = v);
              widget.onChanged();
            },
            content: Text(
              _copy(
                context,
                tr: '18 yaşından büyük olduğumu beyan ederim.',
                en: 'I confirm that I am over 18 years old.',
                de: 'Ich bestätige, dass ich über 18 Jahre alt bin.',
              ),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Şartlar onayı ──
          _ConsentTile(
            value: widget.draft.acceptedTerms,
            onChanged: (v) {
              setState(() => widget.draft.acceptedTerms = v);
              widget.onChanged();
            },
            content: Wrap(
              children: [
                Text(
                  '${_copy(context, tr: "Devam ederek", en: "By continuing", de: "Indem ich fortfahre")} ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  ),
                  child: Text(
                    _copy(
                      context,
                      tr: 'Kullanım Koşulları',
                      en: 'Terms of Service',
                      de: 'Nutzungsbedingungen',
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                      height: 1.5,
                    ),
                  ),
                ),
                Text(
                  ' ${_copy(context, tr: "ve", en: "and", de: "und")} ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                  child: Text(
                    _copy(
                      context,
                      tr: 'Gizlilik Politikası',
                      en: 'Privacy Policy',
                      de: 'Datenschutzrichtlinie',
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                      height: 1.5,
                    ),
                  ),
                ),
                Text(
                  _copy(context, tr: "'nı kabul ediyorum.", en: " I accept.", de: " stimme ich zu."),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.celebration_rounded,
                  size: 18,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _copy(
                      context,
                      tr: 'Hesabını oluşturmaya hazırsın.',
                      en: 'You are ready to create your account.',
                      de: 'Du bist bereit, dein Konto zu erstellen.',
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.onChanged,
    required this.content,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
