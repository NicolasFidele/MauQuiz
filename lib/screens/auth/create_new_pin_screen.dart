// ======================================================
// create_new_pin_screen.dart
//
// PURPOSE:
// Allows a pupil to create a new PIN during first login.
//
// MAIN FEATURES:
// - Validate new 4-digit PIN
// - Confirm both PIN entries match
// - Hash PIN using SHA-256
// - Update pupil PIN in database
// - Force pupil to return to login after PIN update
//
// DATABASE:
//
// WRITE:
// - pupils
//   → Update pin_hash
//   → Set must_change_pin to false
//
// API:
// No external API calls
//
// NAVIGATION:
//
// Opens:
// - LoginScreen after successful PIN creation
//
// ======================================================
import 'dart:convert';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/supabase_service.dart';
import 'login_screen.dart';

class CreateNewPinScreen extends StatefulWidget {
  final String pupilId;
  final String fullName;
  final String username;

  const CreateNewPinScreen({
    super.key,
    required this.pupilId,
    required this.fullName,
    required this.username,
  });

  @override
  State<CreateNewPinScreen> createState() => _CreateNewPinScreenState();
}
// Controllers used to read PIN input fields.
class _CreateNewPinScreenState extends State<CreateNewPinScreen> {
  final pinController = TextEditingController();
  final confirmPinController = TextEditingController();
  // State used while saving the new PIN.
  bool _isSaving = false;
  bool _hidePin = true;
  bool _hideConfirmPin = true;
  // Release text controllers when screen closes.
  @override
  void dispose() {
    pinController.dispose();
    confirmPinController.dispose();
    super.dispose();
  }
  // Hash the PIN before saving it in the database.
  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }
  // Validate PIN, save hashed PIN, and update pupil login status.
  Future<void> _saveNewPin() async {
    final pin = pinController.text.trim();
    final confirmPin = confirmPinController.text.trim();
    // Check that PIN contains exactly 4 digits.
    if (pin.length != 4 || int.tryParse(pin) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be exactly 4 digits')),
      );
      return;
    }

    if (pin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });
    // WRITE to pupils table
    // Save hashed PIN and disable first-login PIN reset.
    try {
      final updatedRows = await supabase
          .from('pupils')
          .update({
            'pin_hash': _hashPin(pin),
            'must_change_pin': false,
          })
          .eq('id', widget.pupilId)
          .select();

      if (!mounted) return;

      if (updatedRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN was not updated. Please check permissions.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated successfully. Please log in.')),
      );
      // Return pupil to login after successful PIN creation.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PIN: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  // Build new PIN creation screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Positioned(
            top: -50,
            left: -30,
            child: _buildCircle(160, Colors.cyanAccent.withOpacity(0.08)),
          ),
          Positioned(
            top: 120,
            right: -40,
            child: _buildCircle(140, Colors.blueAccent.withOpacity(0.08)),
          ),
          Positioned(
            bottom: -60,
            left: 20,
            child: _buildCircle(200, Colors.yellowAccent.withOpacity(0.08)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: 400,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Create Your PIN',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This is your first login. Please create a new 4-digit PIN.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _buildField(
                            controller: pinController,
                            hint: 'Enter new 4-digit PIN',
                            hideValue: _hidePin,
                            onToggleVisibility: () {
                              setState(() {
                                _hidePin = !_hidePin;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: confirmPinController,
                            hint: 'Confirm new PIN',
                            hideValue: _hideConfirmPin,
                            onToggleVisibility: () {
                              setState(() {
                                _hideConfirmPin = !_hideConfirmPin;
                              });
                            },
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
                              onPressed: _isSaving ? null : _saveNewPin,
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
                                      'Save PIN',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // Reusable PIN input field.
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required bool hideValue,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: hideValue,
      maxLength: 4,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white),
        suffixIcon: IconButton(
          icon: Icon(
            hideValue ? Icons.visibility_off : Icons.visibility,
            color: Colors.white,
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white70),
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