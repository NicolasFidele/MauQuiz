import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SendAnnouncementScreen extends StatefulWidget {
  const SendAnnouncementScreen({super.key});

  @override
  State<SendAnnouncementScreen> createState() => _SendAnnouncementScreenState();
}

class _SendAnnouncementScreenState extends State<SendAnnouncementScreen> {
  final supabase = Supabase.instance.client;

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  bool _loading = true;
  bool _sending = false;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _announcements = [];

  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final classes = await supabase
          .from('classes')
          .select('id, class_name')
          .eq('teacher_id', user.id)
          .order('class_name');

      final announcements = await supabase
          .from('announcements')
          .select('id, title, message, class_id, created_at, classes(class_name)')
          .eq('teacher_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _classes = List<Map<String, dynamic>>.from(classes);
        _announcements = List<Map<String, dynamic>>.from(announcements);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showMessage('Error loading announcements: $e');
    }
  }

  Future<void> _sendAnnouncement() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final user = supabase.auth.currentUser;

    if (user == null) return;

    if (title.isEmpty || message.isEmpty) {
      _showMessage('Please enter a title and message.');
      return;
    }

    setState(() => _sending = true);

    try {
      await supabase.from('announcements').insert({
        'teacher_id': user.id,
        'class_id': _selectedClassId,
        'title': title,
        'message': message,
      });

      _titleController.clear();
      _messageController.clear();
      _selectedClassId = null;

      _showMessage('Announcement sent successfully.');
      await _loadData();
    } catch (e) {
      _showMessage('Error sending announcement: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    try {
      await supabase.from('announcements').delete().eq('id', id);
      _showMessage('Announcement deleted.');
      await _loadData();
    } catch (e) {
      _showMessage('Error deleting announcement: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _topBar(),
                        const SizedBox(height: 24),
                        _announcementForm(),
                        const SizedBox(height: 24),
                        _sectionTitle('Previous Announcements'),
                        const SizedBox(height: 12),
                        _announcementsList(),
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

  Widget _topBar() {
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
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Send Announcement',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _announcementForm() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Create Announcement'),
          const SizedBox(height: 14),

          _inputField(
            controller: _titleController,
            hint: 'Announcement title',
            icon: Icons.title,
          ),

          const SizedBox(height: 12),

          _messageField(),

          const SizedBox(height: 12),

          _classDropdown(),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _sendAnnouncement,
              icon: const Icon(Icons.campaign_outlined),
              label: Text(_sending ? 'Sending...' : 'Send Announcement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E5B7A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _classDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedClassId,
      dropdownColor: const Color(0xFF1D3A4A),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.groups_outlined, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white70),
        ),
      ),
      hint: Text(
        'Select class or send to all classes',
        style: GoogleFonts.poppins(color: Colors.white54),
      ),
      style: GoogleFonts.poppins(color: Colors.white),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'All classes',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
        ..._classes.map((classItem) {
          return DropdownMenuItem<String?>(
            value: classItem['id'],
            child: Text(
              classItem['class_name'],
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedClassId = value;
        });
      },
    );
  }

  Widget _announcementsList() {
    if (_announcements.isEmpty) {
      return _glassCard(
        child: Text(
          'No announcements sent yet.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }

    return Column(
      children: _announcements.map((announcement) {
        final classData = announcement['classes'];
        final className = classData == null ? 'All classes' : classData['class_name'];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        announcement['title'] ?? '',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteAnnouncement(announcement['id']),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  announcement['message'] ?? '',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$className • ${_formatDate(announcement['created_at'])}',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _messageField() {
    return TextField(
      controller: _messageController,
      maxLines: 5,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        alignLabelWithHint: true,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 80),
          child: Icon(Icons.message_outlined, color: Colors.white70),
        ),
        hintText: 'Write your announcement message...',
        hintStyle: GoogleFonts.poppins(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: padding,
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}