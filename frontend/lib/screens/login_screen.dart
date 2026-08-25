import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ← ADD THIS
import 'package:frontend/config/api_config.dart'; // ← Add at top

// ─── Slide data ───────────────────────────────────────────────────────────────
class _Slide {
  final String title;
  final String titleHighlight;
  final String body;
  const _Slide(this.title, this.titleHighlight, this.body);
}

const _slides = [
  _Slide(
    'Service',
    'with a smile.',
    'Manage tree trimming and vegetation removal near power lines to ensure uninterrupted, safe electricity delivery across Negros.',
  ),
  _Slide(
    'Every tree,',
    'tracked.',
    'Log inspection findings, schedule clearing work orders, and monitor crew progress from the field in real time.',
  ),
  _Slide(
    'Prevent outages',
    'before they happen.',
    'Proactive vegetation control reduces line faults, storm damage, and unplanned outages across the grid.',
  ),
];

// ─── Color tokens ─────────────────────────────────────────────────────────────
const _green700 = Color(0xFF1A7A3D);
const _green600 = Color(0xFF1E9147);
const _green500 = Color(0xFF22A84F);
const _green50 = Color(0xFFEDF9F1);
const _gray900 = Color(0xFF111827);
const _gray600 = Color(0xFF4A566A);
const _gray400 = Color(0xFF8E97A8);
const _gray300 = Color(0xFFC4CAD6);
const _gray200 = Color(0xFFDDE1EA);
const _gray100 = Color(0xFFEFF1F5);

// ─────────────────────────────────────────────────────────────────────────────
// LoginScreen — wraps itself in a local Theme so Sora + Plus Jakarta Sans
// only apply here, never leaking into the rest of the app (which uses Open Sans).
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Form
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Carousel
  int _slideIndex = 0;
  bool _transitioning = false;
  Timer? _carouselTimer;

  // ── Local text theme (Sora + Plus Jakarta Sans) ───────────────────────────
  late final TextTheme _loginTextTheme = GoogleFonts.plusJakartaSansTextTheme(
    const TextTheme(
      bodyLarge: TextStyle(fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
    ),
  );

  @override
  void initState() {
    super.initState();
    _startCarousel();

    // Check for Google OAuth redirect
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uri = Uri.base;
      final token = uri.queryParameters['token'];
      final isGoogleAuth = uri.queryParameters['google_auth'] == 'true';

      if (isGoogleAuth && token != null && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await ref.read(authProvider.notifier).loadUser();
        if (context.mounted) {
          html.window.history.replaceState(null, '', '/login');
        }
      }
    });
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _goSlide((_slideIndex + 1) % _slides.length);
    });
  }

  void _goSlide(int n) {
    if (_transitioning || !mounted) return;
    _transitioning = true;
    setState(() => _slideIndex = n);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _transitioning = false);
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    await ref.read(authProvider.notifier).login(email, password);
  }

  Future<void> _handleGoogleSignIn() async {
    final url = '${ApiConfig.baseUrl}/auth/google/login'; // ← Changed!

    if (kIsWeb) {
      html.window.location.href = url;
      return;
    }

    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google login. Please try again.'),
        ),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFBE123C),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 800;

    // Wrap the entire login page in its own Theme so Sora / Plus Jakarta Sans
    // are scoped here only — the rest of the app keeps Open Sans.
    return Theme(
      data: Theme.of(context).copyWith(textTheme: _loginTextTheme),
      child: Scaffold(
        backgroundColor: _gray100,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: isMobile
                ? _buildMobileLayout(authState)
                : _buildDesktopLayout(authState),
          ),
        ),
      ),
    );
  }

  // ── Desktop: side-by-side shell ────────────────────────────────────────────
  Widget _buildDesktopLayout(dynamic authState) {
    return Container(
      width: 960,
      constraints: const BoxConstraints(minHeight: 580),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 80,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildBrandPanel()),
              _buildFormPanel(authState, width: 420),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile: stacked ────────────────────────────────────────────────────────
  Widget _buildMobileLayout(dynamic authState) {
    return Container(
      width: 440,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _buildBrandPanelMobile(),
            _buildFormPanel(authState, width: double.infinity),
          ],
        ),
      ),
    );
  }

  // ── Brand panel (desktop) ──────────────────────────────────────────────────
  Widget _buildBrandPanel() {
    return Container(
      color: _green700,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Positioned(
              bottom: -80, right: -80, child: _Ring(size: 360, opacity: 0.10)),
          Positioned(
              bottom: -160,
              right: -160,
              child: _Ring(size: 520, opacity: 0.06)),
          Positioned(
              bottom: -240,
              right: -240,
              child: _Ring(size: 680, opacity: 0.04)),
          Positioned(
              top: -60, left: -60, child: _Ring(size: 260, opacity: 0.07)),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogo(),
                const SizedBox(height: 32),
                Expanded(child: _buildSlideArea()),
                const SizedBox(height: 24),
                _buildDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Brand panel (mobile — compact) ────────────────────────────────────────
  Widget _buildBrandPanelMobile() {
    return Container(
      color: _green700,
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogo(),
              const SizedBox(height: 20),
              SizedBox(height: 140, child: _buildSlideArea()),
              const SizedBox(height: 16),
              _buildDots(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration:
              const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: ClipOval(
            child: const Icon(Icons.bolt, color: _green600, size: 28),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Negros Power',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSlideArea() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: _buildSlideContent(_slideIndex),
    );
  }

  Widget _buildSlideContent(int index) {
    final slide = _slides[index];
    return Column(
      key: ValueKey(index),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${slide.title}\n',
                style: GoogleFonts.sora(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -0.8,
                ),
              ),
              TextSpan(
                text: slide.titleHighlight,
                style: GoogleFonts.sora(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8EE8AC),
                  height: 1.1,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          slide.body,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0x9EFFFFFF),
            height: 1.75,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDots() {
    return Row(
      children: List.generate(_slides.length, (i) {
        final active = i == _slideIndex;
        return GestureDetector(
          onTap: () {
            if (i == _slideIndex) return;
            _carouselTimer?.cancel();
            _goSlide(i);
            _startCarousel();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: active ? 36 : 24,
            height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: active ? Colors.white : Colors.white.withOpacity(0.28),
            ),
          ),
        );
      }),
    );
  }

  // ── Form panel ─────────────────────────────────────────────────────────────
  Widget _buildFormPanel(dynamic authState, {required double width}) {
    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 44),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFormHeader(),
              const SizedBox(height: 32),
              ..._buildSignInFields(authState),
            ],
          ),
        ),
      ),
    );
  }

  // ── Form header ────────────────────────────────────────────────────────────
  Widget _buildFormHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sign In',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _gray900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter your credentials to access the system.',
          style: TextStyle(fontSize: 13, color: _gray400),
        ),
      ],
    );
  }

  // ── Sign-in fields ─────────────────────────────────────────────────────────
  List<Widget> _buildSignInFields(dynamic authState) => [
        const _FieldLabel('Email address'),
        const SizedBox(height: 6),
        _VmsTextFormField(
          controller: _emailController,
          hint: 'e.g. you@example.com',
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please enter your email';
            if (!v.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Password'),
        const SizedBox(height: 6),
        _VmsTextFormField(
          controller: _passwordController,
          hint: 'Enter password',
          obscureText: _obscurePassword,
          onFieldSubmitted: (_) => _handleLogin(),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: _gray400,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please enter your password';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _SubmitButton(
          isLoading: authState.isLoading,
          label: 'Sign In',
          onPressed: _handleLogin,
        ),
        const SizedBox(height: 16),
        const _OrDivider(),
        const SizedBox(height: 14),
        _GoogleButton(
          label: 'Continue with Google',
          isLoading: false,
          onPressed: _handleGoogleSignIn,
        ),
        const SizedBox(height: 20),
        const _FormFooter(
          prefix: 'By signing in you accept our ',
          links: ['Terms of Use', 'Privacy Policy'],
        ),
        const SizedBox(height: 16),
        const Divider(color: _gray200, thickness: 1),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No account yet? ',
              style: TextStyle(fontSize: 13, color: _gray400),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/register'),
              child: const Text(
                'Register →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _green600,
                ),
              ),
            ),
          ],
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: _gray600,
        ),
      );
}

