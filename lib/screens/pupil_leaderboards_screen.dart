import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'pupil_leaderboard_detail_screen.dart';

class PupilLeaderboardsScreen extends StatefulWidget {
  final String pupilId;
  final String fullName;

  const PupilLeaderboardsScreen({
    super.key,
    required this.pupilId,
    required this.fullName,
  });

  @override
  State<PupilLeaderboardsScreen> createState() =>
      _PupilLeaderboardsScreenState();
}

class _PupilLeaderboardsScreenState extends State<PupilLeaderboardsScreen> {
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';

  bool _isLoading = true;
  List<dynamic> _leaderboards = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboards();
  }

  Future<void> _fetchLeaderboards() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pupil-leaderboards?pupilId=${widget.pupilId}')
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _leaderboards = data['leaderboards'] ?? [];
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load leaderboards.');
      }
    } catch (e) {
      _showSnack('Error loading leaderboards: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
        title: Text(
          'Leaderboards',
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
              onRefresh: _fetchLeaderboards,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _leaderboards.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _glassCard(
                              child: Text(
                                'No leaderboard is available yet.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _leaderboards.length,
                          itemBuilder: (context, index) {
                            final item = _leaderboards[index];
                            final participated = item['participated'] == true;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PupilLeaderboardDetailScreen(
                                        pupilId: widget.pupilId,
                                        fullName: widget.fullName,
                                        quizId: item['quiz_id'].toString(),
                                      ),
                                    ),
                                  );
                                },
                                child: _glassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (item['title'] ?? '').toString(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
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
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: participated
                                              ? Colors.cyanAccent
                                              : Colors.orange,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          participated
                                              ? 'Your score: ${item['score_percent'] ?? 0}%'
                                              : 'You did not participate',
                                          style: GoogleFonts.poppins(
                                            color: participated
                                                ? const Color(0xFF10222F)
                                                : Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Spacer(),
                                          Text(
                                            'Open leaderboard',
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