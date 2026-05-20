import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final supabase = Supabase.instance.client;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _codeSent = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _showMessage('Please enter a valid email.');
      return;
    }

    setState(() => _loading = true);

    try {
      await supabase.auth.resetPasswordForEmail(email);

      setState(() => _codeSent = true);

      _showMessage('Reset code sent. Please check your email.');
    } catch (e) {
      _showMessage('Error sending reset code: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateStrongPassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Use at least one capital letter.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Use at least one number.';
    }

    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=;/\\[\]~`]').hasMatch(password)) {
      return 'Use at least one symbol.';
    }

    return null;
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (code.isEmpty) {
      _showMessage('Please enter the reset code.');
      return;
    }

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please enter and confirm the new password.');
      return;
    }

    final passwordError = _validateStrongPassword(newPassword);

    if (passwordError != null) {
      _showMessage(passwordError);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);

    try {
      await supabase.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );

      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      await supabase.auth.signOut();

      if (!mounted) return;

      _showMessage('Password reset successfully. Please login again.');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      _showMessage('Invalid code or reset failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 14,
                      sigmaY: 14,
                    ),
                    child: Container(
                      width: 420,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_reset_outlined,
                            color: Colors.white,
                            size: 58,
                          ),

                          const SizedBox(height: 18),

                          Text(
                            'Reset Password',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            _codeSent
                                ? 'Enter the reset code sent to your email and choose a new password.'
                                : 'Enter your teacher email. A reset code will be sent to your inbox.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 24),

                          _inputField(
                            controller: _emailController,
                            hint: 'Teacher email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_codeSent,
                          ),

                          if (_codeSent) ...[
                            const SizedBox(height: 14),

                            _inputField(
                              controller: _codeController,
                              hint: 'Reset code',
                              icon: Icons.confirmation_number_outlined,
                              keyboardType: TextInputType.number,
                            ),

                            const SizedBox(height: 14),

                            _inputField(
                              controller: _newPasswordController,
                              hint: 'New password',
                              icon: Icons.lock_outline,
                              obscureText: _hidePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _hidePassword = !_hidePassword;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(height: 8),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Use at least 8 characters, 1 capital letter, 1 number and 1 symbol.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  height: 1.4,
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            _inputField(
                              controller: _confirmPasswordController,
                              hint: 'Confirm new password',
                              icon: Icons.lock_reset_outlined,
                              obscureText: _hideConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _hideConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _hideConfirmPassword =
                                        !_hideConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 22),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : _codeSent
                                      ? _resetPassword
                                      : _sendResetCode,
                              icon: Icon(
                                _codeSent
                                    ? Icons.save_outlined
                                    : Icons.email_outlined,
                              ),
                              label: Text(
                                _loading
                                    ? 'Please wait...'
                                    : _codeSent
                                        ? 'Update Password'
                                        : 'Send Reset Code',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E5B7A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          if (_codeSent) ...[
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _loading ? null : _sendResetCode,
                              child: Text(
                                'Resend code',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 8),

                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Back to Login',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: Colors.white54,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white70,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.white24,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.white24,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _background() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF11212D),
                Color(0xFF1D3A4A),
                Color(0xFF2C5364),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -60,
          left: -40,
          child: _circle(
            170,
            Colors.cyanAccent.withOpacity(0.10),
          ),
        ),
        Positioned(
          top: 120,
          right: -50,
          child: _circle(
            150,
            Colors.purpleAccent.withOpacity(0.08),
          ),
        ),
        Positioned(
          bottom: -70,
          left: 10,
          child: _circle(
            210,
            Colors.blueAccent.withOpacity(0.08),
          ),
        ),
      ],
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}