class _VmsTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  const _VmsTextFormField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: const TextStyle(fontSize: 13.5, color: _gray900),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _gray300, fontSize: 13.5),
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _gray200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _green500, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback onPressed;
  const _SubmitButton({
    required this.isLoading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _green600,
          disabledBackgroundColor: _green600.withOpacity(0.7),
          elevation: 2,
          shadowColor: _green500.withOpacity(0.30),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _gray200, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _gray300,
              letterSpacing: 0.06,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _gray200, thickness: 1)),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  const _GoogleButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 11),
        side: const BorderSide(color: _gray200, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.white,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _gray400),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CustomPaint(painter: _GoogleIconPainter()),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: _gray600,
                  ),
                ),
              ],
            ),
    );
  }
}

class _FormFooter extends StatelessWidget {
  final String prefix;
  final List<String> links;
  const _FormFooter({required this.prefix, required this.links});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text(prefix, style: const TextStyle(fontSize: 11.5, color: _gray400)),
        for (int i = 0; i < links.length; i++) ...[
          GestureDetector(
            onTap: () {},
            child: Text(
              links[i],
              style: const TextStyle(
                fontSize: 11.5,
                color: _green600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (i < links.length - 1)
            const Text(' & ',
                style: TextStyle(fontSize: 11.5, color: _gray400)),
        ],
        const Text('.', style: TextStyle(fontSize: 11.5, color: _gray400)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters
// ─────────────────────────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);
    const spacing = 28.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final x = c * spacing;
        final y = r * spacing;
        final dx = (x - size.width / 2).abs() / size.width;
        final dy = (y - size.height / 2).abs() / size.height;
        if ((dx * dx + dy * dy) < 0.3) {
          canvas.drawCircle(Offset(x, y), 1, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Ring extends StatelessWidget {
  final double size;
  final double opacity;
  const _Ring({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(opacity),
            width: 1,
          ),
        ),
      ),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final yell = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final grn = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
        Path()
          ..moveTo(w / 2, h / 2)
          ..arcTo(rect, -0.52, 1.10, false)
          ..close(),
        blue);
    canvas.drawPath(
        Path()
          ..moveTo(w / 2, h / 2)
          ..arcTo(rect, -2.70, 1.40, false)
          ..close(),
        red);
    canvas.drawPath(
        Path()
          ..moveTo(w / 2, h / 2)
          ..arcTo(rect, 2.20, 0.90, false)
          ..close(),
        yell);
    canvas.drawPath(
        Path()
          ..moveTo(w / 2, h / 2)
          ..arcTo(rect, 0.58, 1.60, false)
          ..close(),
        grn);

    canvas.drawCircle(
        Offset(w / 2, h / 2), w * 0.30, Paint()..color = Colors.white);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.50, h * 0.38, w * 0.50, h * 0.24), blue);
    canvas.drawCircle(
        Offset(w / 2, h / 2), w * 0.30, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
