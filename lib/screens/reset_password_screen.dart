import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ResetPasswordScreen({
    super.key,
    required this.initialEmail,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isSubmitting = false;
  bool _isResending = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  AppLocalizations get _l10n => context.l10n;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || code.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage(_l10n.t('fill_all_fields'));
      return;
    }
    if (password.length < 8) {
      _showMessage(_l10n.t('password_too_short'));
      return;
    }
    if (password != confirmPassword) {
      _showMessage(_l10n.t('passwords_mismatch'));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authService.confirmPasswordReset(
        email: email,
        code: code,
        newPassword: password,
      );
      if (!mounted) return;
      _showMessage(_l10n.t('reset_password_success'));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resend() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage(_l10n.t('reset_password_requires_email'));
      return;
    }

    setState(() => _isResending = true);
    try {
      await _authService.resetPassword(email);
      if (!mounted) return;
      _showMessage(_l10n.t('reset_password_sent'));
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _l10n.t('reset_password_title'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.t('reset_password_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _l10n.t('reset_password_subtitle'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              _buildField(
                controller: _emailController,
                icon: Icons.mail_outline_rounded,
                hint: _l10n.t('email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _codeController,
                icon: Icons.password_rounded,
                hint: _l10n.t('reset_password_code_hint'),
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _passwordController,
                icon: Icons.lock_outline_rounded,
                hint: _l10n.t('reset_password_new_password'),
                obscureText: _hidePassword,
                suffix: IconButton(
                  onPressed: () {
                    setState(() => _hidePassword = !_hidePassword);
                  },
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _confirmPasswordController,
                icon: Icons.lock_person_outlined,
                hint: _l10n.t('confirm_password'),
                obscureText: _hideConfirmPassword,
                suffix: IconButton(
                  onPressed: () {
                    setState(() => _hideConfirmPassword = !_hideConfirmPassword);
                  },
                  icon: Icon(
                    _hideConfirmPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isResending ? null : _resend,
                  child: Text(
                    _isResending
                        ? _l10n.t('reset_password_resending')
                        : _l10n.t('reset_password_resend'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _l10n.t('reset_password_submit'),
                          style: AppTextStyles.button,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.2),
            size: 20,
          ),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
