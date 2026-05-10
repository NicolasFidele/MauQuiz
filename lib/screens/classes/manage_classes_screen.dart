import 'dart:convert';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/supabase_service.dart';
import 'add_pupil_screen.dart';

class ManageClassesScreen extends StatefulWidget {
  const ManageClassesScreen({super.key});

  @override
  State<ManageClassesScreen> createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _classes = [];

  // static const String _defaultPin = '1234';

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final teacher = supabase.auth.currentUser;

    if (teacher == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final classesResponse = await supabase
          .from('classes')
          .select()
          .eq('teacher_id', teacher.id)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> loadedClasses = [];

      for (final item in classesResponse) {
        final classMap = Map<String, dynamic>.from(item);

        final pupilsResponse = await supabase
            .from('pupils')
            .select()
            .eq('class_id', classMap['id'])
            .order('created_at', ascending: true);

        classMap['pupils'] = List<Map<String, dynamic>>.from(pupilsResponse);
        loadedClasses.add(classMap);
      }

      if (!mounted) return;
      setState(() {
        _classes = loadedClasses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load classes: $e')),
      );
    }
  }

  Future<void> _openAddPupilScreen(Map<String, dynamic> classItem) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPupilScreen(
          classId: classItem['id'],
          classCode: classItem['class_code'],
          className: classItem['class_name'],
        ),
      ),
    );

    if (result == true) {
      await _loadClasses();
    }
  }

  Future<void> _confirmDeletePupil(Map<String, dynamic> pupil) async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Pupil',
      message:
          'Are you sure you want to delete ${pupil['full_name']} from this class?',
    );

    if (!confirmed) return;

    try {
      await supabase.from('pupils').delete().eq('id', pupil['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pupil deleted successfully')),
      );

      await _loadClasses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete pupil: $e')),
      );
    }
  }

  Future<void> _confirmDeleteClass(Map<String, dynamic> classItem) async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Class',
      message:
          'Are you sure you want to delete "${classItem['class_name']}"? This will also remove all pupils in this class.',
    );

    if (!confirmed) return;

    try {
      await supabase.from('classes').delete().eq('id', classItem['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class deleted successfully')),
      );

      await _loadClasses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete class: $e')),
      );
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F3442),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  String _formatDisplayDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '-';

    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();

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
            child: Padding(
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
                    'Manage Classes',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add or remove pupils, or delete a class.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : _classes.isEmpty
                            ? Center(
                                child: Text(
                                  'No classes found.',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 15,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadClasses,
                                child: ListView.builder(
                                  itemCount: _classes.length,
                                  itemBuilder: (context, index) {
                                    final classItem = _classes[index];
                                    final pupils = List<Map<String, dynamic>>.from(
                                      classItem['pupils'] ?? const [],
                                    );

                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 12,
                                          sigmaY: 12,
                                        ),
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 16),
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.10),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border:
                                                Border.all(color: Colors.white30),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      classItem['class_name'] ?? '',
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: _isSaving
                                                        ? null
                                                        : () => _confirmDeleteClass(
                                                            classItem),
                                                    child: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.redAccent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Class Code: ${classItem['class_code'] ?? '-'}',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white70,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Created On: ${_formatDisplayDate(classItem['created_at']?.toString())}',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white70,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Pupils',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  TextButton.icon(
                                                    onPressed: _isSaving
                                                        ? null
                                                        : () => _openAddPupilScreen(
                                                            classItem),
                                                    icon: const Icon(
                                                      Icons.add,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                    label: Text(
                                                      'Add Pupil',
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              if (pupils.isEmpty)
                                                Text(
                                                  'No pupils in this class.',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white60,
                                                    fontSize: 13,
                                                  ),
                                                )
                                              else
                                                ...pupils.map(
                                                  (pupil) => Container(
                                                    margin: const EdgeInsets.only(
                                                      bottom: 10,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.08),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              14),
                                                      border: Border.all(
                                                        color: Colors.white24,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                pupil['full_name'] ??
                                                                    '',
                                                                style: GoogleFonts
                                                                    .poppins(
                                                                  color:
                                                                      Colors.white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(
                                                                'Username: ${pupil['username'] ?? ''}',
                                                                style: GoogleFonts
                                                                    .poppins(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        InkWell(
                                                          onTap: _isSaving
                                                              ? null
                                                              : () =>
                                                                  _confirmDeletePupil(
                                                                    pupil,
                                                                  ),
                                                          child: const Icon(
                                                            Icons.delete_outline,
                                                            color:
                                                                Colors.redAccent,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
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