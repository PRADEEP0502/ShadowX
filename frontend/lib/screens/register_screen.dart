import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../screens/premium_input_card.dart';
import '../widgets/premium_gradient_button.dart';
import '../widgets/premium_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _otpHint; // shown when email delivery fails (dev mode)
  bool _emailSent = true;

  // Countdown for OTP expiry (5 min = 300s)
  int _secondsLeft = 300;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsLeft = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _countdownTimer?.cancel();
        }
      });
    });
  }

  String get _countdownText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _sendOtp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.sendRegisterOtp(
        username: name,
        email: email,
        password: password,
      );
      if (!mounted) return;
      final hint = result['otp_hint']?.toString();
      final emailSent = result['email_sent'] as bool? ?? true;
      setState(() {
        _isLoading = false;
        _otpSent = true;
        _otpHint = hint;
        _emailSent = emailSent;
        // Auto-fill OTP if email failed (dev convenience)
        if (hint != null && !emailSent) {
          _otpController.text = hint;
        }
      });
      _startCountdown();
      _showSnack(
        emailSent
            ? 'OTP sent to $email ✅'
            : '📋 Email failed — OTP shown below for testing',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showSnack('Enter the 6-digit OTP');
      return;
    }
    if (_secondsLeft <= 0) {
      _showSnack('OTP expired. Tap Resend OTP.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.verifyRegisterOtp(
        email: _emailController.text.trim(),
        otp: otp,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Account created! Please login 🎉');
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardDark,
        margin: const EdgeInsets.all(12),
        content: Text(msg, style: const TextStyle(color: AppColors.textPrimary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.amoledBlack,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Register',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GlowPainter(),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumInputCard(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _otpSent ? _buildOtpStep() : _buildDetailsStep(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      key: const ValueKey('details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _gradientTitle('Create Account'),
        const SizedBox(height: 8),
        _subtitle('Join the premium messaging experience'),
        const SizedBox(height: 32),
        PremiumTextField(
          controller: _nameController,
          label: 'Username',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        PremiumTextField(
          controller: _emailController,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        PremiumTextField(
          controller: _passwordController,
          label: 'Password',
          obscureText: true,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 28),
        PremiumGradientButton(
          text: 'Send OTP',
          isLoading: _isLoading,
          onPressed: _sendOtp,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed('/login'),
          child: Text(
            'Already have an account? Login',
            style: TextStyle(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _gradientTitle('Verify Email'),
        const SizedBox(height: 8),
        _subtitle('Enter the 6-digit OTP sent to\n${_emailController.text.trim()}'),
        const SizedBox(height: 32),
        PremiumTextField(
          controller: _otpController,
          label: 'Enter OTP',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
        ),
        if (_otpHint != null && !_emailSent) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF7B2FF7).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF7B2FF7).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF8B5CF6), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dev OTP: $_otpHint  (email delivery failed)',
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _secondsLeft > 0
                ? Text(
                    'OTP expires in $_countdownText',
                    key: ValueKey(_secondsLeft),
                    style: TextStyle(
                      color: _secondsLeft < 60
                          ? AppColors.errorRed
                          : AppColors.primaryPurple,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  )
                : Text(
                    'OTP expired',
                    style: TextStyle(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        PremiumGradientButton(
          text: 'Verify & Create Account',
          isLoading: _isLoading,
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : () {
            setState(() {
              _otpSent = false;
              _otpController.clear();
              _countdownTimer?.cancel();
            });
          },
          child: Text(
            'Resend OTP / Change details',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _gradientTitle(String text) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _subtitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = const Color(0xFF7B2FF7).withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    final p2 = Paint()
      ..color = const Color(0xFF3A8DFF).withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.2), 160, p1);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.75), 180, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
