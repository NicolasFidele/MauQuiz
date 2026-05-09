import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pupil_analytics_screen.dart';

class PupilAnalyticsSelectionScreen extends StatefulWidget {
  const PupilAnalyticsSelectionScreen({super.key});

  @override
  State<PupilAnalyticsSelectionScreen> createState() =>
      _PupilAnalyticsSelectionScreenState();
}

class _PupilAnalyticsSelectionScreenState
    extends State<PupilAnalyticsSelectionScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<dynamic> _classes = [];
  List<dynamic> _pupils = [];
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final classes = await supabase
          .from('classes')
          .select('id, class_name')
          .eq('teacher_id', user.id)
          .order('class_name', ascending: true);

      setState(() {
        _classes = classes;
      });
    } catch (e) {
      _showSnack('Error loading classes: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPupils(String classId) async {
    setState(() {
      _isLoading = true;
      _pupils = [];
    });

    try {
      final pupils = await supabase
          .from('pupils')
          .select('id, full_name, username')
          .eq('class_id', classId)
          .order('full_name', ascending: true);

      setState(() {
        _pupils = pupils;
      });
    } catch (e) {
      _showSnack('Error loading pupils: $e');
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

  Widget _glassCard({required Widget child, VoidCallback? onTap}) {
    final card = ClipRRect(
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

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11212D),
        elevation: 0,
        title: Text(
          'Select Pupil',
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
            top: 110,
            right: -50,
            child: _buildCircle(150, Colors.purpleAccent.withOpacity(0.08)),
          ),
          Positioned(
            bottom: -70,
            left: 10,
            child: _buildCircle(210, Colors.blueAccent.withOpacity(0.08)),
          ),
          SafeArea(
            child: _isLoading && _classes.isEmpty
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
                              'Choose a Class',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedClassId,
                                  dropdownColor: const Color(0xFF1C3444),
                                  isExpanded: true,
                                  iconEnabledColor: Colors.white,
                                  style:
                                      GoogleFonts.poppins(color: Colors.white),
                                  hint: Text(
                                    'Select a class',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white54,
                                    ),
                                  ),
                                  items: _classes
                                      .map<DropdownMenuItem<String>>((c) {
                                    return DropdownMenuItem<String>(
                                      value: c['id'].toString(),
                                      child: Text(
                                        c['class_name'].toString(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    setState(() {
                                      _selectedClassId = value;
                                    });
                                    await _loadPupils(value);
                                  },
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
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedClassId == null)
                        _glassCard(
                          child: Text(
                            'Please select a class first.',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      if (_selectedClassId != null && _pupils.isEmpty && !_isLoading)
                        _glassCard(
                          child: Text(
                            'No pupils found in this class.',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      if (_selectedClassId != null && _isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ..._pupils.map((pupil) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _glassCard(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PupilAnalyticsScreen(
                                    pupilId: pupil['id'].toString(),
                                    pupilName:
                                        (pupil['full_name'] ?? '').toString(),
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.12),
                                  child: Text(
                                    (pupil['full_name'] ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty
                                        ? (pupil['full_name']
                                                .toString()
                                                .trim()[0])
                                            .toUpperCase()
                                        : '?',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.cyanAccent,
                                  size: 16,
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