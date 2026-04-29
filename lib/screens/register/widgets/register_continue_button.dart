import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import '../../../theme/text_styles.dart';

/// Kayıt akışı için sticky alt buton — klavyenin üstünde kalmaz, ekranın
/// alt safe-area'sında durur. `enabled=false` iken disabled stiline geçer
/// (görünür kalır ama dokunulmaz, çünkü kullanıcının "neden ilerleyemiyorum"
/// sorusunu in-place validation ile cevaplıyoruz).
class RegisterContinueButton extends StatelessWidget {
  const RegisterContinueButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isLoading;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: canTap ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.32),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label, style: AppTextStyles.button),
      ),
    );
  }
}
