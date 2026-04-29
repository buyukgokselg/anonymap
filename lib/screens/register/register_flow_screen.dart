import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../localization/app_localizations.dart';
import '../../models/registration_draft.dart';
import '../../services/app_locale_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/colors.dart';
import '../home_shell_screen.dart';
import '../onboarding_screen.dart';
import 'steps/account_step.dart';
import 'steps/city_step.dart';
import 'steps/gender_step.dart';
import 'steps/identity_step.dart';
import 'steps/mode_step.dart';
import 'steps/success_step.dart';
import 'steps/terms_step.dart';
import 'steps/welcome_step.dart';
import 'widgets/register_continue_button.dart';
import 'widgets/register_progress_bar.dart';

/// Yeni 7 adımlı kayıt wizard'ı.
///
/// Sayfa indeksleri (`RegisterStep` enum'ı ile birebir):
///   0 = welcome   →  kendi butonlarını içerir
///   1 = account   →  e-posta + şifre
///   2 = identity  →  ad + doğum tarihi
///   3 = gender
///   4 = mode      →  flirt / friends / fun / chill
///   5 = city
///   6 = terms     →  CTA: "Hesabımı oluştur" → submit
///   7 = success   →  kendi butonunu içerir
///
/// Welcome ve success "self-contained" ekranlardır (kendi CTA'larını sunar);
/// 1..6 arası adımlar paylaşılan progress bar + sticky continue button kullanır.
class RegisterFlowScreen extends StatefulWidget {
  const RegisterFlowScreen({super.key});

  @override
  State<RegisterFlowScreen> createState() => _RegisterFlowScreenState();
}

class _RegisterFlowScreenState extends State<RegisterFlowScreen> {
  final _pageController = PageController();
  final _draft = RegistrationDraft();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  int _currentIndex = 0;
  bool _isSubmitting = false;
  bool _isGoogleLoading = false;

  static const int _totalSteps = 8;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  RegisterStep get _currentStep => RegisterStep.values[_currentIndex];

