import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gizlilik Politikası',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdated(),
            const SizedBox(height: 20),
            _buildHighlight(
              Icons.shield_outlined,
              'Privacy-First Tasarım',
              'PulseCity, gizliliği sonradan eklenen bir özellik olarak değil, '
              'temel tasarım ilkesi olarak benimser. GDPR ve ePrivacy '
              'Yönetmeliği\'ne tam uyumludur.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Veri Sorumlusu',
              'Verilerinizin sorumlusu PulseCity GmbH\'dir.\n\n'
              'Adres: Hamburg, Almanya\n'
              'E-posta: privacy@pulsecity.app\n'
              'Veri Koruma Görevlisi (DPO): dpo@pulsecity.app',
            ),
            _buildSection(
              '2. Toplanan Veriler',
              'PulseCity aşağıdaki verileri toplar:\n\n'
              'Hesap Bilgileri: E-posta adresi, şifreli parola, yaş aralığı, cinsiyet, ilgi alanları.\n\n'
              'Konum Verileri: GPS koordinatları (yalnızca uygulama aktifken ve izninizle). '
              'Ham konum verileri 24 saat içinde silinir ve yalnızca aggregate formda saklanır.\n\n'
              'Kullanım Verileri: Seçilen intent modu, kalış süresi, etkileşim tercihleri. '
              'Bu veriler kişiselleştirilmiş öneriler için kullanılır.\n\n'
              'Kullanıcı İçerikleri: Vibe Tag\'ler, ortam geri bildirimleri, check-in\'ler.',
            ),
            _buildSection(
              '3. Veri İşleme Amaçları',
              '• Şehir yoğunluk haritası ve Pulse Score hesaplama\n'
              '• Kişiselleştirilmiş mekan ve zaman önerileri sunma\n'
              '• Social Compatibility Index hesaplama\n'
              '• Temporal Forecasting (zaman tahmini) modelleri\n'
              '• Hizmet kalitesini iyileştirme ve hata tespiti\n'
              '• Yasal yükümlülüklerin yerine getirilmesi',
            ),
            _buildSection(
              '4. Gizlilik Teknolojileri',
              'PulseCity aşağıdaki gizlilik koruma teknolojilerini kullanır:\n\n'
              'Differential Privacy: Bireysel verilere matematiksel gürültü eklenerek '
              'kişisel bilgilerin çıkarılması engellenir.\n\n'
              'k-Anonymity (k≥10): Bir bölgede en az 10 kullanıcı olmadan '
              'o bölgeye ait hiçbir veri gösterilmez.\n\n'
              'Veri Minimizasyonu: Yalnızca hizmet için gerekli olan veriler toplanır.\n\n'
              'Uçtan Uca Şifreleme: Tüm veri iletimi TLS 1.3 ile şifrelenir.\n\n'
              'Granularity Control: Konum hassasiyetinizi siz seçersiniz — '
              'mahalle, semt veya şehir seviyesi.',
            ),
            _buildSection(
              '5. Ghost Mode',
              'Ghost Mode aktif edildiğinde:\n\n'
              '• Hiçbir konum verisi toplanmaz veya paylaşılmaz.\n'
              '• Aggregate verilere katkı yapmazsınız.\n'
              '• Diğer kullanıcılar sizin varlığınızdan habersizdir.\n'
              '• Yalnızca veri tüketirsiniz, üretmezsiniz.\n\n'
              'Ghost Mode her zaman, herhangi bir gerekçe belirtmeden aktif edilebilir.',
            ),
            _buildSection(
              '6. Veri Paylaşımı',
              'Kişisel verileriniz hiçbir koşulda üçüncü taraflarla bireysel olarak paylaşılmaz.\n\n'
              'Anonim ve aggregate veriler aşağıdaki amaçlarla paylaşılabilir:\n\n'
              '• Venue ortakları: Mekan sahiplerine anonim ziyaretçi istatistikleri.\n'
              '• Şehir analitikleri: Belediyelere toplu yaya akışı verileri.\n'
              '• Araştırma: Akademik çalışmalar için tam anonimleştirilmiş veri setleri.\n\n'
              'Tüm paylaşımlarda bireysel kullanıcıların kimliği belirlenemez.',
            ),
            _buildSection(
              '7. Veri Saklama Süreleri',
              '• Ham GPS verileri: Maksimum 24 saat\n'
              '• Aggregate yoğunluk verileri: 2 yıl\n'
              '• Hesap bilgileri: Hesap aktif olduğu sürece\n'
              '• Vibe Tag\'ler: Oluşturulmasından itibaren 1 yıl\n'
              '• Kullanım logları: 90 gün\n\n'
              'Süresi dolan veriler otomatik olarak silinir.',
            ),
            _buildSection(
              '8. Haklarınız (GDPR)',
              'GDPR kapsamında aşağıdaki haklara sahipsiniz:\n\n'
              '• Erişim Hakkı: Hangi verilerinizin işlendiğini öğrenme.\n'
              '• Düzeltme Hakkı: Yanlış verilerin düzeltilmesini isteme.\n'
              '• Silme Hakkı: Tüm verilerinizin silinmesini talep etme. '
              'Silme talebi 72 saat içinde tüm yedeklemelerden uygulanır.\n'
              '• Taşınabilirlik Hakkı: Verilerinizi JSON formatında dışa aktarma.\n'
              '• İtiraz Hakkı: Veri işlemeye itiraz etme.\n'
              '• Kısıtlama Hakkı: Veri işlemenin sınırlandırılmasını isteme.\n\n'
              'Haklarınızı kullanmak için: privacy@pulsecity.app',
            ),
            _buildSection(
              '9. Çerezler ve İzleme',
              'PulseCity mobil uygulaması çerez kullanmaz. '
              'Üçüncü taraf izleme araçları (reklam SDK\'ları, analytics trackerlar) kullanılmaz. '
              'Yalnızca hizmet kalitesi için anonim hata raporlaması yapılır.',
            ),
            _buildSection(
              '10. Çocukların Gizliliği',
              'PulseCity 18 yaş altı bireylere yönelik değildir. '
              '18 yaşından küçük bir bireyin hesap oluşturduğu tespit edilirse, '
              'hesap ve ilişkili tüm veriler derhal silinir.',
            ),
            _buildSection(
              '11. Değişiklikler',
              'Gizlilik politikasında yapılacak değişiklikler uygulama içi bildirim '
              've e-posta yoluyla en az 30 gün önceden duyurulur. '
              'Önemli değişiklikler için yeniden onayınız istenebilir.',
            ),
            _buildSection(
              '12. Şikayet Hakkı',
              'Veri işleme uygulamalarımızla ilgili şikayetlerinizi '
              'Hamburg Veri Koruma Otoritesi\'ne (HmbBfDI) iletebilirsiniz.\n\n'
              'Web: https://datenschutz-hamburg.de',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.update_rounded,
              size: 16, color: AppColors.primary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(
            'Son güncelleme: Nisan 2026',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlight(IconData icon, String title, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.55),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}