import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'smart_quiz_preview_screen.dart';

class ManualQuizScreen extends StatefulWidget {
  const ManualQuizScreen({super.key});

  @override
  State<ManualQuizScreen> createState() => _ManualQuizScreenState();
}

class _ManualQuizScreenState extends State<ManualQuizScreen> {
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';

  final supabase = Supabase.instance.client;

  bool _isLoadingInitialData = true;
  bool _isGenerating = false;

  List<dynamic> _classes = [];
  List<String> _subjects = [];
  List<String> _topics = [];
  List<String> _subtopics = [];

  String? _selectedClassId;
  String? _selectedClassLabel;
  String? _selectedSubject;
  String? _selectedTopic;
  String? _selectedSubtopic;
  String _difficulty = 'medium';
  int _numberOfQuestions = 5;
  int? _timeLimitMinutes;
  DateTime? _availableFrom;
  DateTime? _deadlineAt;

  final TextEditingController _titleController = TextEditingController();
  final List<TextEditingController> _questionControllers = [];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _questionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoadingInitialData = true);

    try {
      await Future.wait([
        _fetchClasses(),
        _fetchSubjects(),
      ]);
      _resetQuestionControllers(_numberOfQuestions);
    } finally {
      if (mounted) {
        setState(() => _isLoadingInitialData = false);
      }
    }
  }

  Future<void> _fetchClasses() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('classes')
        .select('id, class_name')
        .eq('teacher_id', user.id)
        .order('class_name', ascending: true);

    _classes = response;
  }

  Future<void> _fetchSubjects() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/curriculum-subjects'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _subjects = List<String>.from(data['subjects'] ?? []);
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load subjects.');
      }
    } catch (e) {
      _showSnack('Error loading subjects: $e');
    }
  }

  Future<void> _fetchTopics(String subject) async {
    setState(() {
      _topics = [];
      _subtopics = [];
      _selectedTopic = null;
      _selectedSubtopic = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/curriculum-topics?subject=${Uri.encodeComponent(subject)}'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _topics = List<String>.from(data['topics'] ?? []);
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load topics.');
      }
    } catch (e) {
      _showSnack('Error loading topics: $e');
    }
  }

  Future<void> _fetchSubtopics(String subject, String topic) async {
    setState(() {
      _subtopics = [];
      _selectedSubtopic = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/curriculum-subtopics?subject=${Uri.encodeComponent(subject)}&topic=${Uri.encodeComponent(topic)}',
        ),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _subtopics = List<String>.from(data['subtopics'] ?? []);
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load subtopics.');
      }
    } catch (e) {
      _showSnack('Error loading subtopics: $e');
    }
  }

  void _resetQuestionControllers(int count) {
    for (final controller in _questionControllers) {
      controller.dispose();
    }
    _questionControllers.clear();

    for (int i = 0; i < count; i++) {
      _questionControllers.add(TextEditingController());
    }

    setState(() {});
  }

  Future<void> _pickAvailableFrom() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _availableFrom ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null) return;

    if (!mounted) return;

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
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null) return;

    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _deadlineAt ?? now.add(const Duration(hours: 1)),
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

  Future<void> _generateManualDraft() async {
    if (_selectedClassId == null) {
      _showSnack('Please select a class.');
      return;
    }
    if (_selectedSubject == null || _selectedTopic == null || _selectedSubtopic == null) {
      _showSnack('Please select subject, topic and subtopic.');
      return;
    }
    if (_deadlineAt == null) {
      _showSnack('Please select a deadline.');
      return;
    }

    final typedQuestions = _questionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (typedQuestions.length != _numberOfQuestions) {
      _showSnack(
        'Please type exactly $_numberOfQuestions questions before generating.',
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      _showSnack('Teacher session not found.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final payload = {
        'teacher_id': user.id,
        'class_id': _selectedClassId,
        'subject': _selectedSubject,
        'topic': _selectedTopic,
        'subtopic': _selectedSubtopic,
        'difficulty': _difficulty,
        'number_of_questions': _numberOfQuestions,
        'time_limit_minutes': _timeLimitMinutes,
        'available_from': (_availableFrom ?? DateTime.now()).toUtc().toIso8601String(),
        'deadline_at': _deadlineAt!.toUtc().toIso8601String(),
        'leaderboard_size': 5,
        'title': _titleController.text.trim().isEmpty
            ? '${_selectedSubject!} - ${_selectedTopic!} - Manual Quiz'
            : _titleController.text.trim(),
        'questions': typedQuestions
            .asMap()
            .entries
            .map(
              (entry) => {
                'order_index': entry.key + 1,
                'question_text': entry.value,
              },
            )
            .toList(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/generate-manual-quiz-draft'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;

        _showSuccessDialog(
          quizId: (data['quiz_id'] ?? '').toString(),
          quizTitle: (data['quiz_title'] ?? '').toString(),
          status: (data['status'] ?? 'draft').toString(),
          totalQuestions: (data['total_questions'] ?? 0).toString(),
        );
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to generate manual draft.');
      }
    } catch (e) {
      _showSnack('Error generating manual draft: $e');
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
          style: GoogleFonts.poppins(
            color: Colors.white70,
            height: 1.5,
          ),
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

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Not selected';
    return '${value.day}/${value.month}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white70),
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

  Widget _buildDropdownCard<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF1C3444),
          isExpanded: true,
          iconEnabledColor: Colors.white,
          style: GoogleFonts.poppins(color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final numberOptions = [3, 4, 5, 6, 8, 10];
    final durationOptions = <int?>[null, 5, 10, 15, 20, 30, 45, 60];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11212D),
        elevation: 0,
        title: Text(
          'Create Manual Quiz',
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
            child: _isLoadingInitialData
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
                              'Manual Quiz Setup',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _titleController,
                              label: 'Quiz Title (optional)',
                              icon: Icons.title,
                            ),
                            const SizedBox(height: 14),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
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
                                  style: GoogleFonts.poppins(color: Colors.white),
                                  hint: Text(
                                    'Select Class',
                                    style: GoogleFonts.poppins(color: Colors.white54),
                                  ),
                                  items: _classes.map<DropdownMenuItem<String>>((c) {
                                    return DropdownMenuItem<String>(
                                      value: c['id'].toString(),
                                      child: Text(
                                        c['class_name'].toString(),
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? value) {
                                    if (value == null) return;

                                    final selected = _classes.firstWhere(
                                      (c) => c['id'].toString() == value,
                                      orElse: () => <String, dynamic>{},
                                    );

                                    setState(() {
                                      _selectedClassId = value;
                                      _selectedClassLabel = selected['class_name']?.toString() ?? '';
                                    });
                                  },
                                ),
                              ),
                            ),

                            if (_selectedClassLabel != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Class: $_selectedClassLabel',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 14),

                            _buildDropdownCard<String>(
                              label: 'Select Subject',
                              icon: Icons.menu_book_outlined,
                              value: _selectedSubject,
                              items: _subjects
                                  .map(
                                    (s) => DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(
                                        s,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) async {
                                if (value == null) return;
                                setState(() {
                                  _selectedSubject = value;
                                });
                                await _fetchTopics(value);
                              },
                            ),

                            const SizedBox(height: 14),

                            _buildDropdownCard<String>(
                              label: 'Select Topic',
                              icon: Icons.topic_outlined,
                              value: _selectedTopic,
                              items: _topics
                                  .map(
                                    (t) => DropdownMenuItem<String>(
                                      value: t,
                                      child: Text(
                                        t,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) async {
                                if (value == null || _selectedSubject == null) return;
                                setState(() {
                                  _selectedTopic = value;
                                });
                                await _fetchSubtopics(_selectedSubject!, value);
                              },
                            ),

                            const SizedBox(height: 14),

                            _buildDropdownCard<String>(
                              label: 'Select Subtopic',
                              icon: Icons.list_alt_outlined,
                              value: _selectedSubtopic,
                              items: _subtopics
                                  .map(
                                    (s) => DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(
                                        s,
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSubtopic = value;
                                });
                              },
                            ),

                            const SizedBox(height: 14),

                            _buildDropdownCard<String>(
                              label: 'Difficulty',
                              icon: Icons.speed_outlined,
                              value: _difficulty,
                              items: ['easy', 'medium', 'hard']
                                  .map(
                                    (d) => DropdownMenuItem<String>(
                                      value: d,
                                      child: Text(
                                        d[0].toUpperCase() + d.substring(1),
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _difficulty = value;
                                });
                              },
                            ),

                            const SizedBox(height: 14),

                            _buildDropdownCard<int>(
                              label: 'Number of Questions',
                              icon: Icons.format_list_numbered_outlined,
                              value: _numberOfQuestions,
                              items: numberOptions
                                  .map(
                                    (n) => DropdownMenuItem<int>(
                                      value: n,
                                      child: Text(
                                        n.toString(),
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                _numberOfQuestions = value;
                                _resetQuestionControllers(value);
                              },
                            ),

                            const SizedBox(height: 14),

                            _buildDropdownCard<int?>(
                              label: 'Time Limit',
                              icon: Icons.timer_outlined,
                              value: _timeLimitMinutes,
                              items: durationOptions
                                  .map(
                                    (minutes) => DropdownMenuItem<int?>(
                                      value: minutes,
                                      child: Text(
                                        minutes == null
                                            ? 'No time limit'
                                            : '$minutes minutes',
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _timeLimitMinutes = value;
                                });
                              },
                            ),

                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _pickAvailableFrom,
                                    icon: const Icon(Icons.calendar_today_outlined),
                                    label: Text(
                                      'Available From',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF10222F),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDateTime(_availableFrom),
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),

                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _pickDeadline,
                                    icon: const Icon(Icons.event_busy_outlined),
                                    label: Text(
                                      'Deadline',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyanAccent,
                                      foregroundColor: const Color(0xFF10222F),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDateTime(_deadlineAt),
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'Type Your Questions',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ..._questionControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final controller = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _glassCard(
                            child: _buildTextField(
                              controller: controller,
                              label: 'Question ${index + 1}',
                              icon: Icons.help_outline,
                              minLines: 2,
                              maxLines: 4,
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isGenerating ? null : _generateManualDraft,
                          icon: _isGenerating
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFF10222F),
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(
                            _isGenerating
                                ? 'Generating...'
                                : 'Generate Answers & Save Draft',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: const Color(0xFF10222F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}