import 'dart:convert';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_screen.dart';
import '../teacher/teacher_dashboard.dart';
import '../pupil/pupil_dashboard.dart';
import 'create_new_pin_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // =========================
  // ANIMATION
  // =========================
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // =========================
  // FORM
  // =========================
  final _formKey = GlobalKey<FormState>();

  // Teacher login
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Pupil login
  final usernameController = TextEditingController();
  final pinController = TextEditingController();

  // Mode
  bool isTeacher = true;

  bool _isLoading = false;
  bool _isPasswordHidden = true;
  bool _isPinHidden = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    pinController.dispose();
    super.dispose();
  }

  // =========================
  // HASH PIN
  // =========================
  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  // =========================
  // LOGIN
  // =========================
  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (isTeacher) {
        final email = emailController.text.trim();
        final password = passwordController.text.trim();

        final response = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;

        if (response.user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teacher login successful')),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const TeacherDashboard(),
            ),
          );
        }
      } else {
        final username = usernameController.text.trim();
        final pin = pinController.text.trim();

        final pupil = await supabase
            .from('pupils')
            .select()
            .eq('username', username)
            .maybeSingle();

        if (!mounted) return;

        if (pupil == null) {
          _showError('Invalid username or PIN');
          return;
        }

        final enteredPinHash = _hashPin(pin);
        final savedPinHash = pupil['pin_hash'];

        if (enteredPinHash != savedPinHash) {
          _showError('Invalid username or PIN');
          return;
        }

        final mustChangePin = pupil['must_change_pin'] == true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pupil_logged_in', true);
        await prefs.setString('pupil_id', pupil['id']);
        await prefs.setString('pupil_full_name', pupil['full_name']);
        await prefs.setString('pupil_username', pupil['username']);
        if (mustChangePin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CreateNewPinScreen(
                pupilId: pupil['id'],
                fullName: pupil['full_name'],
                username: pupil['username'],
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PupilDashboard(
                pupilId: pupil['id'],
                fullName: pupil['full_name'],
                username: pupil['username'],
              ),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Something went wrong: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1CB5E0),
                  Color(0xFF000851),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -60,
            left: -40,
            child: _buildCircle(180, Colors.white.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -80,
            right: -50,
            child: _buildCircle(200, Colors.cyanAccent.withOpacity(0.15)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        Text(
                          'MauQuiz',
                          style: GoogleFonts.poppins(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'Welcome Back',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'Sign in to continue',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Toggle
                        Container(
                          width: 320,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      isTeacher = true;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isTeacher
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Teacher',
                                        style: GoogleFonts.poppins(
                                          color: isTeacher
                                              ? Colors.black87
                                              : Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      isTeacher = false;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !isTeacher
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Pupil',
                                        style: GoogleFonts.poppins(
                                          color: !isTeacher
                                              ? Colors.black87
                                              : Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Glass card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 15,
                              sigmaY: 15,
                            ),
                            child: Container(
                              width: 400,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    if (isTeacher) ...[
                                      _buildGlassField(
                                        controller: emailController,
                                        hint: 'Email',
                                        icon: Icons.email_outlined,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Enter email';
                                          }
                                          if (!value.contains('@') ||
                                              !value.contains('.')) {
                                            return 'Invalid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 15),
                                      _buildGlassField(
                                        controller: passwordController,
                                        hint: 'Password',
                                        icon: Icons.lock_outline,
                                        isPassword: true,
                                        hideValue: _isPasswordHidden,
                                        onToggleVisibility: () {
                                          setState(() {
                                            _isPasswordHidden =
                                                !_isPasswordHidden;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Enter password';
                                          }
                                          return null;
                                        },
                                      ),
                                    ] else ...[
                                      _buildGlassField(
                                        controller: usernameController,
                                        hint: 'Username',
                                        icon: Icons.person_outline,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Enter username';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 15),
                                      _buildGlassField(
                                        controller: pinController,
                                        hint: '4-digit PIN',
                                        icon: Icons.pin_outlined,
                                        isPassword: true,
                                        hideValue: _isPinHidden,
                                        keyboardType: TextInputType.number,
                                        onToggleVisibility: () {
                                          setState(() {
                                            _isPinHidden = !_isPinHidden;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Enter PIN';
                                          }
                                          if (value.length != 4 ||
                                              int.tryParse(value) == null) {
                                            return 'PIN must be 4 digits';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const ForgotPasswordScreen(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            'Forgot Password?',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 20),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                        ),
                                        onPressed:
                                            _isLoading ? null : _loginUser,
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : Text(
                                                'Login',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 12),

                                    if (isTeacher)
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const RegisterScreen(),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          "Don't have an account? Register",
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        'Ask your teacher for login details',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
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
        ],
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool hideValue = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? hideValue : false,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  hideValue ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.20),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.20),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Colors.white70,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Colors.amberAccent,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Colors.amberAccent,
            width: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildCircle(double size, Color color) {
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