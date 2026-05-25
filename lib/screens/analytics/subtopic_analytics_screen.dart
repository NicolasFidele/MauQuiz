// ======================================================
// subtopic_analytics_screen.dart
//
// PURPOSE:
// Display performance analytics by subtopic
// to help teachers identify strengths and weaknesses.
//
// MAIN FEATURES:
// - Load subtopic analytics
// - Display average performance
// - Highlight weak areas for reteaching
// - Show quiz and attempt statistics
//
// DATABASE:
// No direct database access
//
// API / CLOUD:
//
// READ:
// Supabase Edge Function:
// - analytics-subtopics
//
// Returned data:
// - subtopic performance
// - average scores
// - attempts
// - quiz usage
//
// NAVIGATION:
// Opened from:
// - AnalyticsHomeScreen
//
// ======================================================
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SubtopicAnalyticsScreen extends StatefulWidget {
  const SubtopicAnalyticsScreen({super.key});

  @override
  State<SubtopicAnalyticsScreen> createState() =>
      _SubtopicAnalyticsScreenState();
}

class _SubtopicAnalyticsScreenState extends State<SubtopicAnalyticsScreen> {
  // Base URL for Supabase Edge Functions.
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<dynamic> _subtopics = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/analytics-subtopics?teacherId=${user.id}'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _subtopics = data['subtopics'] ?? [];
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load analytics.');
      }
    } catch (e) {
      _showSnack('Error loading analytics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _scoreColor(int score) {
    if (score < 50) return Colors.redAccent;
    if (score < 70) return Colors.orange;
    return Colors.green;
  }

  String _performanceLabel(int score) {
    if (score < 50) return 'Needs reteaching';
    if (score < 70) return 'Average';
    return 'Strong';
  }

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

  Widget _statChip(String label, String value) {
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
          'Subtopic Analytics',
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
                : RefreshIndicator(
                    onRefresh: _fetchAnalytics,
                    child: _subtopics.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _glassCard(
                                child: Text(
                                  'No subtopic analytics available yet.',
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
                                      'Teaching Focus',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Only subtopics that have already been used in quizzes appear here. The weakest subtopics appear first.',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._subtopics.map((item) {
                                final score =
                                    (item['average_score'] as num?)?.toInt() ?? 0;
                                final color = _scoreColor(score);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _glassCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (item['subtopic'] ?? '').toString(),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${item['subject'] ?? ''} • ${item['topic'] ?? ''}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: LinearProgressIndicator(
                                                  value: score / 100,
                                                  minHeight: 10,
                                                  backgroundColor:
                                                      Colors.white12,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(color),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '$score%',
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
                                            _statChip(
                                              'Quizzes',
                                              '${item['quizzes_count'] ?? 0}',
                                            ),
                                            _statChip(
                                              'Attempts',
                                              '${item['attempts_count'] ?? 0}',
                                            ),
                                            _statChip(
                                              'Status',
                                              _performanceLabel(score),
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