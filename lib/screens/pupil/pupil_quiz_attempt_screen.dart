// ======================================================
// pupil_quiz_attempt_screen.dart
//
// PURPOSE:
// Allow pupils to attempt quizzes
// and view their results after submission.
//
// MAIN LOGIC:
//
// Quiz Initialisation
// - Open selected quiz
// - Load questions and quiz settings
//
// Backend Operations
//
// READ → Supabase Edge Function
// - pupil-quiz-start
// - Retrieve quiz details
// - Retrieve questions and options
//
// WRITE → Supabase Edge Function
// - pupil-quiz-submit
// - Submit pupil answers
// - Receive score and review
//
// Quiz Logic
// - Store pupil answers temporarily
// - Support multiple question types
// - Handle manual and automatic submission
// - Control quiz timer
//
// Result Processing
// - Calculate final result
// - Display score and corrections
// - Display explanations for each question
//
// Navigation
// - Open result and review screen
//
// Utilities
// - Format timer display
// - Display status messages
//
// ======================================================
import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class PupilQuizAttemptScreen extends StatefulWidget {
  final String pupilId;
  final String quizId;
  final String quizTitle;

  const PupilQuizAttemptScreen({
    super.key,
    required this.pupilId,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<PupilQuizAttemptScreen> createState() => _PupilQuizAttemptScreenState();
}

class _PupilQuizAttemptScreenState extends State<PupilQuizAttemptScreen> {
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';

  bool _isLoading = true;
  bool _isSubmitting = false;

  Map<String, dynamic>? _quiz;
  List<dynamic> _questions = [];
  final Map<String, String> _answers = {};

  Timer? _timer;
  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _startQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startQuiz() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/pupil-quiz-start?pupilId=${widget.pupilId}&quizId=${widget.quizId}',
        ),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _quiz = data['quiz'];
          _questions = data['questions'] ?? [];
        });

        final timeLimit = _quiz?['time_limit_minutes'];
        if (timeLimit != null) {
          _remainingSeconds = (timeLimit as int) * 60;
          _startTimer();
        }
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to open quiz.');
      }
    } catch (e) {
      _showSnack('Error opening quiz: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds == null) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds! <= 1) {
        timer.cancel();
        _remainingSeconds = 0;
        if (mounted) {
          setState(() {});
        }
        await _submitQuiz(autoSubmit: true);
      } else {
        if (mounted) {
          setState(() {
            _remainingSeconds = _remainingSeconds! - 1;
          });
        }
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _submitQuiz({bool autoSubmit = false}) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'answers': _questions.map((q) {
          return {
            'question_id': q['id'],
            'answer_text': _answers[q['id']] ?? '',
          };
        }).toList(),
      };

      final response = await http.post(
        Uri.parse(
           '$baseUrl/pupil-quiz-submit?pupilId=${widget.pupilId}&quizId=${widget.quizId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PupilQuizResultScreen(
              quizTitle: widget.quizTitle,
              score: data['score'] ?? 0,
              totalPossible: data['total_possible'] ?? 0,
              review: List<Map<String, dynamic>>.from(
                (data['review'] ?? []).map((e) => Map<String, dynamic>.from(e)),
              ),
            ),
          ),
        );
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to submit quiz.');
      }
    } catch (e) {
      _showSnack('Error submitting quiz: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
            color: Colors.white.withOpacity(0.14),
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
    final hasTimer = _remainingSeconds != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        title: Text(
          widget.quizTitle,
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
                  Color(0xFF1A3B5D),
                  Color(0xFF245B7A),
                  Color(0xFF327A88),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -40,
            child: _buildCircle(160, Colors.cyanAccent.withOpacity(0.08)),
          ),
          Positioned(
            bottom: -70,
            right: -40,
            child: _buildCircle(180, Colors.pinkAccent.withOpacity(0.10)),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Column(
                    children: [
                      if (hasTimer)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: _glassCard(
                            child: Row(
                              children: [
                                const Icon(Icons.timer, color: Colors.white),
                                const SizedBox(width: 10),
                                Text(
                                  'Time left: ${_formatTime(_remainingSeconds!)}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _questions.length,
                          itemBuilder: (context, index) {
                            final q = _questions[index];
                            final questionId = q['id'].toString();
                            final questionType = q['question_type'].toString();
                            final options = List<Map<String, dynamic>>.from(
                              (q['options'] ?? []).map(
                                (e) => Map<String, dynamic>.from(e),
                              ),
                            );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _glassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Question ${index + 1}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.cyanAccent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      q['question_text'] ?? '',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (questionType == 'fill_blank')
                                      TextField(
                                        onChanged: (value) {
                                          _answers[questionId] = value;
                                        },
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Type your answer',
                                          hintStyle: GoogleFonts.poppins(
                                            color: Colors.white54,
                                          ),
                                          filled: true,
                                          fillColor:
                                              Colors.white.withOpacity(0.08),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            borderSide: const BorderSide(
                                              color: Colors.white24,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            borderSide: const BorderSide(
                                              color: Colors.cyanAccent,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ...options.map((option) {
                                        final optionText =
                                            (option['option_text'] ?? '')
                                                .toString();

                                        return RadioListTile<String>(
                                          value: optionText,
                                          groupValue: _answers[questionId],

                                          activeColor: Colors.cyanAccent,

                                          fillColor: WidgetStateProperty.resolveWith<Color>(
                                            (states) {
                                              if (states.contains(MaterialState.selected)) {
                                                return Colors.cyanAccent;
                                              }
                                              return Colors.white70;
                                            },
                                          ),

                                          title: Text(
                                            optionText,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                            ),
                                          ),

                                          onChanged: (value) {
                                            setState(() {
                                              _answers[questionId] = value ?? '';
                                            });
                                          },
                                        );
                                        
                                      }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () => _confirmSubmitQuiz(),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFF10222F),
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _isSubmitting ? 'Submitting...' : 'Submit Quiz',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: const Color(0xFF10222F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
  Future<void> _confirmSubmitQuiz() async {
  final shouldSubmit = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1A3B5D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          'Submit quiz?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to submit your answers? You cannot change them after submission.',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.white70,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: const Color(0xFF11212D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Submit',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (shouldSubmit == true) {
    _submitQuiz();
  }
}
}

class PupilQuizResultScreen extends StatelessWidget {
  final String quizTitle;
  final int score;
  final int totalPossible;
  final List<Map<String, dynamic>> review;

  const PupilQuizResultScreen({
    super.key,
    required this.quizTitle,
    required this.score,
    required this.totalPossible,
    required this.review,
  });

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
            color: Colors.white.withOpacity(0.14),
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
        backgroundColor: const Color(0xFF0F2027),
        title: Text(
          'Quiz Review',
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
                  Color(0xFF1A3B5D),
                  Color(0xFF245B7A),
                  Color(0xFF327A88),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -40,
            child: _buildCircle(160, Colors.cyanAccent.withOpacity(0.08)),
          ),
          Positioned(
            bottom: -70,
            right: -40,
            child: _buildCircle(180, Colors.pinkAccent.withOpacity(0.10)),
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
                        quizTitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Score: $score / $totalPossible',
                        style: GoogleFonts.poppins(
                          color: Colors.cyanAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
                            'Your answer: ${item['pupil_answer_text'] ?? ''}',
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