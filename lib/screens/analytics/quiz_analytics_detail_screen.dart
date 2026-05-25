// ======================================================
// quiz_analytics_detail_screen.dart
//
// PURPOSE:
// Display detailed analytics for one selected quiz.
//
// MAIN FEATURES:
// - Load quiz performance details
// - Show hardest and easiest questions
// - Display question success rates
// - Show response statistics
//
// DATABASE:
// No direct database access
//
// API / CLOUD:
//
// READ:
// Supabase Edge Function:
// - analytics-quiz-detail
//
// Returned data:
// - quiz information
// - question statistics
// - question highlights
//
// INPUT:
// - quizId
//
// NAVIGATION:
// Opened from:
// - QuizAnalyticsScreen
//
// ======================================================
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class QuizAnalyticsDetailScreen extends StatefulWidget {
  final String quizId;

  const QuizAnalyticsDetailScreen({
    super.key,
    required this.quizId,
  });

  @override
  State<QuizAnalyticsDetailScreen> createState() =>
      _QuizAnalyticsDetailScreenState();
}

class _QuizAnalyticsDetailScreenState extends State<QuizAnalyticsDetailScreen> {
  // Base URL for Supabase Edge Functions.
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';
  // Store quiz analytics data and loading state.
  bool _isLoading = true;
  Map<String, dynamic>? _quiz;
  List<dynamic> _questions = [];
  Map<String, dynamic>? _highlights;
  // Load quiz analytics when screen opens.
  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }
  // READ quiz analytics using Supabase Edge Function.
  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    // SEND request to analytics-quiz-detail Edge Function.
    // Quiz ID is used to retrieve analytics.
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics-quiz-detail?quizId=${widget.quizId}'),
      );
      // Validate that server returned JSON.
      if (!response.body.trim().startsWith('{')) {
        _showSnack('Server did not return valid JSON for quiz details.');
        setState(() => _isLoading = false);
        return;
      }
      // Convert JSON response into usable objects.
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Store analytics data returned by Edge Function.
        setState(() {
          _quiz = data['quiz'];
          _questions = data['questions'] ?? [];
          _highlights = data['highlights'];
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load quiz details.');
      }
    } catch (e) {
      _showSnack('Error loading quiz details: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // Determine display colour based on correct rate.
  Color _rateColor(int score) {
    if (score < 50) return Colors.redAccent;
    if (score < 70) return Colors.orange;
    return Colors.green;
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

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
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
  }
  // Display hardest and easiest question highlights.
  Widget _highlightRow(String label, dynamic question, Color color) {
    // Prevent rendering if analytics data is missing.
    if (question == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question['question_text'] ?? '',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Correct rate: ${question['correct_rate'] ?? 0}%',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  // Extract question highlights for display.
  @override
  Widget build(BuildContext context) {
    final hardest = _highlights?['hardest_question'];
    final easiest = _highlights?['easiest_question'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11212D),
        elevation: 0,
        title: Text(
          'Quiz Details',
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
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _glassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_quiz?['title'] ?? '').toString(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_quiz?['subject'] ?? ''} • ${_quiz?['topic'] ?? ''}',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (hardest != null || easiest != null)
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Question Highlights',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (hardest != null)
                                _highlightRow(
                                  'Hardest Question',
                                  hardest,
                                  Colors.redAccent,
                                ),
                              if (hardest != null && easiest != null)
                                const SizedBox(height: 10),
                              if (easiest != null)
                                _highlightRow(
                                  'Easiest Question',
                                  easiest,
                                  Colors.green,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Question Performance',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._questions.map((question) {
                        final rate = (question['correct_rate'] ?? 0) as int;
                        final color = _rateColor(rate);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Question ${question['order_index'] ?? ''}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (question['question_text'] ?? '').toString(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: rate / 100,
                                          minHeight: 12,
                                          backgroundColor: Colors.white12,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(color),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$rate%',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _miniChip(
                                      'Correct',
                                      '${question['correct_count'] ?? 0}',
                                    ),
                                    _miniChip(
                                      'Wrong',
                                      '${question['wrong_count'] ?? 0}',
                                    ),
                                    _miniChip(
                                      'Skipped',
                                      '${question['skipped_count'] ?? 0}',
                                    ),
                                    _miniChip(
                                      'Responses',
                                      '${question['total_responses'] ?? 0}',
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
        ],
      ),
    );
  }

  Widget _miniChip(String label, String value) {
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
}