import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class SmartQuizPreviewScreen extends StatefulWidget {
  final String quizId;

  const SmartQuizPreviewScreen({
    super.key,
    required this.quizId,
  });

  @override
  State<SmartQuizPreviewScreen> createState() => _SmartQuizPreviewScreenState();
}

class _SmartQuizPreviewScreenState extends State<SmartQuizPreviewScreen> {
  static const String baseUrl =
    'https://celzxcaciqjayubgwoxp.supabase.co/functions/v1';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPublishing = false;

  Map<String, dynamic>? _quiz;
  List<QuestionEditorModel> _questions = [];

  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDraftQuiz();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchDraftQuiz() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher-quiz-detail?quizId=${widget.quizId}'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final quiz = Map<String, dynamic>.from(data['quiz'] ?? {});
        final questionsRaw = List<Map<String, dynamic>>.from(
          (data['questions'] ?? []).map((e) => Map<String, dynamic>.from(e)),
        );

        final loadedQuestions =
            questionsRaw.map((q) => QuestionEditorModel.fromMap(q)).toList();

        setState(() {
          _quiz = quiz;
          _questions = loadedQuestions;
          _titleController.text = (_quiz?['title'] ?? '').toString();
        });
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to load quiz.');
      }
    } catch (e) {
      _showSnack('Error loading quiz: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _isSaving = true);

    try {
      final payload = {
        'title': _titleController.text.trim(),
        'questions': _questions.map((q) => q.toUpdateMap()).toList(),
      };

      final response = await http.put(
        Uri.parse('$baseUrl/teacher-update-quiz?quizId=${widget.quizId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnack(data['message']?.toString() ?? 'Draft saved successfully');
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to save draft.');
      }
    } catch (e) {
      _showSnack('Error saving draft: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _publishQuiz() async {
    final confirmed = await _showPublishConfirmDialog();
    if (!confirmed) return;

    setState(() => _isPublishing = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher-publish-quiz?quizId=${widget.quizId}'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Quiz published successfully',
            ),
          ),
        );

        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showSnack(data['error']?.toString() ?? 'Failed to publish quiz.');
      }
    } catch (e) {
      _showSnack('Error publishing quiz: $e');
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  Future<bool> _showPublishConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B3344),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Publish Quiz?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Once published, this quiz will no longer be editable.',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: const Color(0xFF10222F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Publish',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _toggleCorrectOption(QuestionEditorModel question, int selectedIndex) {
    for (int i = 0; i < question.options.length; i++) {
      question.options[i].isCorrect = i == selectedIndex;
    }

    if (question.questionType == 'mcq' || question.questionType == 'true_false') {
      final correct = question.options.firstWhere(
        (o) => o.isCorrect,
        orElse: () => question.options.first,
      );
      question.correctAnswerController.text =
          correct.optionTextController.text;
    }

    setState(() {});
  }

  void _syncCorrectAnswerFromOptions(QuestionEditorModel question) {
    if (question.questionType == 'mcq' ||
        question.questionType == 'true_false') {
      final correct = question.options.where((o) => o.isCorrect).toList();
      if (correct.isNotEmpty) {
        question.correctAnswerController.text =
            correct.first.optionTextController.text;
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _safeText(dynamic value) => value?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final quizStatus = _safeText(_quiz?['status']);
    final isEditable = quizStatus == 'draft';

    final quizSubject = _safeText(_quiz?['subject']);
    final quizTopic = _safeText(_quiz?['topic']);
    final quizSubtopic = _safeText(_quiz?['subtopic']);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11212D),
        elevation: 0,
        title: Text(
          'Preview Smart Quiz',
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
                        if (!isEditable)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.45),
                              ),
                            ),
                            child: Text(
                              'This quiz is published and cannot be edited.',
                              style: GoogleFonts.poppins(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quiz Details',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: _titleController,
                                label: 'Quiz Title',
                                icon: Icons.title,
                                isEditable: isEditable,
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _infoChip('Status', quizStatus),
                                  _infoChip('Subject', quizSubject),
                                  _infoChip('Topic', quizTopic),
                                  _infoChip('Subtopic', quizSubtopic),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Questions',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._questions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final question = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _questionCard(
                              index + 1,
                              question,
                              isEditable,
                            ),
                          );
                        }),
                        const SizedBox(height: 18),
                        if (isEditable)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSaving ? null : _saveDraft,
                                    icon: _isSaving
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Color(0xFF10222F),
                                            ),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: Text(
                                      _isSaving ? 'Saving...' : 'Save Draft',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF10222F),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _isPublishing ? null : _publishQuiz,
                                    icon: _isPublishing
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Color(0xFF10222F),
                                            ),
                                          )
                                        : const Icon(Icons.send_outlined),
                                    label: Text(
                                      _isPublishing
                                          ? 'Publishing...'
                                          : 'Publish Quiz',
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
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(
    int displayNumber,
    QuestionEditorModel question,
    bool isEditable,
  ) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniLabel('Q$displayNumber'),
              _miniLabel(question.questionType.toUpperCase()),
              if (question.sourceSubtopic.isNotEmpty)
                _miniLabel(question.sourceSubtopic),
            ],
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: question.questionController,
            label: 'Question Text',
            icon: Icons.help_outline,
            minLines: 2,
            maxLines: 4,
            isEditable: isEditable,
          ),
          const SizedBox(height: 14),
          if (question.questionType == 'mcq' ||
              question.questionType == 'true_false') ...[
            Text(
              'Options',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            ...question.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Radio<int>(
                        value: index,
                        groupValue:
                            question.options.indexWhere((o) => o.isCorrect),
                        onChanged: isEditable
                            ? (val) {
                                if (val == null) return;
                                _toggleCorrectOption(question, val);
                              }
                            : null,
                        activeColor: Colors.cyanAccent,
                      ),
                      Expanded(
                        child: _buildTextField(
                          controller: option.optionTextController,
                          label: 'Option ${index + 1}',
                          icon: Icons.list,
                          minLines: 1,
                          maxLines: 2,
                          isEditable: isEditable,
                          onChanged: isEditable
                              ? (_) {
                                  _syncCorrectAnswerFromOptions(question);
                                  setState(() {});
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (question.questionType == 'fill_blank') ...[
            _buildTextField(
              controller: question.correctAnswerController,
              label: 'Correct Answer',
              icon: Icons.check_circle_outline,
              minLines: 1,
              maxLines: 2,
              isEditable: isEditable,
            ),
            const SizedBox(height: 14),
          ],
          if (question.questionType == 'mcq' ||
              question.questionType == 'true_false') ...[
            _buildTextField(
              controller: question.correctAnswerController,
              label: 'Correct Answer Text',
              icon: Icons.check_circle_outline,
              minLines: 1,
              maxLines: 2,
              isEditable: isEditable,
            ),
            const SizedBox(height: 14),
          ],
          _buildTextField(
            controller: question.explanationController,
            label: 'Explanation',
            icon: Icons.lightbulb_outline,
            minLines: 2,
            maxLines: 4,
            isEditable: isEditable,
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
    required IconData icon,
    required bool isEditable,
    int minLines = 1,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      enabled: isEditable,
      minLines: minLines,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white70),
        filled: true,
        fillColor: isEditable
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        disabledBorder: OutlineInputBorder(
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

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.poppins(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withOpacity(0.90),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: const Color(0xFF10222F),
          fontWeight: FontWeight.w600,
          fontSize: 12,
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

class QuestionEditorModel {
  final String id;
  final String questionType;
  final String sourceSubtopic;

  final TextEditingController questionController;
  final TextEditingController correctAnswerController;
  final TextEditingController explanationController;

  final List<OptionEditorModel> options;

  QuestionEditorModel({
    required this.id,
    required this.questionType,
    required this.sourceSubtopic,
    required this.questionController,
    required this.correctAnswerController,
    required this.explanationController,
    required this.options,
  });

  factory QuestionEditorModel.fromMap(Map<String, dynamic> map) {
    final optionsRaw = List<Map<String, dynamic>>.from(
      (map['options'] ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    return QuestionEditorModel(
      id: (map['id'] ?? '').toString(),
      questionType: (map['question_type'] ?? '').toString(),
      sourceSubtopic: (map['source_subtopic'] ?? '').toString(),
      questionController:
          TextEditingController(text: (map['question_text'] ?? '').toString()),
      correctAnswerController:
          TextEditingController(text: (map['correct_answer_text'] ?? '').toString()),
      explanationController:
          TextEditingController(text: (map['explanation'] ?? '').toString()),
      options: optionsRaw.map((o) => OptionEditorModel.fromMap(o)).toList(),
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'id': id,
      'question_text': questionController.text.trim(),
      'correct_answer_text': correctAnswerController.text.trim(),
      'explanation': explanationController.text.trim(),
      'options': options.map((o) => o.toUpdateMap()).toList(),
    };
  }

  void dispose() {
    questionController.dispose();
    correctAnswerController.dispose();
    explanationController.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

class OptionEditorModel {
  final String id;
  bool isCorrect;
  final TextEditingController optionTextController;

  OptionEditorModel({
    required this.id,
    required this.isCorrect,
    required this.optionTextController,
  });

  factory OptionEditorModel.fromMap(Map<String, dynamic> map) {
    return OptionEditorModel(
      id: (map['id'] ?? '').toString(),
      isCorrect: map['is_correct'] == true,
      optionTextController:
          TextEditingController(text: (map['option_text'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'id': id,
      'option_text': optionTextController.text.trim(),
      'is_correct': isCorrect,
    };
  }

  void dispose() {
    optionTextController.dispose();
  }
}