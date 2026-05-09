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

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  static final supabase = Supabase.instance.client;

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
                icon: Icons.home_outlined,
                title: 'Home',
                onTap: () => _openHome(context),
              ),
              _drawerItem(
                context,
                icon: Icons.person_outline,
                title: 'Profile',
                onTap: () => _openProfile(context),
              ),
              _drawerItem(
                context,
                icon: Icons.campaign_outlined,
                title: 'Send Announcement',
                onTap: () => _openSendAnnouncement(context),
              ),
              _drawerItem(
                context,
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                onTap: () => _openNotifications(context),
              ),
              _drawerItem(
                context,
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () => _openSettings(context),
              ),
              _drawerItem(
                context,
                icon: Icons.help_outline,
                title: 'Help',
                onTap: () => _openHelp(context),
              ),
              _drawerItem(
                context,
                icon: Icons.info_outline,
                title: 'About',
                onTap: () => _openAbout(context),
              ),
              const Spacer(),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: Text(
                  'Logout',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                onTap: () => _logout(context),
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
                    const SizedBox(height: 26),
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
                            onTap: () => _openCreateClass(context),
                          ),
                          _dashboardCard(
                            context,
                            icon: Icons.groups_2_outlined,
                            title: 'Manage Classes',
                            onTap: () => _openManageClasses(context),
                          ),
                          _dashboardCard(
                            context,
                            icon: Icons.view_list_outlined,
                            title: 'View Classes',
                            onTap: () => _openViewClasses(context),
                          ),
                          _dashboardCard(
                            context,
                            icon: Icons.quiz_outlined,
                            title: 'Create Quiz',
                            onTap: () => _openCreateQuiz(context),
                          ),
                          _dashboardCard(
                            context,
                            icon: Icons.auto_awesome_outlined,
                            title: 'Create Smart Quiz',
                            onTap: () => _openCreateSmartQuiz(context),
                          ),
                          _dashboardCard(
                            context,
                            icon: Icons.edit_note_outlined,
                            title: 'Manage Quizzes',
                            onTap: () => _openManageQuizzes(context),
                          ),
                          _dashboardCard(
                            context,
                            icon: Icons.assignment_turned_in_outlined,
                            title: 'View Results',
                            onTap: () => _openViewResults(context),
                          ),
                          _dashboardCard(
                            context,
                            icon: Icons.bar_chart_outlined,
                            title: 'Analytics',
                            onTap: () => _openAnalytics(context),
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

  static void _openCreateClass(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateClassScreen(),
      ),
    );
  }

  static void _openManageClasses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageClassesScreen(),
      ),
    );
  }

  static void _openViewClasses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ViewClassesScreen(),
      ),
    );
  }

  static void _openCreateQuiz(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManualQuizScreen(),
      ),
    );
  }

  static void _openCreateSmartQuiz(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SmartQuizScreen(),
      ),
    );
  }

  static void _openManageQuizzes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageQuizzesScreen(),
      ),
    );
  }

  static void _openViewResults(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeacherResultsScreen(),
      ),
    );
  }

  static void _openAnalytics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AnalyticsHomeScreen(),
      ),
    );
  }

  static void _openHome(BuildContext context) {
    Navigator.pop(context);
  }

  static void _openProfile(BuildContext context) {
    Navigator.pop(context);
    _showComingSoon(context, 'Profile');
  }

  static void _openSendAnnouncement(BuildContext context) {
    Navigator.pop(context);
    _showComingSoon(context, 'Send Announcement');
  }

  static void _openNotifications(BuildContext context) {
    Navigator.pop(context);
    _showComingSoon(context, 'Notifications');
  }

  static void _openSettings(BuildContext context) {
    Navigator.pop(context);
    _showComingSoon(context, 'Settings');
  }

  static void _openHelp(BuildContext context) {
    Navigator.pop(context);
    _showComingSoon(context, 'Help');
  }

  static void _openAbout(BuildContext context) {
    Navigator.pop(context);
    _showComingSoon(context, 'About');
  }

  static Future<void> _logout(BuildContext context) async {
    await supabase.auth.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  static void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title screen coming soon')),
    );
  }

  static Widget _drawerItem(
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

  static Widget _dashboardCard(
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

  static Widget _buildCircle(double size, Color color) {
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