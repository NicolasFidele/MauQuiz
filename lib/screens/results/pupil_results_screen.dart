// ======================================================
// pupil_results_screen.dart
//
// PURPOSE:
// Display completed quiz results
// and allow pupils to review answers.
//
// MAIN LOGIC:
//
// Initialisation
// - Load pupil quiz results
//
// Backend Operations
//
// READ → Supabase Edge Functions
// - pupil-results
// - Retrieve completed quizzes
//
// READ → Supabase Edge Function
// - pupil-result-review
// - Retrieve detailed review for a quiz attempt
//
// Result Logic
// - Display score and correct answers
// - Display submission history
// - Open detailed result review
//
// Navigation
// - Open quiz result screen
//
// Utilities
// - Format submission date
// - Display status messages
// - Refresh result data
//
// ======================================================
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../pupil/pupil_quiz_attempt_screen.dart';

class PupilResultsScreen extends StatefulWidget {
  final String pupilId;

  const PupilResultsScreen({
    super.key,
    required this.pupilId,
  });

  @override
  State<PupilResultsScreen> createState() => _PupilResultsScreenState();
}

class _PupilResultsScreenState extends State<PupilResultsScreen> {
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';

  bool _isLoading = true;
  List<dynamic> _results = [];

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pupil-results?pupilId=${widget.pupilId}'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _results = data['results'] ?? [];
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load results.');
      }
    } catch (e) {
      _showSnack('Error loading results: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openResult(dynamic result) async {
    try {
      final attemptId = result['attempt_id'].toString();

      final response = await http.get(
        Uri.parse(
          '$baseUrl/pupil-result-review?pupilId=${widget.pupilId}&attemptId=$attemptId',
        ),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PupilQuizResultScreen(
              quizTitle: (data['quizTitle'] ?? '').toString(),
              score: data['score'] ?? 0,
              totalPossible: data['total_possible'] ?? 0,
              review: List<Map<String, dynamic>>.from(
                (data['review'] ?? []).map((e) => Map<String, dynamic>.from(e)),
              ),
            ),
          ),
        );
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to open result.');
      }
    } catch (e) {
      _showSnack('Error opening result: $e');
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
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white30),
          ),
          child: child,
        ),
      ),
    );
  }

  String _formatDate(String? dateText) {
    if (dateText == null || dateText.isEmpty) return '';
    final dt = DateTime.tryParse(dateText);
    if (dt == null) return dateText;
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
        title: Text(
          'My Results',
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
            child: RefreshIndicator(
              onRefresh: _fetchResults,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _results.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _glassCard(
                              child: Text(
                                'No quiz results yet.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final result = _results[index];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () => _openResult(result),
                                child: _glassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (result['title'] ?? '').toString(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${result['subject'] ?? ''} • ${result['topic'] ?? ''}',
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
                                              color: Colors.cyanAccent,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${result['score_percent']}%',
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF10222F),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Correct: ${result['correct_answers'] ?? 0}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Submitted: ${_formatDate(result['submitted_at']?.toString())}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
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
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}