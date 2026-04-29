/// Kayıt akışı (RegisterFlowScreen) boyunca adımlar arasında taşınan
/// kullanıcı verisi. Her adım sadece kendi alanını set eder; en sonda
/// `toApiRequest()` ile sunucuya tek bir istek olarak gönderilir.
///
/// Mutable bir veri taşıyıcısıdır — UI state ile birlikte yaşar ve
/// `dispose` zamanı boş bırakılır (özel bir kaynak tutmaz).
class RegistrationDraft {
  // ── Hesap bilgisi ──
  String email = '';
  String password = '';

  // ── Kimlik ──
  String firstName = '';
  DateTime? birthDate;
  String gender = ''; // female | male | nonbinary

  // ── Niyet ──
  /// Kim ile eşleşmek istediği (cinsiyet tercihi).
  /// Şimdilik gender'a göre otomatik türetiliyor; ileride ayrı adıma çıkabilir.
  String matchPreference = 'auto';

  /// Tanışma niyeti (flirt | friends | fun | chill).
  String mode = '';

  // ── Konum ──
  String city = '';

  // ── Onaylar ──
  bool acceptedTerms = false;
  bool acceptedAge = false;

  bool get hasEmail => RegExp(
    r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$',
  ).hasMatch(email.trim());

  bool get hasStrongPassword => password.length >= 8;

  bool get hasName => firstName.trim().isNotEmpty;

  bool get hasBirthDate {
    final birth = birthDate;
    if (birth == null) return false;
    final today = DateTime.now();
    final adulthood = DateTime(today.year - 18, today.month, today.day);
    return !birth.isAfter(adulthood);
  }

  bool get hasGender => gender.isNotEmpty;

  bool get hasMode => mode.isNotEmpty;

  bool get hasCity => city.trim().isNotEmpty;

  bool get hasAllConsents => acceptedTerms && acceptedAge;

  /// Kullanıcının yaşını doğum tarihine göre hesaplar.
  /// `birthDate` set değilse `null` döner.
  int? get age {
    final birth = birthDate;
    if (birth == null) return null;
    final today = DateTime.now();
    var years = today.year - birth.year;
    final hasHadBirthdayThisYear =
        today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);
    if (!hasHadBirthdayThisYear) years -= 1;
    return years < 0 ? 0 : years;
  }

  /// Şu adımdan sonra ileri gidilebilir mi?
  bool canAdvanceFromStep(RegisterStep step) {
    return switch (step) {
      RegisterStep.welcome => true,
      RegisterStep.account => hasEmail && hasStrongPassword,
      RegisterStep.identity => hasName && hasBirthDate,
      RegisterStep.gender => hasGender,
      RegisterStep.mode => hasMode,
      RegisterStep.city => hasCity,
      RegisterStep.terms => hasAllConsents,
      RegisterStep.success => true,
    };
  }

  /// API'ye gönderilecek payload alanları.
  /// `AuthService.register` parametre listesiyle birebir uyumlu.
  Map<String, Object?> toApiPayload() {
    return {
      'firstName': firstName.trim(),
      'email': email.trim(),
      'password': password,
      'city': city.trim(),
      'gender': gender,
      'birthDate': birthDate!,
      'mode': mode,
      'matchPreference': matchPreference,
    };
  }
}

/// Kayıt akışındaki adımlar — `PageView` index'leriyle birebir eşleşir.
enum RegisterStep {
  welcome, // 0
  account, // 1 — e-posta + şifre
  identity, // 2 — ad + doğum tarihi
  gender, // 3
  mode, // 4 — flört / arkadaşlık / eğlence / chill
  city, // 5
  terms, // 6 — onay + submit
  success; // 7 — başarı kutlaması
}
