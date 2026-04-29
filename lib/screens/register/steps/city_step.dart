import 'package:flutter/material.dart';

import '../../../localization/app_localizations.dart';
import '../../../models/registration_draft.dart';
import '../../../theme/colors.dart';
import '../data/turkish_cities.dart';
import '../widgets/register_step_scaffold.dart';

/// Adım 5: Şehir.
///
/// Free-text yerine TR 81 il statik listesinden autocomplete arama.
/// Diakritik-agnostik arama: "izmir" yazınca "İzmir" bulur.
/// Seçilen şehir kart üzerinde "✓ İstanbul" şeklinde gösterilir.
class CityStep extends StatefulWidget {
  const CityStep({super.key, required this.draft, required this.onChanged});

  final RegistrationDraft draft;
  final VoidCallback onChanged;

  @override
  State<CityStep> createState() => _CityStepState();
}

class _CityStepState extends State<CityStep> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _query = _searchController.text);
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

  List<TurkishCity> get _filtered {
    final q = normalizeCityQuery(_query);
    if (q.isEmpty) return kTurkishCities;
    // Önce başlangıçta eşleşenleri öne al, sonra "içeren"leri.
    final starts = <TurkishCity>[];
    final contains = <TurkishCity>[];
    for (final city in kTurkishCities) {
      if (city.searchKey.startsWith(q)) {
        starts.add(city);
      } else if (city.searchKey.contains(q)) {
        contains.add(city);
      }
    }
    return [...starts, ...contains];
  }

  void _select(TurkishCity city) {
    widget.draft.city = city.name;
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final selectedName = widget.draft.city;

    return RegisterStepScaffold(
      heroIcon: Icons.location_city_rounded,
      scrollable: false,
      titleSpans: [
        TextSpan(
          text: _copy(
            context,
            tr: 'Hangi\n',
            en: 'Which city\n',
            de: 'In welcher Stadt\n',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        TextSpan(
          text: _copy(
            context,
            tr: 'şehirdesin?',
            en: 'are you in?',
            de: 'lebst du?',
          ),
          style: const TextStyle(color: AppColors.primary),
        ),
      ],
      subtitle: _copy(
        context,
        tr: 'Şehrindeki insanları keşfetmek için kullanılır.',
        en: 'Used to discover people in your city.',
        de: 'Wird verwendet, um Menschen in deiner Stadt zu entdecken.',
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            // ── Arama kutusu ──
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: AppColors.primary,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _copy(
                    context,
                    tr: 'Şehir ara…',
                    en: 'Search city…',
                    de: 'Stadt suchen…',
                  ),
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.22),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 20,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 18,
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ── Sonuç listesi ──
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _copy(
                          context,
                          tr: 'Sonuç bulunamadı',
                          en: 'No results',
                          de: 'Keine Ergebnisse',
                        ),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      itemBuilder: (context, index) {
                        final city = filtered[index];
                        final isSelected = city.name == selectedName;
                        return InkWell(
                          onTap: () => _select(city),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 18,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white.withValues(alpha: 0.3),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    city.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.white,
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
