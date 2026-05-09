import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class PupilLeaderboardDetailScreen extends StatefulWidget {
  final String pupilId;
  final String fullName;
  final String quizId;

  const PupilLeaderboardDetailScreen({
    super.key,
    required this.pupilId,
    required this.fullName,
    required this.quizId,
  });

  @override
  State<PupilLeaderboardDetailScreen> createState() =>
      _PupilLeaderboardDetailScreenState();
}

class _PupilLeaderboardDetailScreenState
    extends State<PupilLeaderboardDetailScreen> {
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';

  late ConfettiController _confettiController;

  bool _isLoading = true;
  Map<String, dynamic>? _quiz;
  List<dynamic> _podium = [];
  Map<String, dynamic>? _currentPupil;
  bool _participated = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));
    _fetchLeaderboard();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/pupil-leaderboard-detail?pupilId=${widget.pupilId}&quizId=${widget.quizId}',
        ),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _quiz = data['quiz'];
          _podium = data['podium'] ?? [];
          _currentPupil = data['current_pupil'];
          _participated = data['participated'] == true;
        });

        _confettiController.play();
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load leaderboard.');
      }
    } catch (e) {
      _showSnack('Error loading leaderboard: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs.toString().padLeft(2, '0')}s';
  }

  String _encouragementMessage(int score) {
    if (score >= 90) {
      return 'Excellent work!\nYou did very well. Keep it up and continue giving your best.';
    } else if (score >= 80) {
      return 'Very good job!\nEven if you are not on the podium, you performed strongly. Keep trying — you can get there.';
    } else if (score >= 60) {
      return 'Good effort!\nYou are making progress. Review the explanations and try again next time.';
    } else if (score >= 40) {
      return 'Keep going!\nYou have made an effort, and that matters. Read the corrections carefully and keep practising.';
    } else {
      return 'Do not give up!\nEvery quiz helps you learn. Take your time, read the explanations, and you will improve step by step.';
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
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
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
  }

  Widget _podiumBlock({
    required int place,
    required String name,
    required int score,
    required int duration,
    required double height,
    required Color color,
    required Color textColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white.withOpacity(0.18),
          child: Text(
            name.isNotEmpty ? name.trim()[0].toUpperCase() : '?',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 96,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$place',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$score%',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(duration),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizTitle = (_quiz?['title'] ?? '').toString();

    final first = _podium.length > 0 ? _podium[0] : null;
    final second = _podium.length > 1 ? _podium[1] : null;
    final third = _podium.length > 2 ? _podium[2] : null;

    final score = _currentPupil != null
        ? (_currentPupil!['score_percent'] as num?)?.toInt() ?? 0
        : 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
        title: Text(
          'Leaderboard',
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
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
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
            child: _buildCircle(160, Colors.cyanAccent.withOpacity(0.08)),
          ),
          Positioned(
            top: 100,
            right: -40,
            child: _buildCircle(150, Colors.pinkAccent.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -70,
            right: -40,
            child: _buildCircle(180, Colors.blueAccent.withOpacity(0.08)),
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
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Top performers',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      _glassCard(
                        child: SizedBox(
                          height: 270,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (second != null)
                                _podiumBlock(
                                  place: 2,
                                  name: (second['full_name'] ?? '').toString(),
                                  score: (second['score_percent'] as num?)?.toInt() ?? 0,
                                  duration: (second['duration_seconds'] as num?)?.toInt() ?? 0,
                                  height: 120,
                                  color: const Color(0xFFC0C0C0),
                                  textColor: const Color(0xFF10222F),
                                )
                              else
                                const SizedBox(width: 96),

                              if (first != null)
                                _podiumBlock(
                                  place: 1,
                                  name: (first['full_name'] ?? '').toString(),
                                  score: (first['score_percent'] as num?)?.toInt() ?? 0,
                                  duration: (first['duration_seconds'] as num?)?.toInt() ?? 0,
                                  height: 160,
                                  color: const Color(0xFFFFD700),
                                  textColor: const Color(0xFF10222F),
                                )
                              else
                                const SizedBox(width: 96),

                              if (third != null)
                                _podiumBlock(
                                  place: 3,
                                  name: (third['full_name'] ?? '').toString(),
                                  score: (third['score_percent'] as num?)?.toInt() ?? 0,
                                  duration: (third['duration_seconds'] as num?)?.toInt() ?? 0,
                                  height: 100,
                                  color: const Color(0xFFCD7F32),
                                  textColor: Colors.white,
                                )
                              else
                                const SizedBox(width: 96),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      if (_participated && _currentPupil != null)
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Score',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '$score%',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF10222F),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _encouragementMessage(score),
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  height: 1.5,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (!_participated)
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'A message for you',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'You did not participate in this quiz.\nDo not worry — keep trying and take part in the next quiz. Every attempt helps you improve.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  height: 1.5,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              emissionFrequency: 0.04,
              numberOfParticles: 40,
              maxBlastForce: 18,
              minBlastForce: 8,
              gravity: 0.20,
              shouldLoop: false,
            ),
          ),
        ],
      ),
    );
  }
}