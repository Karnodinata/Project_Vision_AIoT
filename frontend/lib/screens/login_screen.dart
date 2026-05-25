import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

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

  bool _isLoading = false;
  bool _isObscure = true;

  // Colors mapped to AppColors
  static const _bgPage      = AppColors.bgLogin;
  static const _bgCard      = AppColors.bgCard;
  static const _bgInput     = AppColors.bgInput;
  static const _accent      = AppColors.accent;
  static const _accentDark  = AppColors.accentDark;
  static const _accentLight = AppColors.accentLight;
  static const _borderColor = AppColors.accentBorder;
  static const _borderFocus = AppColors.accentFocus;
  static const _textPrimary = AppColors.textPrimary;
  static const _textSecondary = AppColors.textSecondaryLogin;
  static const _textMuted   = AppColors.textMuted;

  late AnimationController _fadeController;
  late AnimationController _scanController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _scanAnimation = CurvedAnimation(
      parent: _scanController,
      curve: Curves.linear,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    String rawEmail = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (rawEmail.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Username dan password tidak boleh kosong!',
                  style: TextStyle(color: Color(0xFF78350F), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFEF3C7),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
          elevation: 6,
        ),
      );
      return;
    }

    final String finalEmail = AuthService.formatEmail(rawEmail);

    setState(() => _isLoading = true);

    try {
      await _authService.login(finalEmail, password);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Color(0xFF065F46)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Otentikasi berhasil. Mengakses sistem...',
                  style: TextStyle(color: Color(0xFF064E3B), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD1FAE5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
          elevation: 6,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.replaceFirst('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
          elevation: 6,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: Stack(
        children: [
          // Grid background
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // Scan line (subtle, light-friendly)
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, _) {
              final screenHeight = MediaQuery.of(context).size.height;
              return Positioned(
                top: _scanAnimation.value * screenHeight,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x200891B2),
                        Color(0x500891B2),
                        Color(0x200891B2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Glow orbs — light version
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accent.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0077B6).withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 48),
                      _buildFormCard(),
                      const SizedBox(height: 16),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        // Icon badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            border: Border.all(color: _accent.withOpacity(0.35), width: 1.5),
            borderRadius: BorderRadius.circular(16),
            color: _accentLight,
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.water, color: _accent, size: 36),
        ),
        const SizedBox(height: 20),

        // Title
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF0E7490), Color(0xFF0891B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'V.I.S.I.O.N',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white, // dirender oleh ShaderMask
              letterSpacing: 10,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 1,
              color: _accent.withOpacity(0.35),
            ),
            const SizedBox(width: 10),
            const Text(
              'Visual Intellegence System IoT for Optimized Nutrition',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 1,
              color: _accent.withOpacity(0.35),
            ),
          ],
        ),
      ],
    );
  }

  // ── Form Card ──────────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        color: _bgCard,
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'OTORISASI AKSES',
                style: TextStyle(
                  fontSize: 11,
                  color: _accent,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Email/Username Field
          _buildTextField(
            controller: _emailController,
            label: 'Username atau Email',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // Password Field
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: _isObscure,
            suffixIcon: IconButton(
              icon: Icon(
                _isObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _isObscure = !_isObscure),
            ),
          ),
          const SizedBox(height: 28),

          // Submit Button
          _isLoading ? _buildLoadingButton() : _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 15,
        letterSpacing: 0.3,
      ),
      cursorColor: _accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: _textSecondary,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
        floatingLabelStyle: const TextStyle(
          color: _accent,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
        filled: true,
        fillColor: _bgInput,
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borderFocus, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildLoadingButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withOpacity(0.3)),
        color: _accentLight,
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_accent),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _handleLogin,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [_accentDark, _accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.28),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'OTORISASI AKSES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: _accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'SISTEM AKTIF  •  v1.0.0',
          style: TextStyle(
            fontSize: 10,
            color: _textSecondary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: _accent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

// Grid background painter — light theme version
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0891B2).withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}