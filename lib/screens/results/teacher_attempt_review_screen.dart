import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherAttemptReviewScreen extends StatefulWidget {
  final String attemptId;

  const TeacherAttemptReviewScreen({
    super.key,
    required this.attemptId,
  });

  @override
  State<TeacherAttemptReviewScreen> createState() =>
      _TeacherAttemptReviewScreenState();
}

class _TeacherAttemptReviewScreenState extends State<TeacherAttemptReviewScreen> {
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';
  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  String quizTitle = '';
  String pupilName = '';
  String pupilUsername = '';
  int score = 0;
  int totalPossible = 0;
  int scorePercent = 0;
  List<Map<String, dynamic>> review = [];

  @override
  void initState() {
    super.initState();
    _fetchReview();
  }

  Future<void> _fetchReview() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/teacher-result-review?teacherId=${user.id}&attemptId=${widget.attemptId}'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          quizTitle = (data['quizTitle'] ?? '').toString();
          pupilName = (data['pupilName'] ?? '').toString();
          pupilUsername = (data['pupilUsername'] ?? '').toString();
          score = data['score'] ?? 0;
          totalPossible = data['total_possible'] ?? 0;
          scorePercent = data['score_percent'] ?? 0;
          review = List<Map<String, dynamic>>.from(
            (data['review'] ?? []).map((e) => Map<String, dynamic>.from(e)),
          );
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load review.');
      }
    } catch (e) {
      _showSnack('Error loading review: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11212D),
        elevation: 0,
        title: Text(
          'Pupil Review',
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
                            const SizedBox(height: 8),
                            Text(
                              'Pupil: $pupilName',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Username: $pupilUsername',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Score: $score / $totalPossible  ($scorePercent%)',
                              style: GoogleFonts.poppins(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...review.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isCorrect = item['is_correct'] == true;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Question ${index + 1}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item['question_text'] ?? '',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Pupil answer: ${item['pupil_answer_text'] ?? ''}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Correct answer: ${item['correct_answer_text'] ?? ''}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isCorrect
                                        ? Colors.green.withOpacity(0.18)
                                        : Colors.redAccent.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    isCorrect ? 'Correct' : 'Incorrect',
                                    style: GoogleFonts.poppins(
                                      color: isCorrect
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Explanation:',
                                  style: GoogleFonts.poppins(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['explanation'] ?? '',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
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
}