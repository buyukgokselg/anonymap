import 'package:flutter/material.dart';

import '../../../localization/app_localizations.dart';
import '../../../models/registration_draft.dart';
import '../../../theme/colors.dart';
import '../widgets/register_step_scaffold.dart';
import '../widgets/register_text_field.dart';

/// Adım 1: E-posta + Şifre birleştirilmiş "hesap kimliği" ekranı.
///
/// İki input tek ekranda çünkü kullanıcının zihninde "hesap" tek bir
/// kavram — ama her input'un kendi real-time validasyonu var. Şifre
/// güç ölçeri eski kayıt formundakiyle aynı mantığı korur.
class AccountStep extends StatefulWidget {
  const AccountStep({super.key, required this.draft, required this.onChanged});

  final RegistrationDraft draft;

  /// Draft her değiştiğinde parent'ın "Devam" butonunun enabled durumunu
  /// güncelleyebilmesi için bildirilir.
  final VoidCallback onChanged;

  @override
  State<AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends State<AccountStep> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.draft.email);
    _passwordController = TextEditingController(text: widget.draft.password);
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);
    _recomputeStrength();
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    widget.draft.email = _emailController.text;
    widget.onChanged();
  }

  void _onPasswordChanged() {
    widget.draft.password = _passwordController.text;
    _recomputeStrength();
    widget.onChanged();
  }

  void _recomputeStrength() {
    final password = _passwordController.text;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password) ||
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      score++;
    }
    if (score != _passwordStrength) {
      setState(() => _passwordStrength = score);
    }
  }

  Color get _strengthColor => switch (_passwordStrength) {
    1 => AppColors.error,
    2 => AppColors.warning,
    3 || 4 => AppColors.success,
    _ => Colors.transparent,
  };

  String _strengthLabel(BuildContext context) {
    return switch (_passwordStrength) {
      1 => _copy(context, tr: 'Zayıf', en: 'Weak', de: 'Schwach'),
      2 => _copy(context, tr: 'Orta', en: 'Medium', de: 'Mittel'),
      3 => _copy(context, tr: 'Güçlü', en: 'Strong', de: 'Stark'),
      4 => _copy(context, tr: 'Çok güçlü', en: 'Very strong', de: 'Sehr stark'),
      _ => '',
    };
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
    return RegisterStepScaffold(
      heroIcon: Icons.alternate_email_rounded,
      titleSpans: [
        TextSpan(
          text: _copy(
            context,
            tr: 'Hesabını\n',
            en: 'Set up\n',
            de: 'Richte dein\n',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        TextSpan(
          text: _copy(
            context,
            tr: 'oluştur',
            en: 'your account',
            de: 'Konto ein',
          ),
          style: const TextStyle(color: AppColors.primary),
        ),
      ],
      subtitle: _copy(
        context,
        tr: 'E-posta adresin giriş için kullanılır. Şifren en az 8 karakter olmalı.',
        en: 'Your email is used for sign-in. Password must be at least 8 characters.',
        de: 'Deine E-Mail wird zum Anmelden verwendet. Passwort mindestens 8 Zeichen.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RegisterTextField(
            controller: _emailController,
            hint: _copy(
              context,
              tr: 'E-posta adresin',
              en: 'Your email',
              de: 'Deine E-Mail',
            ),
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofocus: true,
            valid: widget.draft.hasEmail,
          ),
          const SizedBox(height: 12),
          RegisterTextField(
            controller: _passwordController,
            hint: _copy(
              context,
              tr: 'Şifre oluştur',
              en: 'Create password',
              de: 'Passwort erstellen',
            ),
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            textInputAction: TextInputAction.done,
          ),
          if (_passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ...List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: index < _passwordStrength
                            ? _strengthColor
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 10),
                Text(
                  _strengthLabel(context),
                  style: TextStyle(
                    fontSize: 11,
                    color: _strengthColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
