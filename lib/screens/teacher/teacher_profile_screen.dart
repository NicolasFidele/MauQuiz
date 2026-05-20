import 'dart:io';
import 'dart:ui';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final supabase = Supabase.instance.client;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _pupilUsernameController = TextEditingController();

  String? _teacherName;
  String? _teacherEmail;
  String? _profileImagePath;

  int _totalQuizzes = 0;
  int _totalClasses = 0;
  int _totalPupils = 0;
  int _totalAttempts = 0;

  bool _loading = true;
  bool _savingPassword = false;
  bool _resettingPin = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _pupilUsernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      _profileImagePath = prefs.getString('teacher_profile_image_${user.id}');

      _teacherEmail = user.email;
      _teacherName =
          user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          user.email?.split('@').first ??
          'Teacher';

      final quizzes = await supabase
          .from('smart_quizzes')
          .select('id')
          .eq('teacher_id', user.id);

      final classes = await supabase
          .from('classes')
          .select('id')
          .eq('teacher_id', user.id);

      final pupils = await supabase
          .from('pupils')
          .select('id')
          .eq('teacher_id', user.id);

      final attempts = await supabase
          .from('smart_quiz_attempts')
          .select('id, smart_quizzes!inner(teacher_id)')
          .eq('smart_quizzes.teacher_id', user.id);

      setState(() {
        _totalQuizzes = quizzes.length;
        _totalClasses = classes.length;
        _totalPupils = pupils.length;
        _totalAttempts = attempts.length;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showMessage('Error loading profile: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (image == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_profile_image_${user.id}', image.path);

    setState(() {
      _profileImagePath = image.path;
    });
  }

  String? _validateStrongPassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one capital letter.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number.';
    }

    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=;/\\[\]~`]').hasMatch(password)) {
      return 'Password must contain at least one symbol.';
    }

    return null;
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final user = supabase.auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      _showMessage('No logged-in teacher found.');
      return;
    }

    if (currentPassword.isEmpty) {
      _showMessage('Please enter your current password.');
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

    if (currentPassword == newPassword) {
      _showMessage('New password must be different from current password.');
      return;
    }

    setState(() => _savingPassword = true);

    try {
      // Verify current password first.
      await supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      // Then update to new strong password.
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showMessage('Password changed successfully.');
    } catch (e) {
      _showMessage('Current password is incorrect or password update failed.');
    } finally {
      if (mounted) {
        setState(() => _savingPassword = false);
      }
    }
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<void> _resetPupilPin() async {
    final username = _pupilUsernameController.text.trim();
    final user = supabase.auth.currentUser;

    if (user == null) return;

    if (username.isEmpty) {
      _showMessage('Please enter the pupil username.');
      return;
    }

    setState(() => _resettingPin = true);

    try {
      final defaultPinHash = _hashPin('1234');

      final result = await supabase
          .from('pupils')
          .update({
            'pin_hash': defaultPinHash,
            'must_change_pin': true,
          })
          .eq('username', username)
          .eq('teacher_id', user.id)
          .select();

      if (result.isEmpty) {
        _showMessage('No pupil found with this username.');
      } else {
        _pupilUsernameController.clear();
        _showMessage('Pupil PIN reset to 1234 successfully.');
      }
    } catch (e) {
      _showMessage('Error resetting pupil PIN: $e');
    } finally {
      setState(() => _resettingPin = false);
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
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _topBar(),
                        const SizedBox(height: 24),
                        _profileHeader(),
                        const SizedBox(height: 22),
                        _statisticsSection(),
                        const SizedBox(height: 22),
                        _changePasswordSection(),
                        const SizedBox(height: 22),
                        _resetPupilPasswordSection(),
                      ],
                    ),
                  ),
          ),
        ],
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
          child: _circle(170, Colors.cyanAccent.withOpacity(0.10)),
        ),
        Positioned(
          top: 120,
          right: -50,
          child: _circle(150, Colors.purpleAccent.withOpacity(0.08)),
        ),
        Positioned(
          bottom: -70,
          left: 10,
          child: _circle(210, Colors.blueAccent.withOpacity(0.08)),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Teacher Profile',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _profileHeader() {
    return _glassCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  backgroundImage: _profileImagePath != null
                      ? FileImage(File(_profileImagePath!))
                      : null,
                  child: _profileImagePath == null
                      ? const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 52,
                        )
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E5B7A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _teacherName ?? 'Teacher',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _teacherEmail ?? '',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap photo to change profile picture',
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Basic Statistics'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.35,
          children: [
            _statCard(Icons.quiz_outlined, 'Quizzes Created', _totalQuizzes),
            _statCard(Icons.class_outlined, 'Classes Created', _totalClasses),
            _statCard(Icons.groups_outlined, 'Pupils Managed', _totalPupils),
            _statCard(
              Icons.assignment_turned_in_outlined,
              'Quiz Attempts',
              _totalAttempts,
            ),
          ],
        ),
      ],
    );
  }

  Widget _changePasswordSection() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Change Password'),
          const SizedBox(height: 8),
          Text(
            'Use at least 8 characters, including 1 capital letter, 1 number and 1 symbol.',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: _currentPasswordController,
            hint: 'Current password',
            icon: Icons.lock_person_outlined,
            obscureText: true,
          ),
          const SizedBox(height: 12),
          _inputField(
            controller: _newPasswordController,
            hint: 'New password',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 12),
          _inputField(
            controller: _confirmPasswordController,
            hint: 'Confirm new password',
            icon: Icons.lock_reset_outlined,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          _button(
            text: _savingPassword ? 'Changing...' : 'Change Password',
            icon: Icons.save_outlined,
            onTap: _savingPassword ? null : _changePassword,
          ),
        ],
      ),
    );
  }

  Widget _resetPupilPasswordSection() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Reset Pupil PIN'),
          const SizedBox(height: 8),
          Text(
            'Enter the pupil username. The PIN will be reset to 1234 and the pupil will be asked to create a new PIN at next login.',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: _pupilUsernameController,
            hint: 'Pupil username',
            icon: Icons.person_search_outlined,
          ),
          const SizedBox(height: 16),
          _button(
            text: _resettingPin ? 'Resetting...' : 'Reset PIN to 1234',
            icon: Icons.restart_alt_outlined,
            onTap: _resettingPin ? null : _resetPupilPin,
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String title, int value) {
    return _glassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _button({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E5B7A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
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