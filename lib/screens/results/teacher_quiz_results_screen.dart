import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'teacher_attempt_review_screen.dart';

class TeacherQuizResultsScreen extends StatefulWidget {
  final String quizId;

  const TeacherQuizResultsScreen({
    super.key,
    required this.quizId,
  });

  @override
  State<TeacherQuizResultsScreen> createState() =>
      _TeacherQuizResultsScreenState();
}

class _TeacherQuizResultsScreenState extends State<TeacherQuizResultsScreen> {
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isPublishingLeaderboard = false;

  Map<String, dynamic>? _quiz;
  Map<String, dynamic>? _summary;
  List<dynamic> _pupils = [];

  @override
  void initState() {
    super.initState();
    _fetchQuizResults();
  }

  Future<void> _fetchQuizResults() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/teacher-quiz-results?teacherId=${user.id}&quizId=${widget.quizId}'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _quiz = data['quiz'];
          _summary = data['summary'];
          _pupils = data['pupils'] ?? [];
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load quiz results.');
      }
    } catch (e) {
      _showSnack('Error loading quiz results: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _publishLeaderboard() async {
    if (_isPublishingLeaderboard) return;

    setState(() => _isPublishingLeaderboard = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await http.post(
        Uri.parse(
          '$baseUrl/teacher-publish-leaderboard?teacherId=${user.id}&quizId=${widget.quizId}',
        ),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnack(
          data['message']?.toString() ?? 'Leaderboard published successfully',
        );
        await _fetchQuizResults();
      } else {
        _showSnack(
          data['error']?.toString() ?? 'Failed to publish leaderboard',
        );
      }
    } catch (e) {
      _showSnack('Error publishing leaderboard: $e');
    } finally {
      if (mounted) {
        setState(() => _isPublishingLeaderboard = false);
      }
    }
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

  Widget _summaryChip(String label, String value) {
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

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.green;
      case 'started':
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizTitle = (_quiz?['title'] ?? '').toString();
    final leaderboardPublished = _quiz?['leaderboard_published'] == true;
    final submittedCount = _summary?['submitted_count'] ?? 0;
    final startedCount = _summary?['started_count'] ?? 0;
    final notStartedCount = _summary?['not_started_count'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11212D),
        elevation: 0,
        title: Text(
          'Quiz Results',
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
            bottom: -70,
            right: -40,
            child: _buildCircle(190, Colors.blueAccent.withOpacity(0.08)),
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
                              quizTitle,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
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
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _summaryChip('Submitted', '$submittedCount'),
                                _summaryChip('Started', '$startedCount'),
                                _summaryChip('Not attempted', '$notStartedCount'),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: leaderboardPublished ||
                                        _isPublishingLeaderboard
                                    ? null
                                    : _publishLeaderboard,
                                icon: _isPublishingLeaderboard
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Color(0xFF10222F),
                                        ),
                                      )
                                    : const Icon(Icons.emoji_events_outlined),
                                label: Text(
                                  leaderboardPublished
                                      ? 'Leaderboard Published'
                                      : 'Publish Leaderboard',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: leaderboardPublished
                                      ? Colors.white24
                                      : Colors.cyanAccent,
                                  foregroundColor: leaderboardPublished
                                      ? Colors.white70
                                      : const Color(0xFF10222F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Pupils',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._pupils.map((pupil) {
                        final status =
                            (pupil['status'] ?? 'not_started').toString();
                        final canOpen = status == 'submitted';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: canOpen
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TeacherAttemptReviewScreen(
                                          attemptId:
                                              pupil['attempt_id'].toString(),
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            child: _glassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (pupil['full_name'] ?? '').toString(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Username: ${pupil['username'] ?? ''}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          status.replaceAll('_', ' ').toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (pupil['score_percent'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.cyanAccent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${pupil['score_percent']}%',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF10222F),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (canOpen) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Spacer(),
                                        Text(
                                          'Tap to review',
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
                                ],
                              ),
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
}