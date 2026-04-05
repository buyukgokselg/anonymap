import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          'Kullanım Koşulları',
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
            const SizedBox(height: 24),
            _buildSection(
              '1. Hizmet Tanımı',
              'PulseCity, şehirdeki sosyal hareketi gerçek zamanlı analiz ederek '
              'kullanıcılarına kişiselleştirilmiş şehir keşfi sunan bir Urban Intelligence '
              'platformudur. Uygulama, konum verilerini anonim ve aggregate biçimde işleyerek '
              'kullanıcılara yoğunluk haritaları, ortam önerileri ve sosyal uyumluluk skorları sunar.',
            ),
            _buildSection(
              '2. Kullanıcı Uygunluğu',
              'PulseCity\'yi kullanabilmek için en az 18 yaşında olmanız gerekmektedir. '
              'Hesap oluştururken verdiğiniz bilgilerin doğru ve güncel olduğunu taahhüt edersiniz. '
              'Hesabınızın güvenliğinden siz sorumlusunuz; şifrenizi kimseyle paylaşmamalısınız.',
            ),
            _buildSection(
              '3. Konum Verileri ve Gizlilik',
              'PulseCity, hizmetlerini sunabilmek için konum verilerinizi kullanır. '
              'Konum verileri şu ilkelere göre işlenir:\n\n'
              '• Differential Privacy: Bireysel veriye gürültü eklenerek aggregate istatistikler üretilir.\n'
              '• k-Anonymity (k≥10): Minimum 10 kişi olmadan bölge verisi gösterilmez.\n'
              '• Data Minimization: Sadece gerekli veri toplanır, ham GPS logu 24 saat içinde silinir.\n'
              '• Ghost Mode: Tam görünmezlik seçeneği her zaman mevcuttur.\n\n'
              'Konum verileriniz asla üçüncü taraflarla bireysel olarak paylaşılmaz.',
            ),
            _buildSection(
              '4. Kullanıcı Davranışları',
              'Aşağıdaki davranışlar kesinlikle yasaktır:\n\n'
              '• Diğer kullanıcıları takip etmek, taciz etmek veya tehdit etmek.\n'
              '• Sahte konum verisi göndermek veya sistemi manipüle etmeye çalışmak.\n'
              '• Nefret söylemi, ayrımcılık veya yasadışı içerik paylaşmak.\n'
              '• Uygulamayı tersine mühendislik yapmak, kaynak kodunu çıkarmak.\n'
              '• Otomatik bot veya script kullanarak veri toplamak.\n'
              '• Başkalarının kişisel bilgilerini izinsiz paylaşmak.\n\n'
              'Bu kuralları ihlal eden hesaplar uyarı verilmeksizin askıya alınabilir veya silinebilir.',
            ),
            _buildSection(
              '5. Vibe Tags ve Kullanıcı İçerikleri',
              'Kullanıcılar tarafından oluşturulan Vibe Tag\'ler ve diğer içerikler, '
              'topluluk kurallarına uygun olmalıdır. PulseCity, uygunsuz içerikleri '
              'önceden haber vermeksizin kaldırma hakkını saklı tutar. '
              'Oluşturduğunuz içeriklerin fikri mülkiyeti size ait olmaya devam eder; '
              'ancak PulseCity\'ye bu içerikleri platform içinde kullanma lisansı vermiş olursunuz.',
            ),
            _buildSection(
              '6. Premium Abonelik',
              'PulseCity ücretsiz temel özellikler sunar. Premium abonelik aylık veya '
              'yıllık olarak satın alınabilir. Abonelikler, iptal edilmediği sürece '
              'otomatik olarak yenilenir. İptal işlemi, mevcut dönemin sonuna kadar '
              'geçerli olur; kalan süre için iade yapılmaz. Fiyatlar önceden bildirim '
              'yapılarak değiştirilebilir.',
            ),
            _buildSection(
              '7. Sorumluluk Sınırları',
              'PulseCity, sunduğu yoğunluk verileri ve önerilerin doğruluğunu garanti etmez. '
              'Tahminler istatistiksel modellere dayanır ve güven aralıkları ile sunulur. '
              'Kullanıcıların PulseCity önerilerine dayanarak aldıkları kararlardan '
              'PulseCity sorumlu tutulamaz. Platform "olduğu gibi" sunulmaktadır.',
            ),
            _buildSection(
              '8. Hesap Silme ve Veri Taşınabilirliği',
              'Hesabınızı istediğiniz zaman silebilirsiniz. Hesap silme işlemi sonrasında:\n\n'
              '• Tüm kişisel verileriniz 72 saat içinde tüm yedeklemelerden silinir.\n'
              '• Daha önce katkıda bulunduğunuz anonim aggregate veriler sistemde kalabilir.\n'
              '• Tüm verilerinizi JSON formatında dışa aktarabilirsiniz (Data Portability).\n'
              '• Silme işlemi geri alınamaz.',
            ),
            _buildSection(
              '9. Değişiklikler',
              'PulseCity, bu kullanım koşullarını önceden bildirim yaparak değiştirme '
              'hakkını saklı tutar. Önemli değişiklikler uygulama içi bildirim ve e-posta '
              'yoluyla duyurulur. Değişikliklerden sonra uygulamayı kullanmaya devam etmeniz, '
              'güncellenmiş koşulları kabul ettiğiniz anlamına gelir.',
            ),
            _buildSection(
              '10. Uygulanacak Hukuk',
              'Bu koşullar Almanya Federal Cumhuriyeti yasalarına tabidir. '
              'Uyuşmazlıklar Hamburg mahkemelerinde çözüme kavuşturulur. '
              'AB tüketici koruma mevzuatından doğan haklarınız saklıdır.',
            ),
            _buildSection(
              '11. İletişim',
              'Bu koşullarla ilgili sorularınız için:\n\n'
              'E-posta: legal@pulsecity.app\n'
              'Adres: PulseCity GmbH, Hamburg, Almanya',
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