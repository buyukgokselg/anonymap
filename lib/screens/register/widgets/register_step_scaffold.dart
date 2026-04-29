import 'package:flutter/material.dart';

import '../../../theme/colors.dart';

/// Kayıt akışındaki tüm step widget'ları için ortak iskelet:
/// üstte hero ikon, başlık (RichText, marka renkli vurgu) ve alt başlık;
/// sonra `child` içine adımın gerçek içeriği gelir.
///
/// Tüm padding ve scroll davranışı tek yerde toplanır → adımlar
/// arasında pixel-perfect tutarlılık sağlar.
class RegisterStepScaffold extends StatelessWidget {
  const RegisterStepScaffold({
    super.key,
    required this.heroIcon,
    required this.titleSpans,
    required this.subtitle,
    required this.child,
    this.scrollable = true,
  });

  /// Adımı tek bir görsele bağlayan büyük ikon (40-48px civarı).
  final IconData heroIcon;

  /// Başlık metni — `[normalSpan, accentSpan]` şeklinde verilebilir
  /// veya tek bir span olarak gönderilebilir. RichText ile render edilir.
  final List<TextSpan> titleSpans;

  /// Başlığın altında soft-grey yardımcı metin.
  final String subtitle;

  /// Adımın özel içeriği (form alanları, kart listesi, vb.)
  final Widget child;

  /// Kısa içerikler için `false` yapılarak "kaymayan" sabit ekran alınır.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(heroIcon, size: 40, color: AppColors.primary),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.15,
            ),
            children: titleSpans,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.45),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        child,
      ],
    );

    if (!scrollable) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
        child: content,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: content,
    );
  }
}
