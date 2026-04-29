import 'package:flutter/material.dart';

import '../../../localization/app_localizations.dart';
import '../../../theme/colors.dart';
import '../../../theme/text_styles.dart';

/// Kayıt akışının ilk ekranı — marka anı.
///
/// İki ana CTA: "Hesap oluştur" (e-posta yolunu başlatır) ve
/// "Google ile devam et" (mevcut auth servisini kullanır). Altta küçük
/// bir "Zaten hesabın var mı? Giriş yap" link'i yer alır.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({
    super.key,
    required this.onCreateAccount,
    required this.onContinueWithGoogle,
    required this.onLoginInstead,
    required this.isGoogleLoading,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onContinueWithGoogle;
  final VoidCallback onLoginInstead;
  final bool isGoogleLoading;

  String _copy(BuildContext context, {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 3),

            // ── Hero "marka kalbi" ──
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.primary,
                size: 48,
              ),
            ),

            const SizedBox(height: 28),

            // ── Başlık ──
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
                children: [
                  TextSpan(
                    text: _copy(
                      context,
                      tr: 'Anonim. Yakın.\n',
                      en: 'Anonymous. Close.\n',
                      de: 'Anonym. Nah.\n',
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: _copy(
                      context,
                      tr: 'Gerçek.',
                      en: 'Real.',
                      de: 'Echt.',
                    ),
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Text(
              _copy(
                context,
                tr: 'Şehrin nabzındaki insanları keşfet, isimsiz tanış, hazır olduğunda kendini aç.',
                en: 'Discover people on the city pulse, meet anonymously, open up when you are ready.',
                de: 'Entdecke Menschen im Puls der Stadt, lerne anonym kennen und öffne dich, wenn du bereit bist.',
              ),
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),

            const Spacer(flex: 5),

            // ── E-posta ile hesap oluştur ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onCreateAccount,
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
                    tr: 'E-posta ile başla',
                    en: 'Continue with email',
                    de: 'Mit E-Mail starten',
                  ),
                  style: AppTextStyles.button,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Google ile devam ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isGoogleLoading ? null : onContinueWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: isGoogleLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black54,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _copy(
                              context,
                              tr: 'Google ile devam et',
                              en: 'Continue with Google',
                              de: 'Mit Google fortfahren',
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Giriş linki ──
            Center(
              child: Wrap(
                children: [
                  Text(
                    '${_copy(context, tr: "Zaten hesabın var mı?", en: "Already have an account?", de: "Hast du schon ein Konto?")} ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: onLoginInstead,
                    child: Text(
                      _copy(
                        context,
                        tr: 'Giriş yap',
                        en: 'Log in',
                        de: 'Anmelden',
                      ),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
