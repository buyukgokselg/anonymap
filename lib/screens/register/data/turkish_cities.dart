/// Türkiye'nin 81 ilinin alfabetik sırada (Türkçe collation) statik listesi.
///
/// Free-text "şehir" alanını değiştirmek için kullanılır — kullanıcının
/// "İstanbul" / "istanbul" / "Istanbul" gibi varyantlar girmesini önler ve
/// `DiscoverService`'in coğrafi filtrelemesini güvenilir hâle getirir.
///
/// Diakritiksiz arama için `searchKey` üretilir; arama input'u da aynı
/// şekilde normalize edildiğinde "izmir" yazınca "İzmir" bulunur.
class TurkishCity {
  const TurkishCity({required this.name, required this.searchKey});
  final String name;
  final String searchKey;
}

const List<TurkishCity> kTurkishCities = <TurkishCity>[
  TurkishCity(name: 'Adana', searchKey: 'adana'),
  TurkishCity(name: 'Adıyaman', searchKey: 'adiyaman'),
  TurkishCity(name: 'Afyonkarahisar', searchKey: 'afyonkarahisar'),
  TurkishCity(name: 'Ağrı', searchKey: 'agri'),
  TurkishCity(name: 'Aksaray', searchKey: 'aksaray'),
  TurkishCity(name: 'Amasya', searchKey: 'amasya'),
  TurkishCity(name: 'Ankara', searchKey: 'ankara'),
  TurkishCity(name: 'Antalya', searchKey: 'antalya'),
  TurkishCity(name: 'Ardahan', searchKey: 'ardahan'),
  TurkishCity(name: 'Artvin', searchKey: 'artvin'),
  TurkishCity(name: 'Aydın', searchKey: 'aydin'),
  TurkishCity(name: 'Balıkesir', searchKey: 'balikesir'),
  TurkishCity(name: 'Bartın', searchKey: 'bartin'),
  TurkishCity(name: 'Batman', searchKey: 'batman'),
  TurkishCity(name: 'Bayburt', searchKey: 'bayburt'),
  TurkishCity(name: 'Bilecik', searchKey: 'bilecik'),
  TurkishCity(name: 'Bingöl', searchKey: 'bingol'),
  TurkishCity(name: 'Bitlis', searchKey: 'bitlis'),
  TurkishCity(name: 'Bolu', searchKey: 'bolu'),
  TurkishCity(name: 'Burdur', searchKey: 'burdur'),
  TurkishCity(name: 'Bursa', searchKey: 'bursa'),
  TurkishCity(name: 'Çanakkale', searchKey: 'canakkale'),
  TurkishCity(name: 'Çankırı', searchKey: 'cankiri'),
  TurkishCity(name: 'Çorum', searchKey: 'corum'),
  TurkishCity(name: 'Denizli', searchKey: 'denizli'),
  TurkishCity(name: 'Diyarbakır', searchKey: 'diyarbakir'),
  TurkishCity(name: 'Düzce', searchKey: 'duzce'),
  TurkishCity(name: 'Edirne', searchKey: 'edirne'),
  TurkishCity(name: 'Elazığ', searchKey: 'elazig'),
  TurkishCity(name: 'Erzincan', searchKey: 'erzincan'),
  TurkishCity(name: 'Erzurum', searchKey: 'erzurum'),
  TurkishCity(name: 'Eskişehir', searchKey: 'eskisehir'),
  TurkishCity(name: 'Gaziantep', searchKey: 'gaziantep'),
  TurkishCity(name: 'Giresun', searchKey: 'giresun'),
  TurkishCity(name: 'Gümüşhane', searchKey: 'gumushane'),
  TurkishCity(name: 'Hakkâri', searchKey: 'hakkari'),
  TurkishCity(name: 'Hatay', searchKey: 'hatay'),
  TurkishCity(name: 'Iğdır', searchKey: 'igdir'),
  TurkishCity(name: 'Isparta', searchKey: 'isparta'),
  TurkishCity(name: 'İstanbul', searchKey: 'istanbul'),
  TurkishCity(name: 'İzmir', searchKey: 'izmir'),
  TurkishCity(name: 'Kahramanmaraş', searchKey: 'kahramanmaras'),
  TurkishCity(name: 'Karabük', searchKey: 'karabuk'),
  TurkishCity(name: 'Karaman', searchKey: 'karaman'),
  TurkishCity(name: 'Kars', searchKey: 'kars'),
  TurkishCity(name: 'Kastamonu', searchKey: 'kastamonu'),
  TurkishCity(name: 'Kayseri', searchKey: 'kayseri'),
  TurkishCity(name: 'Kilis', searchKey: 'kilis'),
  TurkishCity(name: 'Kırıkkale', searchKey: 'kirikkale'),
  TurkishCity(name: 'Kırklareli', searchKey: 'kirklareli'),
  TurkishCity(name: 'Kırşehir', searchKey: 'kirsehir'),
  TurkishCity(name: 'Kocaeli', searchKey: 'kocaeli'),
  TurkishCity(name: 'Konya', searchKey: 'konya'),
  TurkishCity(name: 'Kütahya', searchKey: 'kutahya'),
  TurkishCity(name: 'Malatya', searchKey: 'malatya'),
  TurkishCity(name: 'Manisa', searchKey: 'manisa'),
  TurkishCity(name: 'Mardin', searchKey: 'mardin'),
  TurkishCity(name: 'Mersin', searchKey: 'mersin'),
  TurkishCity(name: 'Muğla', searchKey: 'mugla'),
  TurkishCity(name: 'Muş', searchKey: 'mus'),
  TurkishCity(name: 'Nevşehir', searchKey: 'nevsehir'),
  TurkishCity(name: 'Niğde', searchKey: 'nigde'),
  TurkishCity(name: 'Ordu', searchKey: 'ordu'),
  TurkishCity(name: 'Osmaniye', searchKey: 'osmaniye'),
  TurkishCity(name: 'Rize', searchKey: 'rize'),
  TurkishCity(name: 'Sakarya', searchKey: 'sakarya'),
  TurkishCity(name: 'Samsun', searchKey: 'samsun'),
  TurkishCity(name: 'Şanlıurfa', searchKey: 'sanliurfa'),
  TurkishCity(name: 'Siirt', searchKey: 'siirt'),
  TurkishCity(name: 'Sinop', searchKey: 'sinop'),
  TurkishCity(name: 'Şırnak', searchKey: 'sirnak'),
  TurkishCity(name: 'Sivas', searchKey: 'sivas'),
  TurkishCity(name: 'Tekirdağ', searchKey: 'tekirdag'),
  TurkishCity(name: 'Tokat', searchKey: 'tokat'),
  TurkishCity(name: 'Trabzon', searchKey: 'trabzon'),
  TurkishCity(name: 'Tunceli', searchKey: 'tunceli'),
  TurkishCity(name: 'Uşak', searchKey: 'usak'),
  TurkishCity(name: 'Van', searchKey: 'van'),
  TurkishCity(name: 'Yalova', searchKey: 'yalova'),
  TurkishCity(name: 'Yozgat', searchKey: 'yozgat'),
  TurkishCity(name: 'Zonguldak', searchKey: 'zonguldak'),
];

/// Kullanıcı girdisini diakritiksiz/küçük harfe normalize eder.
String normalizeCityQuery(String input) {
  final lowered = input.trim().toLowerCase();
  const map = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'i̇': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  final buffer = StringBuffer();
  for (final ch in lowered.split('')) {
    buffer.write(map[ch] ?? ch);
  }
  return buffer.toString();
}
