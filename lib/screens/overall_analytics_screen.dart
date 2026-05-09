import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class OverallAnalyticsScreen extends StatefulWidget {
  const OverallAnalyticsScreen({super.key});

  @override
  State<OverallAnalyticsScreen> createState() =>
      _OverallAnalyticsScreenState();
}

class _OverallAnalyticsScreenState extends State<OverallAnalyticsScreen> {
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';
  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  Map<String, dynamic>? overall;
  Map<String, dynamic>? strongestSubject;
  Map<String, dynamic>? weakestSubject;
  List<dynamic> subjects = [];

  @override
  void initState() {
    super.initState();
    _fetchOverall();
  }

  Future<void> _fetchOverall() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/analytics-overall?teacherId=${user.id}')
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          overall = data['overall'];
          strongestSubject = data['strongest_subject'];
          weakestSubject = data['weakest_subject'];
          subjects = data['subjects'] ?? [];
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load overall analytics.');
      }
    } catch (e) {
      _showSnack('Error loading overall analytics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _insightText() {
    if (overall == null) {
      return '';
    }

    final avg = overall?['overall_average_score'] ?? 0;
    final participation = overall?['participation_rate'] ?? 0;

    if ((overall?['published_quizzes'] ?? 0) == 0) {
      return 'No published quizzes yet, so no overall analytics are available.';
    }

    if (avg < 50 && participation < 50) {
      return 'Overall performance and participation are both low. More follow-up and support may be needed.';
    }

    if (avg < 50) {
      return 'Overall performance is low. It may be helpful to review weaker areas and reteach difficult content.';
    }

    if (participation < 50) {
      return 'Participation is currently low, even though some performance data is available.';
    }

    if (avg < 70) {
      return 'Overall performance is moderate. Some subjects may still need reinforcement.';
    }

    return 'Overall performance is encouraging across the published quizzes.';
  }

  Color _scoreColor(int score) {
    if (score < 50) return Colors.redAccent;
    if (score < 70) return Colors.orange;
    return Colors.green;
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

  Widget _summaryTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlightRow({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final publishedQuizzes = overall?['published_quizzes'] ?? 0;
    final totalSubmissions = overall?['total_submissions'] ?? 0;
    final averageScore = overall?['overall_average_score'] ?? 0;
    final participationRate = overall?['participation_rate'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11212D),
        elevation: 0,
        title: Text(
          'Overall Summary',
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
                    onRefresh: _fetchOverall,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overall Teaching Summary',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _insightText(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  height: 1.5,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _summaryTile(
                              title: 'Published Quizzes',
                              value: '$publishedQuizzes',
                              icon: Icons.publish_outlined,
                            ),
                            const SizedBox(width: 12),
                            _summaryTile(
                              title: 'Total Submissions',
                              value: '$totalSubmissions',
                              icon: Icons.assignment_turned_in_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _summaryTile(
                              title: 'Overall Average',
                              value: '$averageScore%',
                              icon: Icons.insights_outlined,
                            ),
                            const SizedBox(width: 12),
                            _summaryTile(
                              title: 'Participation Rate',
                              value: '$participationRate%',
                              icon: Icons.groups_2_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (strongestSubject != null || weakestSubject != null)
                          _glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Subject Highlights',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (strongestSubject != null)
                                  _highlightRow(
                                    label: 'Strongest Subject',
                                    value:
                                        '${strongestSubject!['subject']} (${strongestSubject!['average_score']}%)',
                                    color: Colors.green,
                                  ),
                                if (strongestSubject != null && weakestSubject != null)
                                  const SizedBox(height: 10),
                                if (weakestSubject != null)
                                  _highlightRow(
                                    label: 'Weakest Subject',
                                    value:
                                        '${weakestSubject!['subject']} (${weakestSubject!['average_score']}%)',
                                    color: Colors.redAccent,
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Subject Performance',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (subjects.isEmpty)
                          _glassCard(
                            child: Text(
                              'No subject analytics available yet.',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ...subjects.map((item) {
                          final score = (item['average_score'] ?? 0) as int;
                          final color = _scoreColor(score);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _glassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (item['subject'] ?? '').toString(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: LinearProgressIndicator(
                                            value: score / 100,
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
                                      _miniChip(
                                        'Quizzes',
                                        '${item['quizzes_count'] ?? 0}',
                                      ),
                                      _miniChip(
                                        'Submissions',
                                        '${item['submissions_count'] ?? 0}',
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