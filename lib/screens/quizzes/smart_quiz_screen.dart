// ======================================================
// smart_quiz_screen.dart
//
// PURPOSE:
// Allow teachers to generate AI-assisted quizzes
// based on curriculum content.
//
// MAIN LOGIC:
//
// Initialisation
// - Load teacher classes
// - Load curriculum subjects, topics and subtopics
//
// Database Operations
//
// READ → classes
// - Retrieve teacher classes
//
// READ → curriculum_items
// - Retrieve subjects
// - Retrieve topics
// - Retrieve subtopics
//
// Backend Operations
//
// WRITE → Supabase Edge Function
// - generate-smart-quiz
// - Generate quiz draft using OpenAI
//
// Quiz Configuration
// - Select class and curriculum content
// - Select difficulty and question type
// - Select number of questions
// - Configure time limit and availability
//
// AI Rules
// - Restrict generation using curriculum
// - Support single, multiple or all subtopics
// - Generate quiz as draft before publishing
//
// Navigation
// - Open draft preview screen
//
// Utilities
// - Generate automatic quiz title
// - Validate inputs
// - Format date and time
//
// ======================================================
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'smart_quiz_preview_screen.dart';

class SmartQuizScreen extends StatefulWidget {
  const SmartQuizScreen({super.key});

  @override
  State<SmartQuizScreen> createState() => _SmartQuizScreenState();
}
// Supabase client used for database and authentication.
class _SmartQuizScreenState extends State<SmartQuizScreen> {
  static final supabase = Supabase.instance.client;
  // Base URL for Supabase Edge Functions.
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';
  // Loading states for screen and quiz generation.
  bool _isLoading = true;
  bool _isGenerating = false;
  // Data loaded from curriculum and teacher classes.
  List<Map<String, dynamic>> _classes = [];
  List<String> _subjects = [];
  List<String> _topics = [];
  List<String> _subtopics = [];
  // Selected quiz configuration values.
  String? _selectedClassId;

  String? _selectedSubject;
  String? _selectedTopic;

  String _subtopicMode = 'single'; // single | multiple | all
  String? _selectedSingleSubtopic;
  List<String> _selectedMultipleSubtopics = [];

  String _difficulty = 'medium';
  String? _questionType;
  int _numberOfQuestions = 5;
  int? _timeLimitMinutes; // null = no time limit

