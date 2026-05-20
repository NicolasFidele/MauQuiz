import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/login_screen.dart';
import 'pupil_announcements_screen.dart';
import 'pupil_quizzes_screen.dart';
import '../results/pupil_results_screen.dart';
import 'pupil_leaderboards_screen.dart';
import 'badges_screen.dart';


class PupilDashboard extends StatelessWidget {
  final String pupilId;
  final String fullName;
  final String username;

  const PupilDashboard({
    super.key,
    required this.pupilId,
    required this.fullName,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _background(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topRow(context),

                  const SizedBox(height: 22),

                  Text(
                    'Hello, $fullName 👋',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Choose what you want to do today.',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: ListView(
                      children: [
                        _dashboardCard(
                          context,
                          title: 'Announcements',
                          subtitle: 'Read messages from your teacher',
                          icon: Icons.campaign_outlined,
                          color: const Color(0xFFFFC857),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PupilAnnouncementsScreen(
                                  pupilId: pupilId,
                                ),
                              ),
                            );
                          },
                        ),
                        _dashboardCard(
                          context,
                          title: 'Quizzes',
                          subtitle: 'Start your available quizzes',
                          icon: Icons.quiz_outlined,
                          color: const Color(0xFF4DD4AC),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PupilQuizzesScreen(
                                  pupilId: pupilId,
                                  fullName: fullName,
                                  username: username,
                                ),
                              ),
                            );
                          },
                        ),

                        _dashboardCard(
                          context,
                          title: 'Results',
                          subtitle: 'Check your scores and progress',
                          icon: Icons.assignment_outlined,
                          color: const Color(0xFF74B9FF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PupilResultsScreen(
                                  pupilId: pupilId,
                                ),
                              ),
                            );
                          },
                        ),

                        _dashboardCard(
                          context,
                          title: 'Leaderboard',
                          subtitle: 'See your ranking and achievements',
                          icon: Icons.emoji_events_outlined,
                          color: const Color(0xFFFFD166),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PupilLeaderboardsScreen(
                                  pupilId: pupilId,
                                  fullName: fullName,
                                ),
                              ),
                            );
                          },
                        ),

                        _dashboardCard(
                          context,
                          title: 'Badges',
                          subtitle: 'View your learning badges',
                          icon: Icons.workspace_premium_outlined,
                          color: const Color(0xFFFF8FAB),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BadgesScreen(
                                  pupilId: pupilId,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
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
                Color(0xFF061A30),
                Color(0xFF0B3A54),
                Color(0xFF0F5B63),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        Positioned(
          top: -70,
          left: -40,
          child: _circle(190, Colors.white.withOpacity(0.13)),
        ),

        Positioned(
          bottom: -80,
          right: -50,
          child: _circle(220, Colors.white.withOpacity(0.10)),
        ),
      ],
    );
  }

  Widget _topRow(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white30),
          ),
          child: Text(
            username,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const Spacer(),

        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              ),
              (route) => false,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white30),
            ),
            child: const Icon(
              Icons.logout,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashboardCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
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