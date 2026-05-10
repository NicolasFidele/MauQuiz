import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'create_class_screen.dart';
import 'manage_classes_screen.dart';
import 'view_classes_screen.dart';
import 'smart_quiz_screen.dart';
import 'manage_quizzes_screen.dart';
import 'teacher_results_screen.dart';
import 'manual_quiz_screen.dart';
import 'analytics_home_screen.dart';
import 'teacher_profile_screen.dart';
import 'send_announcement_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final supabase = Supabase.instance.client;

  bool _loadingAlerts = true;
  List<Map<String, dynamic>> _completionAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadCompletionAlerts();
  }

  Future<void> _loadCompletionAlerts() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('quiz_completion_alerts')
          .select('id, quiz_id, title, message, created_at')
          .eq('teacher_id', user.id)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _completionAlerts = List<Map<String, dynamic>>.from(data);
        _loadingAlerts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _completionAlerts = [];
        _loadingAlerts = false;
      });
    }
  }

  Future<void> _openResultsFromAlert() async {
    final alertIds = _completionAlerts.map((a) => a['id']).toList();

    if (alertIds.isNotEmpty) {
      await supabase
          .from('quiz_completion_alerts')
          .update({'is_read': true})
          .inFilter('id', alertIds);
    }

    if (!mounted) return;

    setState(() {
      _completionAlerts = [];
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeacherResultsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF142532),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF22425B),
                      Color(0xFF2E5B7A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      child: const Icon(
                        Icons.school_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Teacher Panel',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              _drawerItem(
                context,
                icon: Icons.person_outline,
                title: 'Profile',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeacherProfileScreen(),
                    ),
                  );
                },
              ),

              _drawerItem(
                context,
                icon: Icons.campaign_outlined,
                title: 'Send Announcement',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SendAnnouncementScreen(),
                    ),
                  );
                },
              ),

              _drawerItem(
                context,
                icon: Icons.help_outline,
                title: 'Help',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HelpScreen(),
                    ),
                  );
                },
              ),

              _drawerItem(
                context,
                icon: Icons.info_outline,
                title: 'About',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AboutScreen(),
                    ),
                  );
                },
              ),

              const Spacer(),
              const Divider(color: Colors.white24, height: 1),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: Text(
                  'Logout',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                onTap: _logout,
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),

      body: Stack(
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
            child: _buildCircle(170, Colors.cyanAccent.withOpacity(0.10)),
          ),

          Positioned(
            top: 110,
            right: -50,
            child: _buildCircle(150, Colors.purpleAccent.withOpacity(0.08)),
          ),

          Positioned(
            bottom: -70,
            left: 10,
            child: _buildCircle(210, Colors.blueAccent.withOpacity(0.08)),
          ),

          SafeArea(
            child: Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.menu,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),

                        const Spacer(),

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Teacher Dashboard',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Manage your classes, quizzes, and learner progress.',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),

                    if (!_loadingAlerts && _completionAlerts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _completionAlertCard(),
                    ],

                    const SizedBox(height: 22),

                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.22,
                        children: [
                          _dashboardCard(
                            context,
                            icon: Icons.add_box_outlined,
                            title: 'Create Class',
                            onTap: _openCreateClass,
                          ),

                          _dashboardCard(
                            context,
                            icon: Icons.groups_2_outlined,
                            title: 'Manage Classes',
                            onTap: _openManageClasses,
                          ),

                          _dashboardCard(
                            context,
                            icon: Icons.view_list_outlined,
                            title: 'View Classes',
                            onTap: _openViewClasses,
                          ),

                          _dashboardCard(
                            context,
                            icon: Icons.quiz_outlined,
                            title: 'Create Quiz',
                            onTap: _openCreateQuiz,
                          ),

                          _dashboardCard(
                            context,
                            icon: Icons.auto_awesome_outlined,
                            title: 'Create Smart Quiz',
                            onTap: _openCreateSmartQuiz,
                          ),

                          _dashboardCard(
                            context,
                            icon: Icons.edit_note_outlined,
                            title: 'Manage Quizzes',
                            onTap: _openManageQuizzes,
                          ),

                          _dashboardCard(
                            context,
                            icon: Icons.assignment_turned_in_outlined,
                            title: 'View Results',
                            onTap: _openViewResults,
                          ),

                          _dashboardCard(
                            context,
                            icon: Icons.bar_chart_outlined,
                            title: 'Analytics',
                            onTap: _openAnalytics,
                          ),
                        ],
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

  Widget _completionAlertCard() {
    final count = _completionAlerts.length;
    final firstAlert = _completionAlerts.first;

    final message = count == 1
        ? firstAlert['message'].toString()
        : '$count quizzes are fully completed by pupils.';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              TextButton(
                onPressed: _openResultsFromAlert,
                child: Text(
                  'View',
                  style: GoogleFonts.poppins(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreateClass() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateClassScreen(),
      ),
    );
  }

  void _openManageClasses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageClassesScreen(),
      ),
    );
  }

  void _openViewClasses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ViewClassesScreen(),
      ),
    );
  }

  void _openCreateQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManualQuizScreen(),
      ),
    );
  }

  void _openCreateSmartQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SmartQuizScreen(),
      ),
    );
  }

  void _openManageQuizzes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageQuizzesScreen(),
      ),
    );
  }

  void _openViewResults() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeacherResultsScreen(),
      ),
    );
  }

  void _openAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AnalyticsHomeScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title screen coming soon')),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: GoogleFonts.poppins(color: Colors.white),
      ),
      onTap: onTap,
    );
  }

  Widget _dashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
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