// ======================================================
// pupil_announcements_screen.dart
//
// PURPOSE:
// Display announcements sent to the pupil.
//
// MAIN LOGIC:
//
// Initialisation
// - Load announcements when screen opens
//
// Backend Operations
//
// READ → Supabase Edge Function
// - pupil-announcements
// - Retrieve announcements for selected pupil
//
// Data Processing
// - Extract announcement list
// - Handle loading and error states
//
// Announcement Rules
// - Display announcements sent to class
// - Display announcements sent to all classes
//
// Utilities
// - Format announcement dates
// - Refresh announcement data
// - Display status messages
//
// ======================================================
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PupilAnnouncementsScreen extends StatefulWidget {
  final String pupilId;

  const PupilAnnouncementsScreen({
    super.key,
    required this.pupilId,
  });

  @override
  State<PupilAnnouncementsScreen> createState() =>
      _PupilAnnouncementsScreenState();
}

class _PupilAnnouncementsScreenState extends State<PupilAnnouncementsScreen> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await supabase.functions.invoke(
        'pupil-announcements',
        queryParameters: {
          'pupilId': widget.pupilId,
        },
      );

      final data = response.data;
      final items = data['announcements'] ?? [];

      setState(() {
        _announcements = List<Map<String, dynamic>>.from(items);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load announcements.';
        _loading = false;
      });
    }
  }

  String _formatDate(String? value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value);
    if (date == null) return '';

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _background(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(context),

                  const SizedBox(height: 24),

                  Text(
                    'Announcements',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Messages from your teacher.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14.5,
                    ),
                  ),

                  const SizedBox(height: 22),

                  Expanded(
                    child: _body(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: _emptyCard(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          message: _error!,
        ),
      );
    }

    if (_announcements.isEmpty) {
      return Center(
        child: _emptyCard(
          icon: Icons.campaign_outlined,
          title: 'No announcements',
          message: 'Your teacher has not sent any announcement yet.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      child: ListView.builder(
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final item = _announcements[index];

          return _announcementCard(
            title: item['title'] ?? '',
            message: item['message'] ?? '',
            date: _formatDate(item['created_at']),
          );
        },
      ),
    );
  }

  Widget _announcementCard({
    required String title,
    required String message,
    required String date,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        message,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        date,
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 42,
              ),

              const SizedBox(height: 14),

              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
        ),

        const Spacer(),

        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _loadAnnouncements,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _background() {
    return Stack(
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
          top: -70,
          left: -40,
          child: _circle(190, Colors.white.withOpacity(0.10)),
        ),

        Positioned(
          bottom: -80,
          right: -50,
          child: _circle(220, Colors.white.withOpacity(0.08)),
        ),
      ],
    );
  }

  Widget _circle(double size, Color color) {
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