  String _copy({
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

  // ── Akış kontrolü ──────────────────────────────────────────────────

  void _markChanged() {
    // Step widget'ları draft'ı güncelledikten sonra parent'ı bilgilendiriyor;
    // tek yapmamız gereken Continue butonunun enabled durumunu yeniden çizmek.
    if (mounted) setState(() {});
  }

  Future<void> _goToStep(RegisterStep step) async {
    final targetIndex = step.index;
    if (targetIndex == _currentIndex) return;

    await _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    HapticFeedback.lightImpact();
  }

  Future<bool> _onWillPop() async {
    if (_isSubmitting) return false;

    // Welcome veya success'te geri = ekrandan çık.
    if (_currentStep == RegisterStep.welcome ||
        _currentStep == RegisterStep.success) {
      return true;
    }

    // İçeride bir adımdayız: bir önceki step'e dön.
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
    return false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Continue butonu davranışı ─────────────────────────────────────

  void _handleContinue() {
    if (!_draft.canAdvanceFromStep(_currentStep)) {
      _showError(_validationMessageFor(_currentStep));
      return;
    }

    HapticFeedback.selectionClick();

    if (_currentStep == RegisterStep.terms) {
      _submit();
      return;
    }

    final next = RegisterStep.values[_currentIndex + 1];
    _goToStep(next);
  }

  String _validationMessageFor(RegisterStep step) {
    return switch (step) {
      RegisterStep.account => _copy(
        tr: 'Geçerli bir e-posta ve en az 8 karakterli şifre gir.',
        en: 'Enter a valid email and a password of at least 8 characters.',
        de: 'Gib eine gültige E-Mail und mindestens 8 Zeichen Passwort ein.',
      ),
      RegisterStep.identity => _copy(
        tr: 'Adını yaz ve doğum tarihini seç (18+).',
        en: 'Enter your name and birth date (18+).',
        de: 'Gib deinen Namen und Geburtsdatum ein (18+).',
      ),
      RegisterStep.gender => _copy(
        tr: 'Cinsiyetini seç.',
        en: 'Choose your gender.',
        de: 'Wähle dein Geschlecht.',
      ),
      RegisterStep.mode => _copy(
        tr: 'Bir tanışma niyeti seç.',
        en: 'Choose your intent.',
        de: 'Wähle deine Absicht.',
      ),
      RegisterStep.city => _copy(
        tr: 'Şehrini seç.',
        en: 'Choose your city.',
        de: 'Wähle deine Stadt.',
      ),
      RegisterStep.terms => _copy(
        tr: 'Devam etmek için her iki onayı da işaretle.',
        en: 'Tick both confirmations to continue.',
        de: 'Setze beide Bestätigungen, um fortzufahren.',
      ),
      _ => '',
    };
  }

  String get _continueLabel {
    if (_currentStep == RegisterStep.terms) {
      return _copy(
        tr: 'Hesabımı oluştur',
        en: 'Create my account',
        de: 'Mein Konto erstellen',
      );
    }
    return _copy(tr: 'Devam', en: 'Continue', de: 'Weiter');
  }

  // ── Submit ────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final selectedLanguage = AppLocaleService.instance.languageCode;

    try {
      await _authService.register(
        firstName: _draft.firstName,
        email: _draft.email,
        password: _draft.password,
        city: _draft.city,
        gender: _draft.gender,
        birthDate: _draft.birthDate!,
        mode: _draft.mode,
        matchPreference: _draft.matchPreference,
      );
      await _syncPreferredLanguage(selectedLanguage);

      if (!mounted) return;
      // Başarı ekranına geç (PageView'in son sayfası).
      await _pageController.animateToPage(
        RegisterStep.success.index,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _syncPreferredLanguage(String languageCode) async {
    final session = _authService.currentUser;
    if (session == null || session.userId.isEmpty) return;
    if (session.preferredLanguage == languageCode) {
      await AppLocaleService.instance.setLanguageCode(languageCode);
      return;
    }
    try {
      await _firestoreService.updateProfile(session.userId, {
        'preferredLanguage': languageCode,
      });
      await AppLocaleService.instance.setLanguageCode(languageCode);
    } catch (e, st) {
      debugPrint('Preferred language sync failed: $e\n$st');
    }
  }

  // ── Welcome + Google ─────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    final selectedLanguage = AppLocaleService.instance.languageCode;

    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }
      await _syncPreferredLanguage(selectedLanguage);
      if (!mounted) return;
      final isNewUser = result.isNewUser || !result.session.isOnboarded;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              isNewUser ? const OnboardingScreen() : const HomeShellScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 480),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == RegisterStep.welcome,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgMain,
        appBar: _buildAppBar(),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              RegisterProgressBar(
                currentIndex: _currentIndex,
                totalSteps: _totalSteps,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  children: [
                    WelcomeStep(
                      onCreateAccount: () => _goToStep(RegisterStep.account),
                      onContinueWithGoogle: _signInWithGoogle,
                      onLoginInstead: () => Navigator.of(context).pop(),
                      isGoogleLoading: _isGoogleLoading,
                    ),
                    AccountStep(draft: _draft, onChanged: _markChanged),
                    IdentityStep(draft: _draft, onChanged: _markChanged),
                    GenderStep(draft: _draft, onChanged: _markChanged),
                    ModeStep(draft: _draft, onChanged: _markChanged),
                    CityStep(draft: _draft, onChanged: _markChanged),
                    TermsStep(draft: _draft, onChanged: _markChanged),
                    SuccessStep(
                      firstName: _draft.firstName,
                      onContinue: _goToOnboarding,
                    ),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  void _goToOnboarding() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const OnboardingScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final showBack =
        _currentStep != RegisterStep.welcome &&
        _currentStep != RegisterStep.success;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: showBack
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () async {
                final canPop = await _onWillPop();
                if (canPop && mounted) Navigator.of(context).pop();
              },
            )
          : (_currentStep == RegisterStep.welcome
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : const SizedBox.shrink()),
      // Sayaç ("3 / 6" gibi) — sadece working step'lerde
      title: _showStepCounter
          ? Text(
              '$_currentIndex / ${_totalSteps - 2}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            )
          : null,
      centerTitle: true,
    );
  }

  bool get _showStepCounter =>
      _currentStep != RegisterStep.welcome &&
      _currentStep != RegisterStep.success;

  Widget _buildBottomBar() {
    // Welcome ve success ekranları kendi CTA'larını içerir → bottom bar'ı gizle.
    if (_currentStep == RegisterStep.welcome ||
        _currentStep == RegisterStep.success) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        28,
        12,
        28,
        24 + MediaQuery.of(context).viewInsets.bottom * 0,
      ),
      child: RegisterContinueButton(
        label: _continueLabel,
        enabled: _draft.canAdvanceFromStep(_currentStep),
        isLoading: _isSubmitting,
        onPressed: _handleContinue,
      ),
    );
  }
}
