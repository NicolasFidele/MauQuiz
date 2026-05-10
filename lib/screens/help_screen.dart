import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _background(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(context),

                  const SizedBox(height: 24),

                  Text(
                    'Help & Support',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Quick help for using MauQuiz.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: ListView(
                      children: const [
                        HelpTile(
                          title: 'How to create a class',
                          content:
                              'Open Create Class, enter the class name, and add pupils. Usernames and PINs are created automatically.',
                        ),

                        HelpTile(
                          title: 'How to create a smart quiz',
                          content:
                              'Open Create Smart Quiz, choose the subject and topic, then let AI generate the quiz automatically.',
                        ),

                        HelpTile(
                          title: 'How pupils log in',
                          content:
                              'Pupils log in using their username and 4-digit PIN. First login requires a new PIN.',
                        ),

                        HelpTile(
                          title: 'How results work',
                          content:
                              'After quiz submission, scores and analytics are calculated automatically.',
                        ),

                        HelpTile(
                          title: 'How leaderboard works',
                          content:
                              'Higher scores rank first. If scores are equal, faster completion ranks higher.',
                        ),

                        HelpTile(
                          title: 'How analytics work',
                          content:
                              'Analytics show participation, averages, strongest subjects, and weakest subjects.',
                        ),
                      ],
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

  Widget _background() {
    return Container(
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
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class HelpTile extends StatelessWidget {
  final String title;
  final String content;

  const HelpTile({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: ExpansionTile(
            collapsedIconColor: Colors.white,
            iconColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.08),
            collapsedBackgroundColor: Colors.white.withOpacity(0.08),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Text(
                  content,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}