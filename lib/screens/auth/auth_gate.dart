//File unused -- Will keep for future development
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import '../teacher/teacher_dashboard.dart';
import '../pupil/pupil_dashboard.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();

    final teacherSession = supabase.auth.currentSession;
    if (teacherSession != null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TeacherDashboard(),
        ),
      );
      return;
    }

    final pupilLoggedIn = prefs.getBool('pupil_logged_in') ?? false;
    final pupilId = prefs.getString('pupil_id');
    final pupilFullName = prefs.getString('pupil_full_name');
    final pupilUsername = prefs.getString('pupil_username');

    if (pupilLoggedIn &&
        pupilId != null &&
        pupilFullName != null &&
        pupilUsername != null &&
        mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PupilDashboard(
            pupilId: pupilId,
            fullName: pupilFullName,
            username: pupilUsername,
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}