  DateTime? _availableFrom;
  DateTime? _deadlineAt;
  // Optional custom quiz title.
  final TextEditingController _titleController = TextEditingController();
  // Initialise default dates and load screen data.
  @override
  void initState() {
    super.initState();
    _availableFrom = DateTime.now();
    _deadlineAt = DateTime.now().add(const Duration(days: 1));
    _loadInitialData();
  }
  // Release controller resources.
  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
  // Load teacher classes and curriculum subjects.
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadTeacherClasses(),
        _loadSubjects(),
      ]);
    } catch (e) {
      _showSnack('Failed to load data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // Load classes created by current teacher.
  Future<void> _loadTeacherClasses() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // If your table/column names differ, adjust here only.
    final response = await supabase
        .from('classes')
        .select('id, class_name')
        .eq('teacher_id', user.id)
        .order('class_name');

    _classes = List<Map<String, dynamic>>.from(response);

    if (_classes.isNotEmpty) {
      _selectedClassId = _classes.first['id']?.toString();
    }
  }
  // Load available subjects from curriculum.
  Future<void> _loadSubjects() async {
    final response = await supabase
        .from('curriculum_items')
        .select('subject')
        .eq('is_active', true)
        .order('subject');

    final values = response
        .map((e) => (e['subject'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    _subjects = values;

    if (_subjects.isNotEmpty) {
      _selectedSubject = _subjects.first;
      await _loadTopicsForSubject(_selectedSubject!);
    }
  }
  // Load topics when subject changes.
  Future<void> _loadTopicsForSubject(String subject) async {
    final response = await supabase
        .from('curriculum_items')
        .select('topic')
        .eq('subject', subject)
        .eq('is_active', true)
        .order('topic');

    final values = response
        .map((e) => (e['topic'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    // Reset topic and subtopic selections.
    setState(() {
      _topics = values;
      _selectedTopic = _topics.isNotEmpty ? _topics.first : null;
      _subtopics = [];
      _selectedSingleSubtopic = null;
      _selectedMultipleSubtopics = [];
      _questionType = _defaultQuestionTypeForSubject(subject);
    });

    if (_selectedTopic != null) {
      await _loadSubtopicsForTopic(subject, _selectedTopic!);
    }
  }
  // Load subtopics for selected topic.
  Future<void> _loadSubtopicsForTopic(String subject, String topic) async {
    final response = await supabase
        .from('curriculum_items')
        .select('subtopic')
        .eq('subject', subject)
        .eq('topic', topic)
        .eq('is_active', true)
        .order('subtopic');

    final values = response
        .map((e) => (e['subtopic'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _subtopics = values;
      _selectedSingleSubtopic = _subtopics.isNotEmpty ? _subtopics.first : null;
      _selectedMultipleSubtopics = [];
    });
  }
  // Set recommended question type per subject.
  String _defaultQuestionTypeForSubject(String subject) {
    final s = subject.toLowerCase();

    if (s == 'mathematics') return 'mixed';
    if (s == 'english') return 'mcq';
    if (s == 'french') return 'mcq';
    if (s == 'history') return 'mixed';
    if (s == 'geography') return 'mixed';

    return 'mixed';
  }

  List<String> _questionTypesForSubject(String? subject) {
    final s = (subject ?? '').toLowerCase();

    if (s == 'mathematics') return ['mcq', 'true_false', 'mixed'];
    if (s == 'english') return ['mcq', 'fill_blank'];
    if (s == 'french') return ['mcq', 'fill_blank'];
    if (s == 'history') return ['mcq', 'true_false', 'fill_blank', 'mixed'];
    if (s == 'geography') return ['mcq', 'true_false', 'fill_blank', 'mixed'];

    return ['mcq', 'true_false', 'fill_blank', 'mixed'];
  }
  // Select quiz availability date and time.
  Future<void> _pickAvailableFrom() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _availableFrom ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_availableFrom ?? now),
    );

    if (pickedTime == null) return;

    setState(() {
      _availableFrom = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadlineAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _deadlineAt ?? now.add(const Duration(days: 1)),
      ),
    );

    if (pickedTime == null) return;

    setState(() {
      _deadlineAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }
  // Validate inputs and generate draft quiz using AI.
  Future<void> _generateDraftQuiz() async {
    if (_selectedClassId == null) {
      _showSnack('Please select a class.');
      return;
    }

    if (_selectedSubject == null || _selectedTopic == null) {
      _showSnack('Please select subject and topic.');
      return;
    }

    if (_deadlineAt == null) {
      _showSnack('Please select a deadline.');
      return;
    }

    if (_subtopicMode == 'single' && _selectedSingleSubtopic == null) {
      _showSnack('Please select a subtopic.');
      return;
    }

    if (_subtopicMode == 'multiple' && _selectedMultipleSubtopics.isEmpty) {
      _showSnack('Please select at least one subtopic.');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      _showSnack('Teacher session not found.');
      return;
    }

    setState(() => _isGenerating = true);
    // Prepare data sent to Edge Function.
    try {
      final payload = <String, dynamic>{
        'teacher_id': user.id,
        'class_id': _selectedClassId,
        'subject': _selectedSubject,
        'topic': _selectedTopic,
        'difficulty': _difficulty,
        'question_type': _questionType,
        'number_of_questions': _numberOfQuestions,
        'time_limit_minutes': _timeLimitMinutes,
        'available_from': (_availableFrom ?? DateTime.now()).toUtc().toIso8601String(),
        'deadline_at': _deadlineAt!.toUtc().toIso8601String(),
        'leaderboard_size': 5,
        'title': _titleController.text.trim().isEmpty
            ? _buildDefaultTitle()
            : _titleController.text.trim(),
      };

      if (_subtopicMode == 'single') {
        payload['subtopic'] = _selectedSingleSubtopic;
      } else if (_subtopicMode == 'multiple') {
        payload['selected_subtopics'] = _selectedMultipleSubtopics;
      } else if (_subtopicMode == 'all') {
        payload['all_subtopics'] = true;
      }
      // Send request to Supabase Edge Function.
      final response = await http.post(
        Uri.parse('$baseUrl/generate-smart-quiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);
      // Open draft preview after successful generation.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        // Show generated draft information.
        _showSuccessDialog(
          quizId: (data['quiz_id'] ?? '').toString(),
          quizTitle: (data['quiz_title'] ?? '').toString(),
          status: (data['status'] ?? 'draft').toString(),
          totalQuestions: (data['total_questions'] ?? 0).toString(),
        );
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to generate draft quiz.');
      }
    } catch (e) {
      _showSnack('Error generating draft quiz: $e');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
  void _showSuccessDialog({
    required String quizId,
    required String quizTitle,
    required String status,
    required String totalQuestions,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B3344),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Draft Created',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Quiz title: $quizTitle\n'
          'Quiz ID: $quizId\n'
          'Status: $status\n'
          'Questions: $totalQuestions\n\n'
          'Do you want to preview and edit this draft now?',
          style: GoogleFonts.poppins(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Later',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SmartQuizPreviewScreen(quizId: quizId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: const Color(0xFF10222F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Open Draft',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  // Create automatic quiz title if empty.
  String _buildDefaultTitle() {
    if (_subtopicMode == 'single' && _selectedSingleSubtopic != null) {
      return '${_selectedSubject ?? ''} - ${_selectedSingleSubtopic!}';
    }
    if (_subtopicMode == 'multiple') {
      return '${_selectedSubject ?? ''} - Multiple Subtopics';
    }
    return '${_selectedSubject ?? ''} - All Subtopics';
  }
  // Display messages to teacher.
  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  // Convert DateTime into readable format.
  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Not selected';
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  ${two(dt.hour)}:${two(dt.minute)}';
  }
  // Build smart quiz configuration interface.
  @override
  Widget build(BuildContext context) {
    // Ensure selected question type remains valid.
    final questionTypeOptions = _questionTypesForSubject(_selectedSubject);

    if (_questionType == null || !questionTypeOptions.contains(_questionType)) {
      _questionType = questionTypeOptions.first;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11212D),
        elevation: 0,
        title: Text(
          'Create Smart Quiz',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quiz setup section.
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quiz Setup',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Choose class, subject, topic, subtopic mode, and quiz settings.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildTextField(
                                controller: _titleController,
                                label: 'Quiz Title (optional)',
                                hint: 'Example: Numbers Revision Quiz',
                                icon: Icons.title,
                              ),
                              const SizedBox(height: 14),
                              _buildDropdownCard(
                                label: 'Class',
                                icon: Icons.groups_2_outlined,
                                value: _selectedClassId,
                                items: _classes
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c['id'].toString(),
                                        child: Text(c['class_name'].toString()),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedClassId = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdownCard(
                                label: 'Subject',
                                icon: Icons.menu_book_outlined,
                                value: _selectedSubject,
                                items: _subjects
                                    .map(
                                      (s) => DropdownMenuItem<String>(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) async {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedSubject = value;
                                    _selectedTopic = null;
                                    _subtopics = [];
                                    _selectedSingleSubtopic = null;
                                    _selectedMultipleSubtopics = [];
                                    _subtopicMode = 'single';
                                    _questionType =
                                        _defaultQuestionTypeForSubject(value);
                                  });
                                  await _loadTopicsForSubject(value);
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdownCard(
                                label: 'Topic',
                                icon: Icons.topic_outlined,
                                value: _selectedTopic,
                                items: _topics
                                    .map(
                                      (t) => DropdownMenuItem<String>(
                                        value: t,
                                        child: Text(t),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) async {
                                  if (value == null || _selectedSubject == null) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedTopic = value;
                                    _selectedSingleSubtopic = null;
                                    _selectedMultipleSubtopics = [];
                                    _subtopics = [];
                                  });
                                  await _loadSubtopicsForTopic(
                                    _selectedSubject!,
                                    value,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subtopic selection section.
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subtopic Selection',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildRadioTile(
                                title: 'One subtopic',
                                value: 'single',
                              ),
                              _buildRadioTile(
                                title: 'Selected subtopics',
                                value: 'multiple',
                              ),
                              _buildRadioTile(
                                title: 'All subtopics in this topic',
                                value: 'all',
                              ),
                              const SizedBox(height: 12),
                              if (_subtopicMode == 'single')
                                _buildDropdownCard(
                                  label: 'Subtopic',
                                  icon: Icons.list_alt_outlined,
                                  value: _selectedSingleSubtopic,
                                  items: _subtopics
                                      .map(
                                        (s) => DropdownMenuItem<String>(
                                          value: s,
                                          child: Text(s),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSingleSubtopic = value;
                                    });
                                  },
                                ),
                              if (_subtopicMode == 'multiple')
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _subtopics.map((sub) {
                                    final isSelected = _selectedMultipleSubtopics.contains(sub);

                                    return FilterChip(
                                      label: Text(
                                        sub,
                                        style: GoogleFonts.poppins(
                                          color: isSelected ? const Color(0xFF10222F) : Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedMultipleSubtopics.add(sub);
                                          } else {
                                            _selectedMultipleSubtopics.remove(sub);
                                          }
                                        });
                                      },
                                      backgroundColor: const Color(0xFF274457), // darker when unselected
                                      selectedColor: Colors.cyanAccent,
                                      disabledColor: const Color(0xFF274457),
                                      checkmarkColor: const Color(0xFF10222F),
                                      side: BorderSide(
                                        color: isSelected ? Colors.cyanAccent : Colors.white24,
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    );
                                  }).toList(),
                                ),
                              if (_subtopicMode == 'all')
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white24,
                                    ),
                                  ),
                                  child: Text(
                                    _subtopics.isEmpty
                                        ? 'No subtopics found for this topic.'
                                        : 'All ${_subtopics.length} subtopics from this topic will be used.',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Quiz generation options.
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quiz Options',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildDropdownCard(
                                label: 'Difficulty',
                                icon: Icons.speed_outlined,
                                value: _difficulty,
                                items: const [
                                  DropdownMenuItem(value: 'easy', child: Text('easy')),
                                  DropdownMenuItem(value: 'medium', child: Text('medium')),
                                  DropdownMenuItem(value: 'hard', child: Text('hard')),
                                  DropdownMenuItem(value: 'mixed', child: Text('mixed')),
                                ],
                                onChanged: (value) {
                                  setState(() => _difficulty = value ?? 'medium');
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdownCard(
                                label: 'Question Type',
                                icon: Icons.rule_folder_outlined,
                                value: _questionType,
                                items: questionTypeOptions
                                    .map(
                                      (q) => DropdownMenuItem<String>(
                                        value: q,
                                        child: Text(q),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _questionType = value);
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdownCard(
                                label: 'Number of Questions',
                                icon: Icons.format_list_numbered_outlined,
                                value: _numberOfQuestions.toString(),
                                items: List.generate(
                                  15,
                                  (index) => DropdownMenuItem<String>(
                                    value: '${index + 1}',
                                    child: Text('${index + 1}'),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _numberOfQuestions =
                                        int.tryParse(value ?? '5') ?? 5;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdownCard(
                                label: 'Time Limit',
                                icon: Icons.timer_outlined,
                                value: _timeLimitMinutes == null
                                    ? 'none'
                                    : _timeLimitMinutes.toString(),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'none',
                                    child: Text('No time limit'),
                                  ),
                                  DropdownMenuItem(value: '5', child: Text('5 minutes')),
                                  DropdownMenuItem(value: '10', child: Text('10 minutes')),
                                  DropdownMenuItem(value: '15', child: Text('15 minutes')),
                                  DropdownMenuItem(value: '20', child: Text('20 minutes')),
                                  DropdownMenuItem(value: '30', child: Text('30 minutes')),
                                  DropdownMenuItem(value: '45', child: Text('45 minutes')),
                                  DropdownMenuItem(value: '60', child: Text('60 minutes')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _timeLimitMinutes =
                                        value == 'none' ? null : int.tryParse(value ?? '');
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Availability',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _dateButton(
                                icon: Icons.schedule_outlined,
                                title: 'Available From',
                                value: _formatDateTime(_availableFrom),
                                onTap: _pickAvailableFrom,
                              ),
                              const SizedBox(height: 12),
                              _dateButton(
                                icon: Icons.event_available_outlined,
                                title: 'Deadline',
                                value: _formatDateTime(_deadlineAt),
                                onTap: _pickDeadline,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          // Generate AI draft quiz.
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _generateDraftQuiz,
                            icon: _isGenerating
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFF10222F),
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_outlined),
                            label: Text(
                              _isGenerating ? 'Generating Draft...' : 'Generate Draft Quiz',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: const Color(0xFF10222F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 0,
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(color: Colors.white70),
        hintStyle: GoogleFonts.poppins(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.cyanAccent),
        ),
      ),
    );
  }

  Widget _buildDropdownCard({
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: const Color(0xFF1C3444),
          isExpanded: true,
          value: items.any((e) => e.value == value) ? value : null,
          iconEnabledColor: Colors.white,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          hint: Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white54),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String value,
  }) {
    return RadioListTile<String>(
      value: value,
      groupValue: _subtopicMode,
      activeColor: Colors.cyanAccent,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: GoogleFonts.poppins(color: Colors.white),
      ),
      onChanged: (val) {
        setState(() {
          _subtopicMode = val ?? 'single';
        });
      },
    );
  }

  Widget _dateButton({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.cyanAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar, color: Colors.white70),
          ],
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