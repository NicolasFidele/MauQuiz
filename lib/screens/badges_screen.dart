import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class BadgesScreen extends StatefulWidget {
  final String pupilId;

  const BadgesScreen({
    super.key,
    required this.pupilId,
  });

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
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
        _showSnack(data['error']?.toString() ?? 'Failed to load badges.');
      }
    } catch (e) {
      _showSnack('Error loading badges: $e');
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
  int _scorePercent(dynamic result) {
    final value = result['score_percent'];

    if (value == null) return 0;

    if (value is int) return value;

    if (value is double) return value.round();

    return int.tryParse(value.toString()) ?? 0;
  }

  bool get hasCompletedFirstQuiz {
    return _results.isNotEmpty;
  }

  bool get hasPerfectScore {
    return _results.any((result) => _scorePercent(result) == 100);
  }

  bool get hasQuizExplorer {
    return _results.length >= 5;
  }

  bool get hasHighAchiever {
    return _results.any((result) => _scorePercent(result) >= 80);
  }

  bool get hasImproved {
    if (_results.length < 2) return false;

    final firstScore = _scorePercent(_results.first);
    final lastScore = _scorePercent(_results.last);

    return lastScore > firstScore;
  }

  bool get hasActiveLearner {
    return _results.length >= 3;
  }

  bool get hasComebackLearner {
    if (_results.length < 2) return false;

    for (int i = 1; i < _results.length; i++) {
      final previous = _scorePercent(_results[i - 1]);
      final current = _scorePercent(_results[i]);

      if (previous < 50 && current >= 70) {
        return true;
      }
    }

    return false;
  }

  bool get hasSubjectExplorer {
    final subjects = <String>{};

    for (final result in _results) {
      final subject = (result['subject'] ?? '').toString().trim();

      if (subject.isNotEmpty) {
        subjects.add(subject.toLowerCase());
      }
    }

    return subjects.length >= 2;
  }

  @override
  Widget build(BuildContext context) {
    final badges = [
      {
        'title': 'First Quiz',
        'description': 'Complete your first quiz',
        'icon': Icons.check_circle_outline,
        'earned': hasCompletedFirstQuiz,
      },
      {
        'title': 'Perfect Score',
        'description': 'Score 100% in a quiz',
        'icon': Icons.star_outline,
        'earned': hasPerfectScore,
      },
      {
        'title': 'Quiz Explorer',
        'description': 'Complete 5 quizzes',
        'icon': Icons.explore_outlined,
        'earned': hasQuizExplorer,
      },
      {
        'title': 'High Achiever',
        'description': 'Score 80% or more',
        'icon': Icons.trending_up_outlined,
        'earned': hasHighAchiever,
      },
      {
        'title': 'Improvement',
        'description': 'Improve your latest score',
        'icon': Icons.auto_graph_outlined,
        'earned': hasImproved,
      },
      {
        'title': 'Active Learner',
        'description': 'Complete 3 quizzes',
        'icon': Icons.school_outlined,
        'earned': hasActiveLearner,
      },
      {
        'title': 'Comeback',
        'description': 'Improve from below 50% to 70%+',
        'icon': Icons.restart_alt_outlined,
        'earned': hasComebackLearner,
      },
      {
        'title': 'Subject Explorer',
        'description': 'Try quizzes in 2 subjects',
        'icon': Icons.menu_book_outlined,
        'earned': hasSubjectExplorer,
      },
    ];

    final earnedCount =
        badges.where((badge) => badge['earned'] == true).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
        title: Text(
          'My Badges',
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
            child: RefreshIndicator(
              onRefresh: _fetchResults,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _summaryCard(
                          earnedCount: earnedCount,
                          totalCount: badges.length,
                        ),
                        const SizedBox(height: 14),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: badges.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.95,
                          ),
                          itemBuilder: (context, index) {
                            final badge = badges[index];

                            return _badgeCard(
                              title: badge['title'] as String,
                              description: badge['description'] as String,
                              icon: badge['icon'] as IconData,
                              earned: badge['earned'] as bool,
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required int earnedCount,
    required int totalCount,
  }) {
    return _glassCard(
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            color: Colors.amberAccent,
            size: 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$earnedCount / $totalCount badges unlocked',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete more quizzes to unlock more badges.',
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
    );
  }

  Widget _badgeCard({
    required String title,
    required String description,
    required IconData icon,
    required bool earned,
  }) {
    return _glassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: earned ? Colors.amberAccent : Colors.white38,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: earned ? Colors.white : Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: earned ? Colors.white70 : Colors.white38,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: earned
                  ? Colors.greenAccent.withOpacity(0.18)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: earned ? Colors.greenAccent : Colors.white12,
              ),
            ),
            child: Text(
              earned ? 'Unlocked' : 'Locked',
              style: GoogleFonts.poppins(
                color: earned ? Colors.greenAccent : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
}