import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecity/localization/app_localizations.dart';

final RegExp _keyPattern = RegExp(r"\bt\('([^']+)'\)");
final RegExp _phrasePattern = RegExp(r"\bphrase\('([^']+)'\)");
final RegExp _mojibakePattern = RegExp(
  '[\\u00C2-\\u00C5][\\u0080-\\u00FF]|\\u00E2[\\u0080-\\u00FF]{2}',
);
final RegExp _brokenQuestionPattern = RegExp(
  r'\?{3,}|[A-Za-zÇĞİÖŞÜÄÖÜçğıöşüäöüß]\?[A-Za-zÇĞİÖŞÜÄÖÜçğıöşüäöüß]|(^|[\s"({\[])\?[A-Za-zÇĞİÖŞÜÄÖÜçğıöşüäöüß]',
);

Map<String, Set<String>> _collectLocalizationUsage() {
  final keys = <String>{};
  final phrases = <String>{};

  for (final entity
      in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    for (final match in _keyPattern.allMatches(content)) {
      keys.add(match.group(1)!);
    }
    for (final match in _phrasePattern.allMatches(content)) {
      phrases.add(match.group(1)!);
    }
  }

  return {'keys': keys, 'phrases': phrases};
}

Iterable<File> _criticalSourceFiles() sync* {
  const roots = ['lib/screens', 'lib/widgets'];

  for (final root in roots) {
    yield* Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
  }
}

void main() {
  final usage = _collectLocalizationUsage();

  group('Localization guard', () {
    test('all translation keys resolve cleanly in supported locales', () {
      final locales = [
        const AppLocalizations(Locale('tr')),
        const AppLocalizations(Locale('en')),
        const AppLocalizations(Locale('de')),
      ];

      for (final key in usage['keys']!) {
        for (final l10n in locales) {
          final value = l10n.t(key);
          expect(value.trim(), isNotEmpty, reason: 'Empty translation for $key');
          expect(
            AppLocalizations.debugLooksBroken(value),
            isFalse,
            reason:
                'Broken translation for key "$key" in ${l10n.languageCode}: $value',
          );
        }
      }
    });

    test('all phrase translations resolve cleanly in supported locales', () {
      final locales = [
        const AppLocalizations(Locale('tr')),
        const AppLocalizations(Locale('en')),
        const AppLocalizations(Locale('de')),
      ];

      for (final phrase in usage['phrases']!) {
        for (final l10n in locales) {
          final value = l10n.phrase(phrase);
          expect(
            AppLocalizations.debugLooksBroken(value),
            isFalse,
            reason:
                'Broken phrase for "$phrase" in ${l10n.languageCode}: $value',
          );
        }
      }
    });

    test('helper outputs stay clean and human readable', () {
      final tr = AppLocalizations(const Locale('tr'));
      final en = AppLocalizations(const Locale('en'));
      final de = AppLocalizations(const Locale('de'));

      for (final l10n in [tr, en, de]) {
        for (final mode in const [
          'kesif',
          'sakinlik',
          'sosyal',
          'uretkenlik',
          'eglence',
          'acik_alan',
          'topluluk',
          'aile',
        ]) {
          expect(AppLocalizations.debugLooksBroken(l10n.modeLabel(mode)), isFalse);
        }

        for (final value in const ['cok yogun', 'yogun', 'orta', 'dusuk']) {
          expect(
            AppLocalizations.debugLooksBroken(l10n.densityLabel(value)),
            isFalse,
          );
        }

        for (final value in const ['patliyor', 'yukseliyor', 'sabit', 'sakin']) {
          expect(
            AppLocalizations.debugLooksBroken(l10n.trendLabel(value)),
            isFalse,
          );
        }

        for (var month = 1; month <= 12; month++) {
          expect(AppLocalizations.debugLooksBroken(l10n.monthName(month)), isFalse);
        }
      }

      expect(AppLocalizations.debugLooksBroken(en.t('forgot_password')), isFalse);
      expect(
        AppLocalizations.debugLooksBroken(tr.t('register_cta_prefix')),
        isFalse,
      );
      expect(
        AppLocalizations.debugLooksBroken(de.t('register_cta_prefix')),
        isFalse,
      );
    });

    test('critical source files do not contain mojibake or broken question marks', () {
      for (final file in _criticalSourceFiles()) {
        final content = file.readAsStringSync();
        expect(
          _mojibakePattern.hasMatch(content),
          isFalse,
          reason: 'Mojibake source fragment found in ${file.path}',
        );
        expect(
          _brokenQuestionPattern.hasMatch(content),
          isFalse,
          reason: 'Broken question-mark fragment found in ${file.path}',
        );
      }
    });
  });
}
