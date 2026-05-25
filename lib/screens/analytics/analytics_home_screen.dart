// ======================================================
// analytics_home_screen.dart
//
// PURPOSE:
// Main entry screen for teacher analytics.
//
// MAIN FEATURES:
// - Display available analytics modules
// - Navigate to detailed analytics screens
//
// DATABASE:
// No direct database access
//
// API:
// No API calls
//
// NAVIGATION:
//
// Opens:
// - SubtopicAnalyticsScreen
// - PupilAnalyticsSelectionScreen
// - QuizAnalyticsScreen
// - OverallAnalyticsScreen
//
// ======================================================
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'subtopic_analytics_screen.dart';
import 'pupil_analytics_selection_screen.dart';
import 'quiz_analytics_screen.dart';
import 'overall_analytics_screen.dart';

class AnalyticsHomeScreen extends StatelessWidget {
  const AnalyticsHomeScreen({super.key});


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

  Widget _glassCard({
    required Widget child,
    VoidCallback? onTap,
  }) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white30),
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: card,
    );
  }

  Widget _analyticsTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return _glassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.arrow_forward_ios,
            color: Colors.cyanAccent,
            size: 18,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11212D),
        elevation: 0,
        title: Text(
          'Analytics',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teacher Analytics',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use analytics to identify weak areas, track class performance, and better support your pupils.',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Open subtopic analytics screen.
                _analyticsTile(
                  context: context,
                  title: 'Subtopic Analytics',
                  subtitle:
                      'See only the subtopics that were quizzed, ordered from weakest to strongest.',
                  icon: Icons.analytics_outlined,
                  iconBg: Colors.redAccent.withOpacity(0.75),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubtopicAnalyticsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Open pupil analytics screen.
                _analyticsTile(
                  context: context,
                  title: 'Pupil Analytics',
                  subtitle:
                      'View each pupil’s overall performance and strengths by subtopic.',
                  icon: Icons.person_search_outlined,
                  iconBg: Colors.green.withOpacity(0.75),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PupilAnalyticsSelectionScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Open quiz analytics screen.
                _analyticsTile(
                  context: context,
                  title: 'Quiz Analytics',
                  subtitle:
                      'Analyse participation, average score, and question difficulty by quiz.',
                  icon: Icons.quiz_outlined,
                  iconBg: Colors.orange.withOpacity(0.80),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const QuizAnalyticsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Open overall analytics summary.
                _analyticsTile(
                  context: context,
                  title: 'Overall Summary',
                  subtitle:
                      'See overall performance indicators across your quizzes and classes.',
                  icon: Icons.insights_outlined,
                  iconBg: Colors.blueAccent.withOpacity(0.80),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OverallAnalyticsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}