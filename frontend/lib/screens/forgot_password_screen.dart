import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../screens/premium_input_card.dart';
import '../widgets/premium_gradient_button.dart';
import '../widgets/premium_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _otpHint;
  bool _emailSent = true;

  int _secondsLeft = 300;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsLeft = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  String get _countdownText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Please enter your email');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.sendForgotOtp(email: email);
      if (!mounted) return;
      final hint = result['otp_hint']?.toString();
      final emailSent = result['email_sent'] as bool? ?? true;
      setState(() {
        _isLoading = false;
        _otpSent = true;
        _otpHint = hint;
        _emailSent = emailSent;
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

  Future<void> _resetPassword() async {
    final otp = _otpController.text.trim();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (otp.length != 6) {
      _showSnack('Enter the 6-digit OTP');
      return;
    }
    if (newPass.isEmpty || confirmPass.isEmpty) {
      _showSnack('Please fill in both password fields');
      return;
    }
    if (newPass != confirmPass) {
      _showSnack('Passwords do not match');
      return;
    }
    if (newPass.length < 6) {
      _showSnack('Password must be at least 6 characters');
      return;
    }
    if (_secondsLeft <= 0) {
      _showSnack('OTP expired. Tap Resend OTP.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService.verifyForgotOtp(
        email: _emailController.text.trim(),
        otp: otp,
        newPassword: newPass,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Password reset successfully! Please login 🎉');
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
        title: const Text('Forgot Password'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _StarfieldPainter())),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumInputCard(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _otpSent ? _buildResetStep() : _buildEmailStep(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _gradientTitle('Forgot Password?'),
        const SizedBox(height: 8),
        _subtitle('Enter your registered email to receive a reset OTP'),
        const SizedBox(height: 32),
        PremiumTextField(
          controller: _emailController,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
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
            'Back to Login',
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

  Widget _buildResetStep() {
    return Column(
      key: const ValueKey('reset'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _gradientTitle('Reset Password'),
        const SizedBox(height: 8),
        _subtitle('Enter the OTP sent to\n${_emailController.text.trim()}'),
        const SizedBox(height: 32),
        PremiumTextField(
          controller: _otpController,
          label: 'Enter OTP',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
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
        const SizedBox(height: 16),
        PremiumTextField(
          controller: _newPasswordController,
          label: 'New Password',
          obscureText: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        PremiumTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          obscureText: true,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _secondsLeft > 0
                ? 'OTP expires in $_countdownText'
                : 'OTP expired',
            style: TextStyle(
              color: _secondsLeft > 0 && _secondsLeft >= 60
                  ? AppColors.primaryPurple
                  : AppColors.errorRed,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 24),
        PremiumGradientButton(
          text: 'Reset Password',
          isLoading: _isLoading,
          onPressed: _resetPassword,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _otpSent = false;
                    _otpController.clear();
                    _countdownTimer?.cancel();
                  });
                },
          child: Text(
            'Resend OTP',
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
        style: AppTextStyles.displayMedium,
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

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 50; i++) {
      final x = (random * i * 0.12).remainder(size.width);
      final y = (random * i * 0.17).remainder(size.height);
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);
      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
