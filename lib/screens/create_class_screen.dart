import 'dart:convert';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/supabase_service.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final TextEditingController classNameController = TextEditingController();
  final TextEditingController pupilNameController = TextEditingController();

  final List<String> pupils = [];
  bool _isSaving = false;

  static const String _defaultPin = '1234';

  @override
  void dispose() {
    classNameController.dispose();
    pupilNameController.dispose();
    super.dispose();
  }

  void addPupil() {
    final name = pupilNameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a pupil name first')),
      );
      return;
    }

    setState(() {
      pupils.add(name);
      pupilNameController.clear();
    });
  }

  void removePupil(int index) {
    setState(() {
      pupils.removeAt(index);
    });
  }

  Future<void> createClass() async {
    final className = classNameController.text.trim();

    if (className.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a class name')),
      );
      return;
    }

    if (pupils.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one pupil')),
      );
      return;
    }

    final teacher = supabase.auth.currentUser;
    if (teacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logged-in teacher found')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final classCode = _generateClassCode(className);
      final generatedPupils = _generatePupilUsernames(classCode, pupils);
      final hashedDefaultPin = _hashPin(_defaultPin);

      // Save class first
      final insertedClass = await supabase
          .from('classes')
          .insert({
            'teacher_id': teacher.id,
            'class_name': className,
            'class_code': classCode,
          })
          .select()
          .single();

      final classId = insertedClass['id'] as String;
      final createdAt = insertedClass['created_at']?.toString() ?? '';

      // Save pupils
      final pupilRows = generatedPupils
          .map(
            (pupil) => {
              'class_id': classId,
              'teacher_id': teacher.id,
              'full_name': pupil['full_name'],
              'username': pupil['username'],
              'pin_hash': hashedDefaultPin,
              'must_change_pin': true,
            },
          )
          .toList();

      await supabase.from('pupils').insert(pupilRows);

      if (!mounted) return;

      await _showCreatedClassDialog(
        className: className,
        classCode: classCode,
        createdAt: createdAt,
        generatedPupils: generatedPupils,
      );

      setState(() {
        classNameController.clear();
        pupils.clear();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save class: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showCreatedClassDialog({
    required String className,
    required String classCode,
    required String createdAt,
    required List<Map<String, String>> generatedPupils,
  }) async {
    final createdDate = createdAt.isNotEmpty
        ? _formatDisplayDate(DateTime.tryParse(createdAt) ?? DateTime.now())
        : _formatDisplayDate(DateTime.now());

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F3442),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Class Created',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Name: $className',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Class Code: $classCode',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Created On: $createdDate',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Generated Pupil Usernames',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...generatedPupils.map(
                    (pupil) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${pupil['full_name']}  →  ${pupil['username']}',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Temporary PIN for all new pupils: $_defaultPin',
                    style: GoogleFonts.poppins(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pupils will be required to create their own 4-digit PIN on first login.',
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Done',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  String _generateClassCode(String className) {
    final cleaned = className.toLowerCase().trim();
    final words = cleaned.split(RegExp(r'\s+'));

    String code = '';
    for (final word in words) {
      if (word.isEmpty) continue;

      final digitMatch = RegExp(r'\d+').firstMatch(word);
      if (digitMatch != null) {
        code += digitMatch.group(0)!;
      } else {
        code += word[0];
      }
    }

    return code.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  List<Map<String, String>> _generatePupilUsernames(
    String classCode,
    List<String> pupilNames,
  ) {
    final Map<String, int> nameCounts = {};
    final List<Map<String, String>> result = [];

    for (final fullName in pupilNames) {
      final firstName = _extractFirstName(fullName);
      final baseName = _sanitizeName(firstName);

      if (nameCounts.containsKey(baseName)) {
        nameCounts[baseName] = nameCounts[baseName]! + 1;
      } else {
        nameCounts[baseName] = 0;
      }

      final count = nameCounts[baseName]!;
      final username =
          count == 0 ? '${classCode}_$baseName' : '${classCode}_${baseName}$count';

      result.add({
        'full_name': fullName,
        'username': username,
      });
    }

    return result;
  }

  String _extractFirstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : fullName;
  }

  String _sanitizeName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  String _formatDisplayDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day/$month/$year';
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
                  Row(
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
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create Class',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a class and generate usernames for pupils.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 26),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Class Details',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildGlassField(
                              controller: classNameController,
                              hint: 'Enter class name',
                              icon: Icons.class_outlined,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Add Pupils',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildGlassField(
                                    controller: pupilNameController,
                                    hint: 'Enter pupil full name',
                                    icon: Icons.person_outline,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: addPupil,
                                  child: Container(
                                    height: 56,
                                    width: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7F5AF0),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (pupils.isNotEmpty)
                              Text(
                                'Pupil List',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 10),
                            ...List.generate(
                              pupils.length,
                              (index) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pupils[index],
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => removePupil(index),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7F5AF0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _isSaving ? null : createClass,
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
                                        'Create Class',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
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

  Widget _buildGlassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.20),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Colors.white70,
            width: 1.4,
          ),
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