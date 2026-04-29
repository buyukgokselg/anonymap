import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../services/app_locale_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/pulse_api_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'home_shell_screen.dart';
import 'onboarding_screen.dart';
import 'reset_password_screen.dart';
import 'register/register_flow_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _pulseApi = PulseApiService.instance;

  late final AnimationController _pulseController;
  late final AnimationController _orbitController;

  Timer? _snapshotTimer;
  bool _obscurePassword = true;
  bool _isLoading = false;
  int _activeUsers = 18;
  int _livePlaces = 12;
  int _risingZones = 4;
  List<_LobbyOrbitDot> _orbitDots = const [
    _LobbyOrbitDot(
      color: AppColors.modeKesif,
      radius: 62,
      size: 9,
      angleOffset: 0.15,
      speed: 0.75,
    ),
    _LobbyOrbitDot(
      color: AppColors.modeSosyal,
      radius: 62,
      size: 10,
      angleOffset: 1.35,
      speed: 0.92,
    ),
    _LobbyOrbitDot(
      color: AppColors.modeAcikAlan,
      radius: 62,
      size: 8,
      angleOffset: 2.4,
      speed: 0.64,
    ),
    _LobbyOrbitDot(
      color: AppColors.modeTopluluk,
      radius: 62,
      size: 8,
      angleOffset: 3.5,
      speed: 0.86,
    ),
    _LobbyOrbitDot(
      color: AppColors.modeKesif,
      radius: 92,
      size: 8,
      angleOffset: 0.75,
      speed: 0.42,
    ),
    _LobbyOrbitDot(
      color: AppColors.modeSakinlik,
      radius: 92,
      size: 7,
      angleOffset: 1.95,
      speed: 0.52,
    ),
    _LobbyOrbitDot(
      color: AppColors.modeEglence,
      radius: 92,
      size: 9,
      angleOffset: 3.15,
      speed: 0.58,
    ),
    _LobbyOrbitDot(
      color: AppColors.modeUretkenlik,
      radius: 122,
      size: 7,
      angleOffset: 4.3,
      speed: 0.47,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat(reverse: true);
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    unawaited(_loadLobbySnapshot());
    _snapshotTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_loadLobbySnapshot()),
    );
  }

  @override
  void dispose() {
    _snapshotTimer?.cancel();
    _orbitController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadLobbySnapshot() async {
    if (!_pulseApi.isEnabled) return;

    try {
      final snapshot = await _pulseApi.getLobbySnapshot();
      if (!mounted || snapshot == null) return;

      final modeActivity =
          (snapshot['modeActivity'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const <Map<String, dynamic>>[];

      setState(() {
        _activeUsers = _readInt(snapshot['activeUsers'], fallback: _activeUsers);
        _livePlaces = _readInt(snapshot['livePlaces'], fallback: _livePlaces);
        _risingZones = _readInt(snapshot['risingZones'], fallback: _risingZones);
        _orbitDots = _buildOrbitDots(modeActivity);
      });
    } catch (e, st) {
      debugPrint('Lobby snapshot load failed: $e\n$st');
    }
  }

  int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed ?? fallback;
  }

  Color _modeColor(String mode) => ModeConfig.byId(mode).color;

  List<_LobbyOrbitDot> _buildOrbitDots(List<Map<String, dynamic>> activity) {
    if (activity.isEmpty) return _orbitDots;

    const ringPattern = <double>[
      64,
      64,
      64,
      64,
      96,
      96,
      96,
      96,
      122,
      122,
      122,
      122,
    ];
    final dots = <_LobbyOrbitDot>[];
    var angleCursor = 0.0;

    for (final item in activity) {
      final mode = ModeConfig.normalizeId(item['mode']?.toString());
      final count = _readInt(item['count'], fallback: 1).clamp(1, 4);
      for (var i = 0; i < count; i++) {
        final index = dots.length % ringPattern.length;
        final radius = ringPattern[index];
        dots.add(
          _LobbyOrbitDot(
            color: _modeColor(mode),
            radius: radius,
            size: radius >= 120 ? 7 : radius >= 96 ? 8 : 10,
            angleOffset: angleCursor,
            speed: radius >= 120
                ? 0.24 + (i * 0.04)
                : radius >= 96
                ? 0.38 + (i * 0.05)
                : 0.62 + (i * 0.06),
          ),
        );
        angleCursor += 0.74;
        if (dots.length >= 12) {
          return dots;
        }
      }
    }

    return dots;
  }

  Future<void> _login() async {
    final l10n = context.l10n;
    final selectedLanguage = AppLocaleService.instance.languageCode;
    FocusScope.of(context).unfocus();
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError(l10n.t('fill_all_fields'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _completeAuthFlow(selectedLanguage);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    final selectedLanguage = AppLocaleService.instance.languageCode;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) return;
      await _completeAuthFlow(selectedLanguage);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeAuthFlow(String selectedLanguage) async {
    await _syncPreferredLanguage(selectedLanguage);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) =>
            _authService.currentUser?.isOnboarded == true
            ? const HomeShellScreen()
            : const OnboardingScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _syncPreferredLanguage(String languageCode) async {
    final session = _authService.currentUser;
    if (session == null || session.userId.isEmpty) return;
    if (session.preferredLanguage == languageCode) {
      await AppLocaleService.instance.setLanguageCode(languageCode);
      return;
    }

    try {
      await _firestoreService.updateProfile(session.userId, {
        'preferredLanguage': languageCode,
      });
      await AppLocaleService.instance.setLanguageCode(languageCode);
    } catch (e, st) {
      debugPrint('Preferred language sync failed: $e\n$st');
    }
  }

  Future<void> _selectLanguage(String code) async {
    await AppLocaleService.instance.setLanguageCode(code);
    if (mounted) {
      setState(() {});
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLobbyHero(
    AppLocalizations l10n, {
    required bool compact,
    required bool dense,
    required double heroSize,
  }) {
    final titleSize = dense ? 17.0 : compact ? 20.0 : 24.0;
    final subtitleWidth = dense ? 220.0 : compact ? 260.0 : 320.0;
    final panelPadding = dense ? 10.0 : compact ? 13.0 : 18.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(panelPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dense ? 18 : compact ? 20 : 24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF171733).withValues(alpha: 0.82),
            const Color(0xFF101122).withValues(alpha: 0.78),
            const Color(0xFF0B0C18).withValues(alpha: 0.88),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.modeAcikAlan,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.modeAcikAlan.withValues(alpha: 0.34),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.t('login_signal_badge'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: dense ? 9.5 : 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_activeUsers.toString()}+',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.92),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 6 : 10),
          SizedBox(
            width: heroSize,
            height: heroSize,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _orbitController]),
              builder: (context, child) {
                final pulseT = Curves.easeInOut.transform(_pulseController.value);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(heroSize),
                      painter: _LobbyAuraPainter(pulse: pulseT),
                    ),
                    ..._buildOrbitWidgets(pulseT, compact: compact),
                    _buildPulseCore(pulseT, compact: compact),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: dense ? 6 : 10),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                letterSpacing: dense ? -0.4 : -0.7,
                height: 1.05,
              ),
              children: [
                TextSpan(
                  text: '${l10n.t('login_title_line1')}\n',
                  style: const TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: l10n.t('login_title_line2'),
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          SizedBox(height: dense ? 6 : 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: subtitleWidth),
            child: Text(
              l10n.t('login_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: dense ? 10.5 : compact ? 11.5 : 12.5,
                height: dense ? 1.3 : 1.45,
                color: Colors.white.withValues(alpha: dense ? 0.5 : 0.56),
              ),
            ),
          ),
          SizedBox(height: dense ? 6 : 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: dense ? 4 : 6,
            runSpacing: dense ? 4 : 6,
            children: [
              _LobbyMetricChip(
                icon: Icons.bolt_rounded,
                value: _activeUsers,
                label: l10n.t('login_active_users'),
                color: AppColors.primary,
                compact: compact || dense,
              ),
              _LobbyMetricChip(
                icon: Icons.place_rounded,
                value: _livePlaces,
                label: l10n.t('login_live_places'),
                color: AppColors.modeAcikAlan,
                compact: compact || dense,
              ),
              _LobbyMetricChip(
                icon: Icons.trending_up_rounded,
                value: _risingZones,
                label: l10n.t('login_rising_zones'),
                color: AppColors.modeSosyal,
                compact: compact || dense,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandMark({required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 12 : 14,
          height: compact ? 12 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.98),
                AppColors.primary.withValues(alpha: 0.52),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.38),
                blurRadius: 16,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: compact ? 20 : 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
            children: const [
              TextSpan(
                text: 'Pulse',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'City',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(
    AppLocalizations l10n, {
    required bool compact,
    required bool dense,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        dense ? 14 : compact ? 16 : 20,
        dense ? 14 : compact ? 16 : 20,
        dense ? 14 : compact ? 16 : 20,
        dense ? 12 : compact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgCard.withValues(alpha: 0.96),
            const Color(0xFF121325).withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(dense ? 22 : compact ? 26 : 30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('login_card_title'),
            style: TextStyle(
              color: Colors.white,
              fontSize: dense ? 16.5 : compact ? 18 : 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: dense ? 4 : 6),
          Text(
            l10n.t('login_card_subtitle'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: dense ? 10.5 : compact ? 11.5 : 12.5,
              height: dense ? 1.35 : 1.5,
            ),
          ),
          SizedBox(height: dense ? 10 : 12),
          SizedBox(
            width: double.infinity,
            height: dense ? 40 : compact ? 44 : 48,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _loginWithGoogle,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: dense ? 28 : 30,
                    height: dense ? 28 : 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: dense ? 16 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: dense ? 10 : 12),
                  Text(
                    l10n.t('continue_with_google'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: dense ? 12.5 : compact ? 13.5 : 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: dense ? 10 : 12),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l10n.t('or_email'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.36),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                  thickness: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 10 : 12),
          _buildTextField(
            controller: _emailController,
            hint: l10n.t('email'),
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            compact: compact,
          ),
          SizedBox(height: dense ? 6 : 8),
          _buildTextField(
            controller: _passwordController,
            hint: l10n.t('password'),
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            compact: compact,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.white.withValues(alpha: 0.38),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          SizedBox(height: dense ? 2 : 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: dense ? 2 : 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final email = _emailController.text.trim();
                if (email.isNotEmpty) {
                  try {
                    final navigator = Navigator.of(context);
                    await _authService.resetPassword(email);
                    if (!mounted) return;
                    _showError(l10n.t('reset_password_sent'));
                    await navigator.push(
                      PageRouteBuilder(
                        pageBuilder: (_, _, _) =>
                            ResetPasswordScreen(initialEmail: email),
                        transitionsBuilder: (_, anim, _, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 320),
                      ),
                    );
                  } catch (e) {
                    if (mounted) _showError(e.toString());
                  }
                } else {
                  _showError(l10n.t('reset_password_requires_email'));
                }
              },
              child: Text(
                l10n.t('forgot_password'),
                style: TextStyle(
                  fontSize: dense ? 10.5 : 12,
                  color: AppColors.primary.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: dense ? 6 : 10),
          SizedBox(
            width: double.infinity,
            height: dense ? 42 : compact ? 46 : 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.t('login'), style: AppTextStyles.button),
            ),
          ),
          SizedBox(height: dense ? 4 : 8),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: dense ? 2 : 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, _, _) => const RegisterFlowScreen(),
                    transitionsBuilder: (_, anim, _, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                );
              },
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: dense ? 11.5 : compact ? 12.5 : 14,
                    color: Colors.white.withValues(alpha: 0.44),
                  ),
                  children: [
                    TextSpan(text: '${l10n.t('register_cta_prefix')} '),
                    TextSpan(
                      text: l10n.t('register_cta'),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOrbitWidgets(
    double pulseT, {
    required bool compact,
  }) {
    final radiusFactor = compact ? 0.74 : 1.0;
    final dotPadding = compact ? 4.0 : 6.0;
    return List<Widget>.generate(_orbitDots.length, (index) {
      final dot = _orbitDots[index];
      final direction = index.isEven ? 1.0 : -1.0;
      final baseAngle = math.pi * 2 * _orbitController.value * dot.speed;
      final angle = dot.angleOffset + (baseAngle * direction);
      final radius =
          (dot.radius * radiusFactor) +
          math.sin((_orbitController.value * math.pi * 2) + index) * 3;
      final dx = math.cos(angle) * radius;
      final dy = math.sin(angle) * radius;
      final scale = 0.92 + (pulseT * 0.08) + ((index % 3) * 0.03);
      final outerSize = dot.size + dotPadding;
      final innerSize = compact ? (dot.size - 1).clamp(4.0, 9.0) : dot.size;

      return Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dot.color.withValues(alpha: 0.14),
              border: Border.all(
                color: dot.color.withValues(alpha: 0.32),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: dot.color.withValues(alpha: 0.16 + (pulseT * 0.1)),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dot.color.withValues(alpha: 0.82),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.34),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPulseCore(
    double pulseT, {
    required bool compact,
  }) {
    final coreSize = compact ? 68.0 : 84.0;
    final outerGlow = compact ? 86.0 : 106.0;
    final ringSize = compact ? 98.0 : 122.0;
    final innerDisc = compact ? 42.0 : 52.0;
    final iconSize = compact ? 28.0 : 34.0;
    final borderRadius = compact ? 24.0 : 28.0;
    final coreScale = 0.96 + (pulseT * 0.1);
    final ringScale = 1.0 + (pulseT * 0.36);
    final outerScale = 1.1 + (pulseT * 0.5);

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: outerScale,
          child: Container(
            width: outerGlow,
            height: outerGlow,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Transform.scale(
          scale: ringScale,
          child: Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1 + (pulseT * 0.08)),
                width: 1.2,
              ),
            ),
          ),
        ),
        Transform.scale(
          scale: coreScale,
          child: Container(
            width: coreSize,
            height: coreSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: AppColors.bgCard,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.34),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18 + (pulseT * 0.16)),
                  blurRadius: (compact ? 24 : 34) + (pulseT * 10),
                  spreadRadius: 2 + (pulseT * 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: innerDisc,
                  height: innerDisc,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                Icon(
                  Icons.favorite_rounded,
                  size: iconSize,
                  color: AppColors.primary.withValues(alpha: 0.96),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF090A16),
              Color(0xFF0B0C1B),
              Color(0xFF06070F),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 120,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 180,
              right: -100,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.modeSosyal.withValues(alpha: 0.06),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.modeSosyal.withValues(alpha: 0.12),
                      blurRadius: 120,
                      spreadRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.modeAcikAlan.withValues(alpha: 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.modeAcikAlan.withValues(alpha: 0.08),
                      blurRadius: 120,
                      spreadRadius: 16,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
                  final keyboardVisible = keyboardInset > 0;
                  final compact = constraints.maxHeight < 980 || keyboardVisible;
                  final dense = constraints.maxHeight < 920 || keyboardInset > 120;
                  final heroSize = keyboardVisible
                      ? 0
                      : dense
                      ? 82.0
                      : compact
                      ? 96.0
                      : 132.0;
                  final sidePadding = dense ? 16.0 : compact ? 20.0 : 28.0;
                  final maxContentWidth = compact ? 420.0 : 470.0;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      sidePadding,
                      keyboardVisible ? 6 : dense ? 4 : 8,
                      sidePadding,
                      keyboardVisible ? 10 : dense ? 8 : 14,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildBrandMark(compact: compact)),
                            const SizedBox(width: 12),
                            Tooltip(
                              message: l10n.t('select_language'),
                              child: PopupMenuButton<String>(
                                initialValue:
                                    AppLocaleService.instance.languageCode,
                                onSelected: _selectLanguage,
                                color: AppColors.bgCard,
                                offset: const Offset(0, 40),
                                itemBuilder: (_) {
                                  return AppLocalizations.supportedLocales.map((
                                    locale,
                                  ) {
                                    final code = locale.languageCode;
                                    final isSelected =
                                        code ==
                                        AppLocaleService.instance.languageCode;
                                    return PopupMenuItem<String>(
                                      value: code,
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? Icons.check_rounded
                                                : Icons.language_rounded,
                                            size: 18,
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.white.withValues(
                                                    alpha: 0.55,
                                                  ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            l10n.languageName(code),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList();
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        dense ? 10 : compact ? 11 : 12,
                                    vertical: dense ? 6 : compact ? 7 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgCard,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.language_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppLocaleService.instance.languageCode
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: dense ? 8 : 12),
                        Expanded(
                          child: keyboardVisible
                              ? ListView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: EdgeInsets.only(
                                    top: 4,
                                    bottom: keyboardInset + 12,
                                  ),
                                  children: [
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: maxContentWidth,
                                        ),
                                        child: _buildAuthCard(
                                          l10n,
                                          compact: true,
                                          dense: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Align(
                                  alignment: Alignment.center,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: maxContentWidth,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _buildAuthCard(
                                          l10n,
                                          compact: compact,
                                          dense: dense,
                                        ),
                                        SizedBox(height: dense ? 8 : 10),
                                        _buildLobbyHero(
                                          l10n,
                                          compact: compact,
                                          dense: dense,
                                          heroSize: heroSize.toDouble(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    bool compact = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(color: Colors.white, fontSize: compact ? 13.5 : 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.24),
            fontSize: compact ? 13 : 14.5,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.3),
            size: compact ? 18 : 20,
          ),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: compact ? 12 : 15,
          ),
        ),
      ),
    );
  }
}

class _LobbyOrbitDot {
  const _LobbyOrbitDot({
    required this.color,
    required this.radius,
    required this.size,
    required this.angleOffset,
    required this.speed,
  });

  final Color color;
  final double radius;
  final double size;
  final double angleOffset;
  final double speed;
}

class _LobbyMetricChip extends StatelessWidget {
  const _LobbyMetricChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 22 : 24,
            height: compact ? 22 : 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: color, size: compact ? 12 : 13),
          ),
          SizedBox(width: compact ? 7 : 8),
          Text(
            '$value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.46),
              fontSize: compact ? 10 : 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyAuraPainter extends CustomPainter {
  const _LobbyAuraPainter({required this.pulse});

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.08 + (pulse * 0.03)),
          AppColors.modeSosyal.withValues(alpha: 0.05 + (pulse * 0.02)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, auraPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final ring in [0.38, 0.58, 0.82]) {
      ringPaint.color = Colors.white.withValues(
        alpha: 0.035 + ((1 - ring) * 0.03) + (pulse * 0.01),
      );
      canvas.drawCircle(center, radius * ring, ringPaint);
    }

    final blobs = [
      (const Offset(-72, -54), 18.0, AppColors.modeSosyal),
      (const Offset(78, -30), 14.0, AppColors.modeAcikAlan),
      (const Offset(-26, 74), 16.0, AppColors.modeTopluluk),
      (const Offset(68, 64), 12.0, AppColors.modeKesif),
    ];

    for (final (offset, blobRadius, color) in blobs) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.06 + (pulse * 0.02));
      canvas.drawCircle(center + offset, blobRadius + (pulse * 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LobbyAuraPainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}
