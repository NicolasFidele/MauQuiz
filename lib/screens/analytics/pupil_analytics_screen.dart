// ======================================================
// pupil_analytics_screen.dart
//
// PURPOSE:
// Display detailed analytics for one selected pupil.
//
// MAIN FEATURES:
// - Load pupil analytics
// - Display average performance
// - Show strongest and weakest subtopics
// - Display performance by subtopic
// - Generate teacher insights
//
// DATABASE:
// No direct database access
//
// API / CLOUD:
//
// READ:
// Supabase Edge Function:
// - analytics-pupil
//
// Returned data:
// - overall pupil statistics
// - attempts
// - subtopic performance
//
// INPUT:
// - pupilId
// - pupilName
//
// NAVIGATION:
// Opened from:
// - PupilAnalyticsSelectionScreen
//
// ======================================================
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class PupilAnalyticsScreen extends StatefulWidget {
  final String pupilId;
  final String pupilName;

  const PupilAnalyticsScreen({
    super.key,
    required this.pupilId,
    required this.pupilName,
  });

  @override
  State<PupilAnalyticsScreen> createState() => _PupilAnalyticsScreenState();
}

class _PupilAnalyticsScreenState extends State<PupilAnalyticsScreen> {
  // Base URL for Supabase Edge Functions.
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';
  // Store analytics results and loading state.
  bool _isLoading = true;

  int averageScore = 0;
  int attempts = 0;
  List<dynamic> subtopics = [];

  @override
  // Load pupil analytics when screen opens.
  void initState() {
    super.initState();
    _fetchData();
  }
  // READ analytics data for selected pupil
  // using Supabase Edge Function.
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // SEND request to analytics-pupil Edge Function.
      // Pupil ID is used to calculate performance.
      final response = await http.get(
        Uri.parse('$baseUrl/analytics-pupil?pupilId=${widget.pupilId}'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Store analytics data returned by Edge Function.
        setState(() {
          averageScore = (data['overall']?['average_score'] ?? 0) as int;
          attempts = (data['overall']?['attempts'] ?? 0) as int;
          subtopics = data['subtopics'] ?? [];
        });
      } else {
        _showSnack(
          data['error']?.toString() ?? 'Failed to load pupil analytics.',
        );
      }
    } catch (e) {
      _showSnack('Error loading pupil analytics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // Determine score colour for visual indicators.
  Color _scoreColor(int score) {
    if (score < 50) return Colors.redAccent;
    if (score < 70) return Colors.orange;
    return Colors.green;
  }
  // Generate performance category from score.
  String _performanceLabel(int score) {
    if (score < 50) return 'Needs support';
    if (score < 70) return 'Making progress';
    return 'Doing well';
  }
  // Generate teacher interpretation from analytics.
  String _teacherInsight() {
    if (attempts == 0) {
      return 'This pupil has not yet submitted any quiz, so there is no performance data available.';
    }

    if (averageScore < 50) {
      return 'This pupil is struggling in the assessed subtopics and may need additional support and revision.';
    }

    if (averageScore < 70) {
      return 'This pupil is making progress but still has some gaps in understanding in certain subtopics.';
    }

    return 'This pupil is performing well overall in the assessed subtopics.';
  }
  // Group subtopics by subject and identify
  // strongest and weakest performance areas. 
  List<Map<String, dynamic>> _subjectHighlights() {
    if (subtopics.isEmpty) return [];

    final Map<String, List<dynamic>> grouped = {};
    // Organise subtopics by subject.
    for (final item in subtopics) {
      final subject = (item['subject'] ?? 'Unknown').toString();
      grouped.putIfAbsent(subject, () => []);
      grouped[subject]!.add(item);
    }

    final List<Map<String, dynamic>> results = [];

    for (final entry in grouped.entries) {
      final subject = entry.key;
      final items = [...entry.value];
      // Sort scores to determine weakest and strongest.
      items.sort(
        (a, b) => ((a['average_score'] ?? 0) as num)
            .compareTo((b['average_score'] ?? 0) as num),
      );

      if (items.length < 2) {
        results.add({
          'subject': subject,
          'only_one': true,
          'item': items.first,
        });
      } else {
        results.add({
          'subject': subject,
          'only_one': false,
          'weakest': items.first,
          'strongest': items.last,
        });
      }
    }

    return results;
  }
  // Display messages to teacher.
  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
  // Display analytics summary indicators.
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
  // Display performance for one assessed subtopic.
  Widget _subtopicBar(dynamic item) {
    final score = (item['average_score'] ?? 0) as int;
    final color = _scoreColor(score);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (item['subtopic'] ?? '').toString(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item['subject'] ?? ''} • ${item['topic'] ?? ''}',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 12,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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
            const SizedBox(height: 8),
            Text(
              _performanceLabel(score),
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // Display strongest and weakest highlights.
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
  // Build pupil analytics interface.
  @override
  Widget build(BuildContext context) {
    // Prepare subject highlights for display.
    final subjectHighlights = _subjectHighlights();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11212D),
        elevation: 0,
        title: Text(
          widget.pupilName,
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
                    onRefresh: _fetchData,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overall Pupil Performance',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _teacherInsight(),
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
                              title: 'Average Score',
                              value: '$averageScore%',
                              icon: Icons.insights_outlined,
                            ),
                            const SizedBox(width: 12),
                            _summaryTile(
                              title: 'Quizzes Attempted',
                              value: '$attempts',
                              icon: Icons.quiz_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Display strongest and weakest subject areas.
                        if (subjectHighlights.isNotEmpty)
                          _glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Performance Highlights',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...subjectHighlights.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  final subject = item['subject'].toString();

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          index == subjectHighlights.length - 1
                                          ? 0
                                          : 14,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white24,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            subject,
                                            style: GoogleFonts.poppins(
                                              color: Colors.cyanAccent,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          if (item['only_one'] == true)
                                            Text(
                                              'Only one assessed subtopic so far: ${item['item']['subtopic']} (${item['item']['average_score']}%)',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white70,
                                                height: 1.5,
                                                fontSize: 13,
                                              ),
                                            )
                                          else ...[
                                            _highlightRow(
                                              label: 'Strongest Subtopic',
                                              value:
                                                  '${item['strongest']['subtopic']} (${item['strongest']['average_score']}%)',
                                              color: Colors.green,
                                            ),
                                            const SizedBox(height: 10),
                                            _highlightRow(
                                              label: 'Weakest Subtopic',
                                              value:
                                                  '${item['weakest']['subtopic']} (${item['weakest']['average_score']}%)',
                                              color: Colors.redAccent,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Subtopic Performance',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (subtopics.isEmpty)
                          _glassCard(
                            child: Text(
                              'No subtopic performance data available yet.',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          // Display detailed subtopic performance.
                        ...subtopics.map(_subtopicBar),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}