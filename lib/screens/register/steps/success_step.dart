import 'package:flutter/material.dart';

import '../../../localization/app_localizations.dart';
import '../../../theme/colors.dart';
import '../../../theme/text_styles.dart';

/// Adım 7: Başarı/karşılama ekranı.
///
/// `RegisterFlowScreen` submit başarılı olunca buraya geçer. Burada:
/// - Pulsing yeşil tik animasyonu
/// - "Hoş geldin, {ad}!" başlığı
/// - Tek CTA: onboarding'e geçiş
class SuccessStep extends StatefulWidget {
  const SuccessStep({
    super.key,
    required this.firstName,
    required this.onContinue,
  });

  final String firstName;
  final VoidCallback onContinue;

  @override
  State<SuccessStep> createState() => _SuccessStepState();
}

class _SuccessStepState extends State<SuccessStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.1).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 40,
      ),
    ]).animate(_controller);
    _glowAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
        child: Column(
          children: [
            const Spacer(flex: 3),
            // ── Animasyonlu tik ──
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppColors.success.withValues(
                        alpha: 0.3 + (0.4 * _glowAnim.value),
                      ),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(
                          alpha: 0.18 * _glowAnim.value,
                        ),
                        blurRadius: 36,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: 64,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
                children: [
                  TextSpan(
                    text:
                        '${_copy(context, tr: "Hoş geldin", en: "Welcome", de: "Willkommen")},\n',
                    style: const TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: '${widget.firstName.trim()}!',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _copy(
                context,
                tr: 'Şimdi seni biraz tanıyalım — ilgi alanların ve gizlilik tercihlerinle profilini şekillendir.',
                en: 'Now let us get to know you — shape your profile with interests and privacy preferences.',
                de: 'Jetzt lerne dich kennen — gestalte dein Profil mit Interessen und Datenschutz.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
            const Spacer(flex: 5),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: widget.onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _copy(
                    context,
                    tr: 'Devam et',
                    en: 'Continue',
                    de: 'Weiter',
                  ),
                  style: AppTextStyles.button,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
