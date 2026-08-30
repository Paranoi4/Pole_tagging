import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:google_fonts/google_fonts.dart';

const _green700 = Color(0xFF1A7A3D);
const _green600 = Color(0xFF1E9147);
const _green500 = Color(0xFF22A84F);
const _gray900 = Color(0xFF111827);
const _gray600 = Color(0xFF4A566A);
const _gray400 = Color(0xFF8E97A8);
const _gray300 = Color(0xFFC4CAD6);
const _gray200 = Color(0xFFDDE1EA);
const _gray100 = Color(0xFFEFF1F5);

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedOrgCode; // ✅ ADD THIS
  bool _obscurePassword = true;

  late final TextTheme _registerTextTheme =
      GoogleFonts.plusJakartaSansTextTheme(
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
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOrgCode == null)
      return; // dropdown has its own validator below, this is a safety net

    final user = User(
      userId: 0,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      username: _usernameController.text.trim(),
      orgCode: _selectedOrgCode, // ✅ ADD THIS
    );

    await ref.read(authProvider.notifier).register(
          user,
          _passwordController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Theme(
      data: Theme.of(context).copyWith(textTheme: _registerTextTheme),
      child: Scaffold(
        backgroundColor: _gray100,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: isMobile
                ? _buildLayout(authState, true)
                : _buildLayout(authState, false),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(AuthState authState, bool mobile) {
    final brand = _buildBrandPanel(mobile);
    final form = _buildFormPanel(authState);
    final content = mobile
        ? Column(children: [brand, form])
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: brand),
                SizedBox(width: 420, child: form),
              ],
            ),
          );

    return Container(
      width: mobile ? 440 : 960,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(mobile ? 20 : 24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 60,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(mobile ? 20 : 24),
        child: content,
      ),
    );
  }

  Widget _buildBrandPanel(bool mobile) {
    return Container(
      color: _green700,
      padding: EdgeInsets.fromLTRB(40, mobile ? 32 : 40, 40, mobile ? 28 : 40),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Positioned(
            bottom: -170,
            right: -160,
            child: _Ring(size: mobile ? 420 : 560, opacity: 0.07),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
            children: [
              _buildLogo(),
              SizedBox(height: mobile ? 28 : 100),
              Text(
                'Join the team,',
                style: GoogleFonts.sora(
                  fontSize: mobile ? 28 : 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              Text(
                'make a difference.',
                style: GoogleFonts.sora(
                  fontSize: mobile ? 28 : 36,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8EE8AC),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Create your account to help keep vegetation management organized, visible, and safe across the grid.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0x9EFFFFFF),
                  height: 1.75,
                ),
              ),
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
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: const Icon(Icons.bolt, color: _green600, size: 28),
        ),
        const SizedBox(width: 12),
        const Text(
          'Negros Power',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFormPanel(AuthState authState) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 44),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create Account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _gray900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Request access to the Poletagging system.',
              style: TextStyle(fontSize: 13, color: _gray400),
            ),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                  child:
                      _field('First name', 'First name', _firstNameController)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field('Last name', 'Last name', _lastNameController)),
            ]),
            const SizedBox(height: 15),
            _field('Email address', 'e.g. you@example.com', _emailController,
                keyboardType: TextInputType.emailAddress, validator: (value) {
              if (value == null || value.isEmpty) return 'Enter your email';
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            }),
            const SizedBox(height: 15),
            _field('Username', 'Choose a username', _usernameController),
            const SizedBox(height: 15),
            _orgCodeField(), // ✅ ADD THIS
            const SizedBox(height: 15),
            _field('Password', 'At least 6 characters', _passwordController,
                obscureText: _obscurePassword,
                suffixIcon: _passwordToggle(), validator: (value) {
              if (value == null || value.isEmpty) return 'Enter a password';
              if (value.length < 6) return 'Use at least 6 characters';
              return null;
            }),
            const SizedBox(height: 15),
            _field('Confirm password', 'Repeat your password',
                _confirmPasswordController, obscureText: _obscurePassword,
                validator: (value) {
              if (value != _passwordController.text)
                return 'Passwords do not match';
              return null;
            }),
            const SizedBox(height: 18),
            if (authState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(authState.errorMessage!,
                    style: const TextStyle(color: Color(0xFFBE123C)),
                    textAlign: TextAlign.center),
              ),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green600,
                  disabledBackgroundColor: _green600.withOpacity(0.7),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create account',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
            ),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Already have an account? ',
                  style: TextStyle(fontSize: 13, color: _gray400)),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: const Text('Sign in',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _green600)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _orgCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Organization',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: _gray600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedOrgCode,
          items: const [
            DropdownMenuItem(value: 'NP', child: Text('Negros Power (NP)')),
            DropdownMenuItem(value: 'BP', child: Text('BP')),
            DropdownMenuItem(value: 'MP', child: Text('MP')),
          ],
          onChanged: (value) => setState(() => _selectedOrgCode = value),
          validator: (value) =>
              value == null ? 'Select your organization' : null,
          style: const TextStyle(fontSize: 13.5, color: _gray900),
          decoration: InputDecoration(
            hintText: 'Select organization',
            hintStyle: const TextStyle(color: _gray300, fontSize: 13.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _gray200, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green500, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _passwordToggle() => IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 18,
          color: _gray400,
        ),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      );

  Widget _field(
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: _gray600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator ??
              (value) => value == null || value.isEmpty
                  ? 'This field is required'
                  : null,
          style: const TextStyle(fontSize: 13.5, color: _gray900),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _gray300, fontSize: 13.5),
            suffixIcon: suffixIcon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _gray200, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green500, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);
    const spacing = 28.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < cols; column++) {
        final x = column * spacing;
        final y = row * spacing;
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
