import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecity/localization/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('renders login copy correctly in all supported languages', () {
      final tr = AppLocalizations(const Locale('tr'));
      final en = AppLocalizations(const Locale('en'));
      final de = AppLocalizations(const Locale('de'));

      expect(tr.t('login_title_line1'), '\u015eehrin nabz\u0131n\u0131');
      expect(tr.t('login_title_line2'), '\u015eimdi ke\u015ffet');
      expect(tr.t('register_title_line1'), "PulseCity'ye");
      expect(en.t('login_title_line1'), 'Feel the pulse');
      expect(en.t('login_title_line2'), 'of your city');
      expect(en.t('register_cta_prefix'), "Don't have an account?");
      expect(de.t('login_title_line1'), 'Sp\u00fcre den Puls');
      expect(de.t('login_title_line2'), 'deiner Stadt');
    });

    test('repairs broken variants and translates shared phrases', () {
      final tr = AppLocalizations(const Locale('tr'));
      final en = AppLocalizations(const Locale('en'));
      final de = AppLocalizations(const Locale('de'));

      expect(tr.phrase('Video paylasti'), 'Video payla\u015ft\u0131');
      expect(
        tr.phrase('A\u00C3\u0192\u00C2\u00A7\u00C3\u201E\u00C2\u00B1k'),
        'A\u00e7\u0131k',
      );
      expect(en.phrase('A\u00e7\u0131k'), 'Open');
      expect(en.phrase('Video paylasti'), 'Shared a video');
      expect(de.phrase('A\u00e7\u0131k'), 'Offen');
      expect(de.phrase('Video paylasti'), 'Hat ein Video geteilt');
    });

    test('includes settings copy in all supported languages', () {
      final tr = AppLocalizations(const Locale('tr'));
      final en = AppLocalizations(const Locale('en'));
      final de = AppLocalizations(const Locale('de'));

      expect(tr.t('privacy_visibility'), 'Profil g\u00f6r\u00fcn\u00fcrl\u00fc\u011f\u00fc');
      expect(en.t('privacy_visibility'), 'Profile visibility');
      expect(de.t('privacy_visibility'), 'Profilsichtbarkeit');
      expect(tr.t('district'), '\u0130l\u00e7e');
      expect(en.t('district'), 'District');
      expect(de.t('district'), 'Bezirk');
    });

    test('translates common app phrases for home and chat flows', () {
      final en = AppLocalizations(const Locale('en'));
      final de = AppLocalizations(const Locale('de'));

      expect(en.phrase('Açık'), 'Open');
      expect(de.phrase('Açık'), 'Offen');
      expect(en.phrase('Kapalı'), 'Closed');
      expect(de.phrase('Kapalı'), 'Geschlossen');
      expect(en.phrase('Canlı veri'), 'Live data');
      expect(de.phrase('Canlı veri'), 'Live-Daten');
      expect(en.phrase('Gönderi Paylaş'), 'Share Post');
      expect(de.phrase('Gönderi Paylaş'), 'Beitrag teilen');
      expect(
        en.phrase('Arkadaşlık isteği gönderildi.'),
        'Friend request sent.',
      );
      expect(
        de.phrase('Arkadaşlık isteği gönderildi.'),
        'Freundschaftsanfrage wurde gesendet.',
      );
    });
  });
}
