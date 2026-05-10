import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'pupil_quiz_attempt_screen.dart';

class PupilQuizzesScreen extends StatefulWidget {
  final String pupilId;
  final String fullName;
  final String username;

  const PupilQuizzesScreen({
    super.key,
    required this.pupilId,
    required this.fullName,
    required this.username,
  });

  @override
  State<PupilQuizzesScreen> createState() => _PupilQuizzesScreenState();
}

class _PupilQuizzesScreenState extends State<PupilQuizzesScreen> {
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';

  bool _isLoading = true;
  List<dynamic> _quizzes = [];

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pupil-quizzes?pupilId=${widget.pupilId}')
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _quizzes = data['quizzes'] ?? [];
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load quizzes.');
      }
    } catch (e) {
      _showSnack('Error loading quizzes: $e');
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

  // Color _statusColor(String availabilityStatus) {
  //   switch (availabilityStatus) {
  //     case 'open':
  //       return Colors.green;
  //     case 'upcoming':
  //       return Colors.orange;
  //     case 'closed':
  //       return Colors.redAccent;
  //     default:
  //       return Colors.grey;
  //   }
  // }

  // String _formatStatus(String status) {
  //   switch (status) {
  //     case 'open':
  //       return 'Available';
  //     case 'upcoming':
  //       return 'Upcoming';
  //     case 'closed':
  //       return 'Closed';
  //     case 'inactive':
  //       return 'Inactive';
  //     default:
  //       return status;
  //   }
  // }

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
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openQuizzes = _quizzes
        .where((q) => (q['availability_status'] ?? '') == 'open')
        .toList();

    final otherQuizzes = _quizzes
        .where((q) => (q['availability_status'] ?? '') != 'open')
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
        title: Text(
          'My Quizzes',
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
            top: 120,
            right: -50,
            child: _buildCircle(140, Colors.pinkAccent.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -70,
            right: -40,
            child: _buildCircle(180, Colors.blueAccent.withOpacity(0.08)),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchQuizzes,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _glassCard(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white.withOpacity(0.15),
                                child: const Icon(
                                  Icons.school_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hello, ${widget.fullName}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Check your quizzes below',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Available Now',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (openQuizzes.isEmpty)
                          _glassCard(
                            child: Text(
                              'No quizzes are available right now.',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ...openQuizzes.map((quiz) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _quizCard(quiz),
                            )),
                        const SizedBox(height: 20),
                        Text(
                          'Other Quizzes',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (otherQuizzes.isEmpty)
                          _glassCard(
                            child: Text(
                              'No other quizzes found.',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ...otherQuizzes.map((quiz) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _quizCard(quiz),
                            )),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quizCard(dynamic quiz) {
    final availabilityStatus = (quiz['availability_status'] ?? '').toString();
    final attemptStatus = (quiz['attempt_status'] ?? '').toString();
    final scorePercent = quiz['score_percent'];
    final canOpen = availabilityStatus == 'open';

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (quiz['title'] ?? '').toString(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (attemptStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    attemptStatus.replaceAll('_', ' ').toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (scorePercent != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$scorePercent%',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF10222F),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  attemptStatus.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Questions: ${quiz['number_of_questions'] ?? ''}',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Deadline: ${quiz['deadline_at'] ?? ''}',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: canOpen
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PupilQuizAttemptScreen(
                            pupilId: widget.pupilId,
                            quizId: quiz['quiz_id'].toString(),
                            quizTitle: (quiz['title'] ?? '').toString(),
                          ),
                        ),
                      );

                      await _fetchQuizzes();
                    }
                  : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                canOpen ? 'Open Quiz' : 'Unavailable',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canOpen ? Colors.cyanAccent : Colors.white24,
                foregroundColor:
                    canOpen ? const Color(0xFF10222F) : Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}