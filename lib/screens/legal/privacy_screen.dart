import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../theme/colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  List<Map<String, String>> _sections(BuildContext context) {
    return [
      {
        'title': context.tr3(
          tr: '1. Veri sorumlusu',
          en: '1. Data controller',
          de: '1. Verantwortliche Stelle',
        ),
        'content': context.tr3(
          tr:
              'Verilerinizin sorumlusu PulseCity GmbH\'dir.\n\nAdres: Hamburg, Almanya\nE-posta: privacy@pulsecity.app\nVeri koruma sorumlusu: dpo@pulsecity.app',
          en:
              'PulseCity GmbH is the controller of your personal data.\n\nAddress: Hamburg, Germany\nEmail: privacy@pulsecity.app\nData Protection Officer: dpo@pulsecity.app',
          de:
              'Verantwortliche Stelle für Ihre Daten ist die PulseCity GmbH.\n\nAdresse: Hamburg, Deutschland\nE-Mail: privacy@pulsecity.app\nDatenschutzkontakt: dpo@pulsecity.app',
        ),
      },
      {
        'title': context.tr3(
          tr: '2. Toplanan veriler',
          en: '2. Data we collect',
          de: '2. Erhobene Daten',
        ),
        'content': context.tr3(
          tr:
              'Hesap bilgileri: e-posta adresi, şifre özeti, yaş aralığı, cinsiyet ve ilgi alanları.\n\nKonum verileri: yalnızca uygulama aktifken ve izninizle kullanılan GPS koordinatları.\n\nKullanım verileri: seçilen mod, etkileşimler, kalış süresi ve ürün sinyalleri.\n\nKullanıcı içerikleri: paylaşımlar, shorts, durumlar, yorumlar ve raporlar.',
          en:
              'Account data: email address, password hash, age range, gender, and interests.\n\nLocation data: GPS coordinates used only while the app is active and with your permission.\n\nUsage data: selected mode, interactions, session duration, and product signals.\n\nUser content: posts, shorts, stories, comments, and reports.',
          de:
              'Kontodaten: E-Mail-Adresse, Passwort-Hash, Altersbereich, Geschlecht und Interessen.\n\nStandortdaten: GPS-Koordinaten nur bei aktiver App und mit Ihrer Zustimmung.\n\nNutzungsdaten: gewählter Modus, Interaktionen, Aufenthaltsdauer und Produktsignale.\n\nNutzerinhalte: Beiträge, Shorts, Stories, Kommentare und Meldungen.',
        ),
      },
      {
        'title': context.tr3(
          tr: '3. İşleme amaçları',
          en: '3. Why we process data',
          de: '3. Zwecke der Verarbeitung',
        ),
        'content': context.tr3(
          tr:
              '• Pulse Score ve şehir yoğunluk sinyallerini hesaplamak\n• Kişiselleştirilmiş yer ve zaman önerileri sunmak\n• Sosyal uyumluluk ve nearby akışlarını çalıştırmak\n• Güvenlik, moderasyon ve hata tespiti sağlamak\n• Yasal yükümlülükleri yerine getirmek',
          en:
              '• To compute Pulse Score and urban density signals\n• To deliver personalized place and timing recommendations\n• To power social compatibility and nearby discovery\n• To support safety, moderation, and issue detection\n• To comply with legal obligations',
          de:
              '• Zur Berechnung von Pulse Score und städtischen Dichtesignalen\n• Für personalisierte Orts- und Zeitempfehlungen\n• Für soziale Kompatibilität und Nearby Discovery\n• Für Sicherheit, Moderation und Fehlererkennung\n• Zur Erfüllung gesetzlicher Pflichten',
        ),
      },
      {
        'title': context.tr3(
          tr: '4. Gizlilik teknolojileri',
          en: '4. Privacy technologies',
          de: '4. Datenschutztechnologien',
        ),
        'content': context.tr3(
          tr:
              'PulseCity şu korumaları kullanır:\n\nDifferential privacy yaklaşımı, toplu çıktılarda bireysel davranışların ayrıştırılmasını zorlaştırır.\n\nk-anonymity eşiği, yeterli kullanıcı yoğunluğu olmadan hassas görünürlüğü sınırlar.\n\nGranularity control ile görünürlük hassasiyetini şehir, ilçe veya yakın çevre düzeyinde ayarlayabilirsiniz.\n\nGhost mode aktifken canlı konum katkısı kapatılır.\n\nTüm istemci-sunucu iletişimi şifrelenir.',
          en:
              'PulseCity uses the following safeguards:\n\nA differential privacy approach reduces the chance of isolating individual behavior in aggregate outputs.\n\nk-anonymity thresholds limit sensitive visibility unless enough people are present.\n\nGranularity control lets you choose city, district, or nearby precision.\n\nGhost mode disables your live location contribution.\n\nAll client-server communication is encrypted.',
          de:
              'PulseCity verwendet folgende Schutzmechanismen:\n\nEin Differential-Privacy-Ansatz erschwert die Ableitung individuellen Verhaltens aus aggregierten Ausgaben.\n\nk-Anonymitäts-Schwellen begrenzen sensible Sichtbarkeit, wenn nicht genügend Personen vorhanden sind.\n\nMit Granularity Control wählen Sie Stadt-, Bezirks- oder Nahbereichsgenauigkeit.\n\nIm Ghost Mode wird Ihr Live-Beitrag deaktiviert.\n\nDie gesamte Kommunikation zwischen Client und Server ist verschlüsselt.',
        ),
      },
      {
        'title': context.tr3(
          tr: '5. Ghost mode',
          en: '5. Ghost mode',
          de: '5. Ghost Mode',
        ),
        'content': context.tr3(
          tr:
              'Ghost mode açıkken canlı görünürlüğünüz kapanır. Diğer kullanıcılar sizi nearby akışlarında görmez, katkılarınız anlık sosyal alan hesaplarına dahil edilmez ve uygulamayı daha pasif bir modda kullanabilirsiniz.',
          en:
              'When Ghost Mode is enabled, your live visibility is disabled. Other users will not see you in nearby flows, your contribution will not be included in live social field calculations, and you can use the app more passively.',
          de:
              'Wenn Ghost Mode aktiviert ist, wird Ihre Live-Sichtbarkeit deaktiviert. Andere Nutzer sehen Sie nicht in Nearby-Ansichten, Ihr Beitrag fließt nicht in Live-Berechnungen des sozialen Feldes ein und Sie können die App passiver nutzen.',
        ),
      },
      {
        'title': context.tr3(
          tr: '6. Veri paylaşımı',
          en: '6. Data sharing',
          de: '6. Datenweitergabe',
        ),
        'content': context.tr3(
          tr:
              'Kişisel verileriniz üçüncü taraflara bireysel kullanıcı düzeyinde satılmaz veya paylaşılmaz.\n\nAnonim ve toplulaştırılmış veriler, ürün içi analiz, şehir zekâsı içgörüleri, mekan raporları ve güvenlik operasyonları için kullanılabilir.',
          en:
              'Your personal data is not sold or shared with third parties at an individual user level.\n\nAnonymous and aggregated data may be used for product analytics, urban intelligence insights, venue reporting, and safety operations.',
          de:
              'Ihre personenbezogenen Daten werden nicht auf Ebene einzelner Nutzer verkauft oder an Dritte weitergegeben.\n\nAnonyme und aggregierte Daten können für Produktanalysen, Urban-Intelligence-Insights, Venue-Reporting und Sicherheitsprozesse genutzt werden.',
        ),
      },
      {
        'title': context.tr3(
          tr: '7. Saklama süreleri',
          en: '7. Retention periods',
          de: '7. Speicherfristen',
        ),
        'content': context.tr3(
          tr:
              'Ham konum ve yüksek hassasiyetli varlık kayıtları kısa ömürlü tutulur.\n\nHesap verileri hesabın aktif kaldığı sürece saklanır.\n\nİçerik ve etkileşim kayıtları ürün işlevi ve güvenlik ihtiyaçlarına göre sınırlı sürelerle korunur.\n\nSilme taleplerinden sonra 72 saatlik yedek temizleme politikası uygulanır.',
          en:
              'Raw location and high-precision presence records are kept for short periods.\n\nAccount data is stored while your account remains active.\n\nContent and interaction records are retained for limited periods based on product functionality and safety needs.\n\nAfter deletion requests, a 72-hour backup cleanup policy is applied.',
          de:
              'Rohe Standortdaten und hochpräzise Präsenzdaten werden nur kurz gespeichert.\n\nKontodaten werden aufbewahrt, solange Ihr Konto aktiv ist.\n\nInhalte und Interaktionsdaten werden abhängig von Produktfunktion und Sicherheitsbedarf begrenzt gespeichert.\n\nNach Löschanfragen gilt eine 72-Stunden-Policy für die Bereinigung von Backups.',
        ),
      },
      {
        'title': context.tr3(
          tr: '8. Haklarınız',
          en: '8. Your rights',
          de: '8. Ihre Rechte',
        ),
        'content': context.tr3(
          tr:
              'GDPR kapsamında erişim, düzeltme, silme, taşınabilirlik, itiraz ve işlemeyi sınırlandırma haklarına sahipsiniz.\n\nVeri dışa aktarımı ve hesap silme taleplerinizi uygulama içinden veya privacy@pulsecity.app üzerinden iletebilirsiniz.',
          en:
              'Under the GDPR, you have rights to access, rectification, deletion, portability, objection, and restriction of processing.\n\nYou can request data export or account deletion in the app or via privacy@pulsecity.app.',
          de:
              'Nach der DSGVO haben Sie Rechte auf Auskunft, Berichtigung, Löschung, Datenübertragbarkeit, Widerspruch und Einschränkung der Verarbeitung.\n\nSie können Datenexport oder Kontolöschung in der App oder über privacy@pulsecity.app anfordern.',
        ),
      },
      {
        'title': context.tr3(
          tr: '9. İzleme ve güvenlik',
          en: '9. Tracking and security',
          de: '9. Tracking und Sicherheit',
        ),
        'content': context.tr3(
          tr:
              'PulseCity reklam izleme SDK\'ları çalıştırmaz. Operasyonel hata kayıtları, güvenlik olayları ve kötüye kullanım sinyalleri sınırlı ve kontrollü şekilde tutulabilir.',
          en:
              'PulseCity does not run advertising trackers. Operational error logs, security incidents, and abuse signals may be retained in a limited and controlled way.',
          de:
              'PulseCity verwendet keine Werbe-Tracking-SDKs. Betriebsbezogene Fehlerprotokolle, Sicherheitsvorfälle und Missbrauchssignale können in begrenzter und kontrollierter Form gespeichert werden.',
        ),
      },
      {
        'title': context.tr3(
          tr: '10. İletişim ve şikayet',
          en: '10. Contact and complaints',
          de: '10. Kontakt und Beschwerden',
        ),
        'content': context.tr3(
          tr:
              'Gizlilikle ilgili sorularınız için privacy@pulsecity.app adresine yazabilirsiniz.\n\nAyrıca yetkili veri koruma otoritesine şikayette bulunma hakkınız saklıdır.',
          en:
              'For privacy-related questions, contact privacy@pulsecity.app.\n\nYou also retain the right to lodge a complaint with the competent data protection authority.',
          de:
              'Bei datenschutzbezogenen Fragen schreiben Sie an privacy@pulsecity.app.\n\nSie haben außerdem das Recht, sich bei der zuständigen Datenschutzaufsichtsbehörde zu beschweren.',
        ),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections(context);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr3(
            tr: 'Gizlilik Politikası',
            en: 'Privacy Policy',
            de: 'Datenschutzerklärung',
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        itemCount: sections.length + 1,
        separatorBuilder: (_, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Text(
                context.tr3(
                  tr: 'PulseCity gizliliği ürün tasarımının merkezine koyar. Bu politika, hangi verilerin toplandığını, neden kullanıldığını ve kontrolün nasıl sizde kaldığını açıklar.',
                  en: 'PulseCity places privacy at the center of the product experience. This policy explains what data is collected, why it is used, and how control stays with you.',
                  de: 'PulseCity stellt Datenschutz in den Mittelpunkt des Produkterlebnisses. Diese Richtlinie erklärt, welche Daten erhoben werden, warum sie genutzt werden und wie die Kontrolle bei Ihnen bleibt.',
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            );
          }

          final section = sections[index - 1];
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section['title']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  section['content']!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
