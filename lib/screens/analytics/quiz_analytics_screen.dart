// ======================================================
// quiz_analytics_screen.dart
//
// PURPOSE:
// Display analytics summary for quizzes created by teacher.
//
// MAIN FEATURES:
// - Load quiz analytics
// - Display quiz participation
// - Display score indicators
// - Open detailed quiz analytics
//
// DATABASE:
// No direct database access
//
// API / CLOUD:
//
// READ:
// Supabase Edge Function:
// - analytics-quizzes
//
// Returned data:
// - quiz statistics
// - participation indicators
// - score summaries
//
// NAVIGATION:
//
// Opens:
// - QuizAnalyticsDetailScreen
//
// ======================================================
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'quiz_analytics_detail_screen.dart';

class QuizAnalyticsScreen extends StatefulWidget {
  const QuizAnalyticsScreen({super.key});

  @override
  State<QuizAnalyticsScreen> createState() => _QuizAnalyticsScreenState();
}

class _QuizAnalyticsScreenState extends State<QuizAnalyticsScreen> {
  // Base URL for Supabase Edge Functions.
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';
  // Supabase client used to identify current teacher.
  final supabase = Supabase.instance.client;
  // Store quiz analytics results and loading state.
  bool _isLoading = true;
  List<dynamic> _quizzes = [];
  // Load quiz analytics when screen opens.
  @override 
  void initState() {
    super.initState();
    _fetchQuizAnalytics();
  }
  // Read quiz analytics using Supabase Edge Function.
  Future<void> _fetchQuizAnalytics() async {
    setState(() => _isLoading = true);
    // Retrieve current authenticated teacher.
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      // SEND request to analytics-quizzes Edge Function.
      // Teacher ID is used to retrieve analytics.
      final response = await http.get(
        Uri.parse('$baseUrl/analytics-quizzes?teacherId=${user.id}'),
      );
      // Convert JSON response into usable objects.
      final data = jsonDecode(response.body);
      // Store analytics results returned by Edge Function.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _quizzes = data['quizzes'] ?? [];
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load quiz analytics.');
      }
    } catch (e) {
      _showSnack('Error loading quiz analytics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // Display messages to teacher.
  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _glassCard({required Widget child, VoidCallback? onTap}) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white30),
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: card,
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
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
          'Quiz Analytics',
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                  // Allow teacher to refresh analytics manually.
                : RefreshIndicator(
                    onRefresh: _fetchQuizAnalytics,
                    // Show message when no analytics are available.
                    child: _quizzes.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _glassCard(
                                child: Text(
                                  'No published quiz analytics available yet.',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _glassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Quiz Performance',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Open any quiz to see participation and question-by-question performance.',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._quizzes.map((quiz) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _glassCard(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => QuizAnalyticsDetailScreen(
                                            quizId: quiz['quiz_id'].toString(),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (quiz['title'] ?? '').toString(),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${quiz['subject'] ?? ''} • ${quiz['topic'] ?? ''}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Class: ${quiz['class_name'] ?? ''}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        // Display participation and score indicators.
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            _chip('Average', '${quiz['average_score'] ?? 0}%'),
                                            _chip('Highest', '${quiz['highest_score'] ?? 0}%'),
                                            _chip('Lowest', '${quiz['lowest_score'] ?? 0}%'),
                                            _chip(
                                              'Submitted',
                                              '${quiz['submitted_count'] ?? 0}',
                                            ),
                                            _chip(
                                              'Started',
                                              '${quiz['started_count'] ?? 0}',
                                            ),
                                            _chip(
                                              'Not attempted',
                                              '${quiz['not_attempted_count'] ?? 0}',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Spacer(),
                                            Text(
                                              'Tap for details',
                                              style: GoogleFonts.poppins(
                                                color: Colors.cyanAccent,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.arrow_forward_ios,
                                              color: Colors.cyanAccent,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}