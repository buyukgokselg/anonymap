import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../theme/colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  List<Map<String, String>> _sections(BuildContext context) {
    return [
      {
        'title': context.tr3(
          tr: '1. Hizmet tanımı',
          en: '1. Description of the service',
          de: '1. Beschreibung des Dienstes',
        ),
        'content': context.tr3(
          tr:
              'PulseCity, şehirdeki sosyal hareketi ve mekânsal bağlamı gerçek zamanlı analiz ederek kişiselleştirilmiş şehir keşfi sunan bir urban intelligence uygulamasıdır.',
          en:
              'PulseCity is an urban intelligence application that analyzes live social movement and spatial context to offer personalized city discovery.',
          de:
              'PulseCity ist eine Urban-Intelligence-Anwendung, die soziale Bewegung und räumlichen Kontext in Echtzeit analysiert, um personalisierte Stadterkundung zu ermöglichen.',
        ),
      },
      {
        'title': context.tr3(
          tr: '2. Kullanıcı uygunluğu',
          en: '2. Eligibility',
          de: '2. Nutzungsberechtigung',
        ),
        'content': context.tr3(
          tr:
              'PulseCity kullanmak için en az 18 yaşında olmanız gerekir. Hesap bilgilerinizin doğru, güncel ve size ait olduğunu taahhüt edersiniz.',
          en:
              'You must be at least 18 years old to use PulseCity. You agree that the account information you provide is accurate, current, and yours to use.',
          de:
              'Für die Nutzung von PulseCity müssen Sie mindestens 18 Jahre alt sein. Sie sichern zu, dass Ihre Kontodaten korrekt, aktuell und von Ihnen rechtmäßig nutzbar sind.',
        ),
      },
      {
        'title': context.tr3(
          tr: '3. Konum ve gizlilik',
          en: '3. Location and privacy',
          de: '3. Standort und Datenschutz',
        ),
        'content': context.tr3(
          tr:
              'PulseCity, öneri ve sosyal alan işlevleri için konum verilerini kullanır. Kullanım, uygulama izinleriniz, ghost mode tercihiniz, görünürlük seviyeniz ve gizlilik ayarlarınızla sınırlanır.',
          en:
              'PulseCity uses location data to power recommendations and social field features. Usage is limited by your app permissions, ghost mode preference, visibility level, and privacy settings.',
          de:
              'PulseCity verwendet Standortdaten für Empfehlungen und Funktionen des sozialen Feldes. Die Nutzung ist durch Ihre Berechtigungen, den Ghost Mode, Ihre Sichtbarkeit und Datenschutzeinstellungen begrenzt.',
        ),
      },
      {
        'title': context.tr3(
          tr: '4. Yasaklı davranışlar',
          en: '4. Prohibited behavior',
          de: '4. Verbotenes Verhalten',
        ),
        'content': context.tr3(
          tr:
              'Şu davranışlar yasaktır:\n\n• Taciz, tehdit, nefret söylemi veya ayrımcılık\n• Sahte profil, kimlik taklidi veya dolandırıcılık\n• Açık rıza olmadan başkalarına ait veri veya medya paylaşımı\n• Sistemi manipüle etmeye yönelik otomasyon, spam veya kötüye kullanım\n• Yasalara aykırı faaliyetler',
          en:
              'The following behavior is prohibited:\n\n• Harassment, threats, hate speech, or discrimination\n• Fake profiles, impersonation, or fraud\n• Sharing someone else\'s data or media without clear consent\n• Automation, spam, or abuse intended to manipulate the system\n• Illegal activity',
          de:
              'Folgendes Verhalten ist untersagt:\n\n• Belästigung, Drohungen, Hassrede oder Diskriminierung\n• Fake-Profile, Identitätsdiebstahl oder Betrug\n• Das Teilen fremder Daten oder Medien ohne klare Zustimmung\n• Automatisierung, Spam oder Missbrauch zur Manipulation des Systems\n• Rechtswidrige Aktivitäten',
        ),
      },
      {
        'title': context.tr3(
          tr: '5. İçerik ve moderasyon',
          en: '5. Content and moderation',
          de: '5. Inhalte und Moderation',
        ),
        'content': context.tr3(
          tr:
              'Paylaşımlarınız, yorumlarınız ve durumlarınız topluluk güvenliği için denetlenebilir. PulseCity, raporlanan veya riskli görünen içerikleri inceleme, sınırlama veya kaldırma hakkını saklı tutar.',
          en:
              'Your posts, comments, and stories may be reviewed for community safety. PulseCity reserves the right to review, limit, or remove reported or risky content.',
          de:
              'Ihre Beiträge, Kommentare und Stories können für die Sicherheit der Community überprüft werden. PulseCity behält sich das Recht vor, gemeldete oder riskante Inhalte zu prüfen, einzuschränken oder zu entfernen.',
        ),
      },
      {
        'title': context.tr3(
          tr: '6. Hesap güvenliği',
          en: '6. Account security',
          de: '6. Kontosicherheit',
        ),
        'content': context.tr3(
          tr:
              'Hesabınızın güvenliğinden, cihaz erişiminizden ve şifrenizin korunmasından siz sorumlusunuz. Yetkisiz erişim fark ettiğinizde destek ekibiyle hemen iletişime geçmelisiniz.',
          en:
              'You are responsible for the security of your account, access to your device, and protection of your password. If you notice unauthorized access, you must contact support immediately.',
          de:
              'Sie sind für die Sicherheit Ihres Kontos, den Zugriff auf Ihr Gerät und den Schutz Ihres Passworts verantwortlich. Wenn Sie unbefugten Zugriff bemerken, müssen Sie den Support sofort kontaktieren.',
        ),
      },
      {
        'title': context.tr3(
          tr: '7. Hizmette değişiklik',
          en: '7. Changes to the service',
          de: '7. Änderungen am Dienst',
        ),
        'content': context.tr3(
          tr:
              'PulseCity, ürün deneyimini, fiyatlandırmayı, özellikleri veya güvenlik politikalarını zaman içinde güncelleyebilir. Önemli değişiklikler uygulama içinde veya ilgili iletişim kanallarında duyurulur.',
          en:
              'PulseCity may update the product experience, pricing, features, or safety policies over time. Material changes will be communicated in the app or through relevant communication channels.',
          de:
              'PulseCity kann Produkterlebnis, Preise, Funktionen oder Sicherheitsrichtlinien im Laufe der Zeit aktualisieren. Wesentliche Änderungen werden in der App oder über geeignete Kommunikationskanäle bekannt gegeben.',
        ),
      },
      {
        'title': context.tr3(
          tr: '8. Sorumluluğun sınırı',
          en: '8. Limitation of liability',
          de: '8. Haftungsbeschränkung',
        ),
        'content': context.tr3(
          tr:
              'PulseCity, şehirdeki anlık sinyaller ve öneriler için makul çaba gösterir; ancak tüm verilerin her zaman eksiksiz, kesintisiz veya hatasız olacağı garanti edilmez. Yasal olarak izin verilen ölçüde dolaylı zararlar için sorumluluk sınırlandırılır.',
          en:
              'PulseCity makes reasonable efforts to provide timely signals and recommendations, but does not guarantee that all data will always be complete, uninterrupted, or error free. To the extent permitted by law, liability for indirect damages is limited.',
          de:
              'PulseCity unternimmt angemessene Anstrengungen, um aktuelle Signale und Empfehlungen bereitzustellen, garantiert jedoch nicht, dass alle Daten jederzeit vollständig, unterbrechungsfrei oder fehlerfrei sind. Soweit gesetzlich zulässig, ist die Haftung für indirekte Schäden begrenzt.',
        ),
      },
      {
        'title': context.tr3(
          tr: '9. Hesabın askıya alınması ve silinmesi',
          en: '9. Suspension and deletion',
          de: '9. Sperrung und Löschung',
        ),
        'content': context.tr3(
          tr:
              'Bu koşulları ihlal etmeniz halinde hesabınız geçici olarak sınırlandırılabilir, askıya alınabilir veya silinebilir. Siz de istediğiniz zaman uygulama ayarlarından hesabınızı silebilirsiniz.',
          en:
              'If you violate these terms, your account may be restricted, suspended, or deleted. You may also delete your account at any time from the app settings.',
          de:
              'Wenn Sie gegen diese Bedingungen verstoßen, kann Ihr Konto eingeschränkt, gesperrt oder gelöscht werden. Sie können Ihr Konto auch jederzeit in den App-Einstellungen löschen.',
        ),
      },
      {
        'title': context.tr3(
          tr: '10. İletişim',
          en: '10. Contact',
          de: '10. Kontakt',
        ),
        'content': context.tr3(
          tr:
              'Bu koşullarla ilgili sorularınız için support@pulsecity.app adresine yazabilirsiniz.',
          en:
              'For questions about these terms, contact support@pulsecity.app.',
          de:
              'Bei Fragen zu diesen Bedingungen schreiben Sie an support@pulsecity.app.',
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
            tr: 'Kullanım Koşulları',
            en: 'Terms of Service',
            de: 'Nutzungsbedingungen',
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
                  tr: 'Bu koşullar, PulseCity hizmetini kullanırken uyacağınız temel kuralları ve hakları açıklar.',
                  en: 'These terms explain the core rules and rights that apply when you use the PulseCity service.',
                  de: 'Diese Bedingungen erklären die grundlegenden Regeln und Rechte für die Nutzung des PulseCity-Dienstes.',
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
