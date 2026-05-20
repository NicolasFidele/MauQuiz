import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_screen.dart';
import '../classes/create_class_screen.dart';
import '../classes/manage_classes_screen.dart';
import '../classes/view_classes_screen.dart';
import '../quizzes/smart_quiz_screen.dart';
import '../quizzes/manage_quizzes_screen.dart';
import '../results/teacher_results_screen.dart';
import '../quizzes/manual_quiz_screen.dart';
import '../analytics/analytics_home_screen.dart';
import 'teacher_profile_screen.dart';
import '../communication/send_announcement_screen.dart';
import '../support/help_screen.dart';
import '../support/about_screen.dart';

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
    _loadDashboardData();
  }
  Future<void> _loadDashboardData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final quizzes = await supabase
          .from('smart_quizzes')
          .select('id, title, subject, topic, status, created_at, class_id')
          .eq('teacher_id', user.id)
          .order('created_at', ascending: false);

      final classes = await supabase
          .from('classes')
          .select('id, class_name')
          .eq('teacher_id', user.id);

      final pupils = await supabase
          .from('pupils')
          .select('id')
          .eq('teacher_id', user.id);

      final classMap = {
        for (final c in classes) c['id'].toString(): c['class_name'].toString()
      };

      final quizIds = List<Map<String, dynamic>>.from(quizzes)
          .map((q) => q['id'])
          .toList();

      List<Map<String, dynamic>> attempts = [];

      if (quizIds.isNotEmpty) {
        final attemptsData = await supabase
            .from('smart_quiz_attempts')
            .select('id, score_percent')
            .inFilter('quiz_id', quizIds)
            .eq('status', 'submitted');

        attempts = List<Map<String, dynamic>>.from(attemptsData);
      }

      double avg = 0;

      if (attempts.isNotEmpty) {
        final total = attempts.fold<double>(0, (sum, item) {
          final value = item['score_percent'];
          if (value is int) return sum + value.toDouble();
          if (value is double) return sum + value;
          return sum + (double.tryParse(value.toString()) ?? 0);
        });

        avg = total / attempts.length;
      }

      final recent = List<Map<String, dynamic>>.from(quizzes.take(3)).map((quiz) {
        final classId = quiz['class_id']?.toString();

        return {
          'title': quiz['title'] ?? 'Untitled Quiz',
          'subject': quiz['subject'] ?? '',
          'topic': quiz['topic'] ?? '',
          'class': classMap[classId] ?? 'Class',
          'date': _formatDate(quiz['created_at']?.toString()),
          'status': quiz['status'] ?? 'draft',
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _totalQuizzes = quizzes.length;
        _totalPupils = pupils.length;
        _completedAttempts = attempts.length;
        _averageScore = avg;
        _recentQuizzes = recent;
        _loadingDashboard = false;
      });
    } catch (e) {
      debugPrint('Dashboard data error: $e');

      if (!mounted) return;

      setState(() {
        _loadingDashboard = false;
      });
    }
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
    final user = supabase.auth.currentUser;

    if (user != null) {
      try {
        await supabase
            .from('quiz_completion_alerts')
            .update({'is_read': true})
            .eq('teacher_id', user.id)
            .eq('is_read', false);
      } catch (e) {
        debugPrint('Failed to mark alerts as read: $e');
      }
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
  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';

    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;

    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }
  bool _loadingDashboard = true;
  int _totalQuizzes = 0;
  int _totalPupils = 0;
  int _completedAttempts = 0;
  double _averageScore = 0;
  List<Map<String, dynamic>> _recentQuizzes = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF061A30),
                  Color(0xFF062B4A),
                  Color(0xFF08365C),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Positioned(
            top: -80,
            right: -70,
            child: _buildCircle(220, Colors.blueAccent.withOpacity(0.12)),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: _buildCircle(230, Colors.cyanAccent.withOpacity(0.08)),
          ),

          SafeArea(
            child: Builder(
              builder: (context) {
                return RefreshIndicator(
                  onRefresh: () async {
                    await _loadCompletionAlerts();
                    await _loadDashboardData();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.menu,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: () {
                                Scaffold.of(context).openDrawer();
                              },
                            ),
                            const Spacer(),
                            Text(
                              'Dashboard',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),

                        const SizedBox(height: 28),

                        Text(
                          'Welcome back, Teacher!',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Here’s what’s happening with your quizzes.',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),

                        if (!_loadingAlerts && _completionAlerts.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _completionAlertCard(),
                        ],

                        const SizedBox(height: 26),

                        // Statistics cards - sample data for now
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.55,
                          children: [
                            _statCard(
                              icon: Icons.post_add_outlined,
                              iconColor: const Color(0xFF1E90FF),
                              value: _loadingDashboard ? '...' : _totalQuizzes.toString(),
                              label: 'Quizzes Created',
                            ),
                            _statCard(
                              icon: Icons.groups_2_outlined,
                              iconColor: const Color(0xFF00D1C1),
                              value: _loadingDashboard ? '...' : _totalPupils.toString(),
                              label: 'Pupils',
                            ),
                            _statCard(
                              icon: Icons.check_circle_outline,
                              iconColor: const Color(0xFF8E5CF7),
                              value: _loadingDashboard ? '...' : _completedAttempts.toString(),
                              label: 'Completed Attempts',
                            ),
                            _statCard(
                              icon: Icons.bar_chart_outlined,
                              iconColor: const Color(0xFFFFC107),
                              value: _loadingDashboard ? '...' : '${_averageScore.toStringAsFixed(0)}%',
                              label: 'Average Score',
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        Text(
                          'Quick Actions',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 16),

                        _quickActionCard(
                          icon: Icons.auto_awesome_outlined,
                          iconBackground: const Color(0xFF168BFF),
                          title: 'Create Smart Quiz',
                          subtitle: 'Generate quiz questions using AI',
                          onTap: _openCreateSmartQuiz,
                        ),

                        const SizedBox(height: 14),

                        _quickActionCard(
                          icon: Icons.quiz_outlined,
                          iconBackground: const Color(0xFF8E5CF7),
                          title: 'Create Manual Quiz',
                          subtitle: 'Type your own questions and options',
                          onTap: _openCreateQuiz,
                        ),

                        const SizedBox(height: 14),

                        _quickActionCard(
                          icon: Icons.groups_2_outlined,
                          iconBackground: const Color(0xFF12C7C0),
                          title: 'Manage Classes',
                          subtitle: 'Add, view, or remove pupils',
                          onTap: _openManageClasses,
                        ),

                        const SizedBox(height: 14),

                        _quickActionCard(
                          icon: Icons.article_outlined,
                          iconBackground: const Color(0xFFFFB020),
                          title: 'View Results',
                          subtitle: 'See pupils’ scores and quiz outcomes',
                          onTap: _openViewResults,
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Manage',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 16),

                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.35,
                          children: [
                            _smallActionCard(
                              icon: Icons.add_box_outlined,
                              title: 'Create Class',
                              onTap: _openCreateClass,
                            ),
                            _smallActionCard(
                              icon: Icons.view_list_outlined,
                              title: 'View Classes',
                              onTap: _openViewClasses,
                            ),
                            _smallActionCard(
                              icon: Icons.edit_note_outlined,
                              title: 'Manage Quizzes',
                              onTap: _openManageQuizzes,
                            ),
                            _smallActionCard(
                              icon: Icons.bar_chart_outlined,
                              title: 'Analytics',
                              onTap: _openAnalytics,
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        Row(
                          children: [
                            Text(
                              'Recent Quizzes',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: _openManageQuizzes,
                              child: Row(
                                children: [
                                  Text(
                                    'View All',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF49C7FF),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Color(0xFF49C7FF),
                                    size: 15,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        
                        _recentQuizBox(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
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

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white38),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: iconColor, width: 1.4),
              color: iconColor.withOpacity(0.12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white38),
        ),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: iconBackground.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 31,
              ),
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
  Widget _smallActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white38),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _recentQuizBox() {
    if (_loadingDashboard) {
      return _glassContainer(
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_recentQuizzes.isEmpty) {
      return _glassContainer(
        child: Text(
          'No quizzes created yet.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white38),
      ),
      child: Column(
        children: List.generate(_recentQuizzes.length, (index) {
          final quiz = _recentQuizzes[index];
          final isLast = index == _recentQuizzes.length - 1;

          return Column(
            children: [
              _recentQuizItem(
                title: quiz['title'].toString(),
                className: quiz['class'].toString(),
                date: quiz['date'].toString(),
                status: quiz['status'].toString(),
                iconColor: index == 0
                    ? const Color(0xFF168BFF)
                    : index == 1
                        ? const Color(0xFF6C55E8)
                        : const Color(0xFFFFC107),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.25),
                ),
            ],
          );
        }),
      ),
    );
  }
  Widget _glassContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white38),
      ),
      child: child,
    );
  }
  Widget _recentQuizItem({
    required String title,
    required String className,
    required String date,
    required String status,
    required Color iconColor,
  }) {
    final bool isPublished = status == 'Published';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Row(
        children: [
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$className • $date',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isPublished
                    ? const Color(0xFF19D5D2)
                    : const Color(0xFFFFC107),
              ),
            ),
            child: Text(
              status,
              style: GoogleFonts.poppins(
                color: isPublished
                    ? const Color(0xFF19D5D2)
                    : const Color(0xFFFFC107),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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

  Widget _drawerItem({
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