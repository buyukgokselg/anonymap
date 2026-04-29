import 'package:flutter/material.dart';

import '../../../localization/app_localizations.dart';
import '../../../models/registration_draft.dart';
import '../../../theme/colors.dart';
import '../widgets/register_step_scaffold.dart';
import '../widgets/register_text_field.dart';

/// Adım 2: Ad + Doğum Tarihi
///
/// "Sen kimsin?" soyut konseptinin tek bir ekranda kendi içinde tamamlanması.
/// Soyad alanı **bilerek yok** (anonimlik vaadi). Doğum tarihi için Material
/// dialog yerine inline scroll picker — gece teması ve marka renkleriyle
/// uyumlu, tek dokunuşta açılan modal bottom sheet.
class IdentityStep extends StatefulWidget {
  const IdentityStep({super.key, required this.draft, required this.onChanged});

  final RegistrationDraft draft;
  final VoidCallback onChanged;

  @override
  State<IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends State<IdentityStep> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.firstName);
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    widget.draft.firstName = _nameController.text;
    widget.onChanged();
  }

  Future<void> _openBirthDatePicker() async {
    final now = DateTime.now();
    final initial =
        widget.draft.birthDate ?? DateTime(now.year - 24, now.month, now.day);

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _BirthDatePickerSheet(
        initial: initial,
        firstYear: now.year - 80,
        // 18 yaş sınırı; bu yıl doğan henüz 18 olmamış olabilir, yıl bazlı
        // upper bound kullanıp asıl 18+ kontrolünü RegistrationDraft yapar.
        lastYear: now.year - 18,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        widget.draft.birthDate = picked;
      });
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthDate = widget.draft.birthDate;
    final age = widget.draft.age;
    final isAdult = widget.draft.hasBirthDate;

    return RegisterStepScaffold(
      heroIcon: Icons.person_outline_rounded,
      titleSpans: [
        TextSpan(
          text: context.tr3(
            tr: 'Sana nasıl\n',
            en: 'What should we\n',
            de: 'Wie sollen wir dich\n',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        TextSpan(
          text: context.tr3(
            tr: 'hitap edelim?',
            en: 'call you?',
            de: 'nennen?',
          ),
          style: const TextStyle(color: AppColors.primary),
        ),
      ],
      subtitle: context.tr3(
        tr: 'Sadece sen ve eşleştiğin kişiler görür. Doğum tarihin ise asla paylaşılmaz.',
        en: 'Only you and your matches see this. Your birth date is never shared.',
        de: 'Nur du und deine Matches sehen das. Dein Geburtsdatum wird nie geteilt.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RegisterTextField(
            controller: _nameController,
            hint: context.tr3(
              tr: 'Adın',
              en: 'Your first name',
              de: 'Dein Vorname',
            ),
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            valid: widget.draft.hasName,
          ),
          const SizedBox(height: 14),
          // ── Doğum tarihi tap-target ──
          InkWell(
            onTap: _openBirthDatePicker,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isAdult
                      ? AppColors.success.withValues(alpha: 0.32)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cake_outlined,
                    color: Colors.white.withValues(alpha: 0.22),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      birthDate == null
                          ? context.tr3(
                              tr: 'Doğum tarihin',
                              en: 'Your birth date',
                              de: 'Dein Geburtsdatum',
                            )
                          : '${birthDate.day.toString().padLeft(2, '0')}.${birthDate.month.toString().padLeft(2, '0')}.${birthDate.year}',
                      style: TextStyle(
                        color: birthDate == null
                            ? Colors.white.withValues(alpha: 0.22)
                            : Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (isAdult)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    )
                  else
                    Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white.withValues(alpha: 0.28),
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
          if (birthDate != null && age != null) ...[
            const SizedBox(height: 10),
            if (isAdult)
              Row(
                children: [
                  const Text('🎂', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    context.tr3(
                      tr: '$age yaşındasın',
                      en: 'You are $age',
                      de: 'Du bist $age',
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr3(
                      tr: 'Kayıt için en az 18 yaşında olmalısın.',
                      en: 'You must be at least 18 to sign up.',
                      de: 'Du musst mindestens 18 sein, um dich zu registrieren.',
                    ),
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

// ════════════════════════════════════════════════════════════════════════
// Birth date picker — bottom sheet ile inline 3-wheel scroller
// ════════════════════════════════════════════════════════════════════════

class _BirthDatePickerSheet extends StatefulWidget {
  const _BirthDatePickerSheet({
    required this.initial,
    required this.firstYear,
    required this.lastYear,
  });

  final DateTime initial;
  final int firstYear;
  final int lastYear;

  @override
  State<_BirthDatePickerSheet> createState() => _BirthDatePickerSheetState();
}

class _BirthDatePickerSheetState extends State<_BirthDatePickerSheet> {
  late int _day = widget.initial.day;
  late int _month = widget.initial.month;
  late int _year = widget.initial.year;

  int get _maxDayInMonth {
    // Şubat dahil ay-uzunluğu kontrolü (artık yıl dahil).
    final next = (_month == 12)
        ? DateTime(_year + 1, 1, 1)
        : DateTime(_year, _month + 1, 1);
    final last = next.subtract(const Duration(days: 1));
    return last.day;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final years = List.generate(
      widget.lastYear - widget.firstYear + 1,
      (i) => widget.firstYear + i,
    ).reversed.toList();

    final maxDay = _maxDayInMonth;
    if (_day > maxDay) {
      _day = maxDay;
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Sürükleme tutamağı ──
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              switch (l10n.languageCode) {
                'en' => 'Birth date',
                'de' => 'Geburtsdatum',
                _ => 'Doğum tarihi',
              },
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: _WheelColumn(
                      values: List.generate(maxDay, (i) => i + 1),
                      selected: _day,
                      width: 60,
                      onChanged: (v) => setState(() => _day = v),
                      formatter: (v) => v.toString().padLeft(2, '0'),
                    ),
                  ),
                  Expanded(
                    child: _WheelColumn(
                      values: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                      selected: _month,
                      width: 90,
                      onChanged: (v) => setState(() => _month = v),
                      formatter: (v) => _monthLabel(v, l10n.languageCode),
                    ),
                  ),
                  Expanded(
                    child: _WheelColumn(
                      values: years,
                      selected: _year,
                      width: 80,
                      onChanged: (v) => setState(() => _year = v),
                      formatter: (v) => v.toString(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(DateTime(_year, _month, _day));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  switch (l10n.languageCode) {
                    'en' => 'Confirm',
                    'de' => 'Bestätigen',
                    _ => 'Onayla',
                  },
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(int month, String lang) {
    const tr = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    const en = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const de = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    return switch (lang) {
      'en' => en[month - 1],
      'de' => de[month - 1],
      _ => tr[month - 1],
    };
  }
}

class _WheelColumn extends StatefulWidget {
  const _WheelColumn({
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.formatter,
    required this.width,
  });

  final List<int> values;
  final int selected;
  final ValueChanged<int> onChanged;
  final String Function(int) formatter;
  final double width;

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.values.indexOf(widget.selected);
    _controller = FixedExtentScrollController(
      initialItem: initial < 0 ? 0 : initial,
    );
  }

  @override
  void didUpdateWidget(covariant _WheelColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values.length != widget.values.length) {
      // Listenin uzunluğu değiştiğinde (örn. ay değişince gün max'ı değişti)
      // controller'ı geçerli aralığa çek.
      final clamped = widget.selected.clamp(
        widget.values.first,
        widget.values.last,
      );
      final index = widget.values.indexOf(clamped);
      if (index >= 0 && index != _controller.selectedItem) {
        _controller.jumpToItem(index);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: 36,
      perspective: 0.003,
      diameterRatio: 1.6,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) {
        widget.onChanged(widget.values[index]);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.values.length,
        builder: (context, index) {
          final value = widget.values[index];
          final isSelected = value == widget.selected;
          return Container(
            alignment: Alignment.center,
            child: Text(
              widget.formatter(value),
              style: TextStyle(
                fontSize: isSelected ? 19 : 16,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          );
        },
      ),
    );
  }
}
