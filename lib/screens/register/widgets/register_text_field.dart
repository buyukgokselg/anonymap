import 'package:flutter/material.dart';

import '../../../theme/colors.dart';

/// Mevcut `register_screen.dart`'taki text field görsel diliyle birebir
/// uyumlu, ama her step widget'ında tekrar yazılmaması için izole edilmiş
/// versiyon. `valid==true` iken sağ tarafta yeşil tik gösterir.
class RegisterTextField extends StatelessWidget {
  const RegisterTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.valid = false,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final bool valid;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    Widget? trailing = suffix;
    if (trailing == null && valid) {
      trailing = const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 20,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: valid
              ? AppColors.success.withValues(alpha: 0.32)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofocus: autofocus,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        textCapitalization: textCapitalization,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.22),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.22),
            size: 20,
          ),
          suffixIcon: trailing,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
