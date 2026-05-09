import 'dart:convert';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/supabase_service.dart';

class AddPupilScreen extends StatefulWidget {
  final String classId;
  final String classCode;
  final String className;

  const AddPupilScreen({
    super.key,
    required this.classId,
    required this.classCode,
    required this.className,
  });

  @override
  State<AddPupilScreen> createState() => _AddPupilScreenState();
}

class _AddPupilScreenState extends State<AddPupilScreen> {
  final TextEditingController fullNameController = TextEditingController();
  bool _isSaving = false;

  static const String _defaultPin = '1234';

  @override
  void dispose() {
    fullNameController.dispose();
    super.dispose();
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  String _extractFirstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : fullName;
  }

  String _sanitizeName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _generateSingleUsername({
    required String classCode,
    required String fullName,
    required List<Map<String, dynamic>> existingPupils,
  }) {
    final firstName = _extractFirstName(fullName);
    final baseName = _sanitizeName(firstName);

    final existingUsernames = existingPupils
        .map((p) => (p['username'] ?? '').toString())
        .toList();

    final baseUsername = '${classCode}_$baseName';

    if (!existingUsernames.contains(baseUsername)) {
      return baseUsername;
    }

    int counter = 1;
    while (existingUsernames.contains('${classCode}_${baseName}$counter')) {
      counter++;
    }

    return '${classCode}_${baseName}$counter';
  }

  Future<void> _savePupil() async {
    final teacher = supabase.auth.currentUser;
    final fullName = fullNameController.text.trim();

    if (teacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logged-in teacher found')),
      );
      return;
    }

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter pupil full name')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final existingPupils = await supabase
          .from('pupils')
          .select('username')
          .eq('class_id', widget.classId);

      final existingList = List<Map<String, dynamic>>.from(existingPupils);

      final username = _generateSingleUsername(
        classCode: widget.classCode,
        fullName: fullName,
        existingPupils: existingList,
      );

      await supabase.from('pupils').insert({
        'class_id': widget.classId,
        'teacher_id': teacher.id,
        'full_name': fullName,
        'username': username,
        'pin_hash': _hashPin(_defaultPin),
        'must_change_pin': true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pupil added: $username')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add pupil: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Add Pupil',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Class: ${widget.className}',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: fullNameController,
                              style: GoogleFonts.poppins(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Enter pupil full name',
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.white70,
                                ),
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7F5AF0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _isSaving ? null : _savePupil,
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Add Pupil',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Default PIN for new pupils: 1234',
                              style: GoogleFonts.poppins(
                                color: Colors.amberAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
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