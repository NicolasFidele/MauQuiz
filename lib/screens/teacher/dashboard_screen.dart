// Dashboard screen
// This screen is the main landing page after teacher login.
// It displays the logged-in teacher email, dashboard sections, and logout options.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get Supabase client and the current logged-in teacher.
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // Show the teacher email if it exists.
    final email = user?.email ?? 'No email';

    return Scaffold(
      // Side menu for dashboard navigation.
      drawer: Drawer(
        backgroundColor: const Color(0xFF1B2A41),
        child: SafeArea(
          child: Column(
            children: [
              // Drawer header showing teacher account information.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1E3C72),
                      Color(0xFF2A5298),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      child: Icon(Icons.person),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Welcome',
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Temporary drawer items for future navigation.
              _drawerItem('Item 1'),
              _drawerItem('Item 2'),
              _drawerItem('Item 3'),
              _drawerItem('Item 4'),
              _drawerItem('Item 5'),

              const Spacer(),

              // Logout from Supabase and return to login screen.
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: Text(
                  'Logout',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                onTap: () async {
                  await supabase.auth.signOut();

                  if (!context.mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // Main dashboard content.
      body: Stack(
        children: [
          // Dashboard background.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
            ),
          ),

          SafeArea(
            // Builder is used so the menu button can open the drawer.
            child: Builder(
              builder: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar with drawer button and user icon.
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),
                        const Spacer(),
                        const Icon(Icons.person, color: Colors.white),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Dashboard title.
                    Text(
                      'Dashboard',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Welcome back',
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),

                    // Display current teacher email.
                    Text(
                      email,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Placeholder area for future dashboard information.
                    _glassBox('Container 1'),

                    const SizedBox(height: 20),

                    // Section for quick dashboard actions.
                    Text(
                      'Quick Section',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Temporary action cards.
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: const [
                        DashboardCard(title: 'Button 1'),
                        DashboardCard(title: 'Button 2'),
                        DashboardCard(title: 'Button 3'),
                        DashboardCard(title: 'Button 4'),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Additional placeholder sections.
                    _glassBox('Container 2'),

                    const SizedBox(height: 20),

                    _glassBox('Container 3'),

                    const SizedBox(height: 25),

                    // Logout button for the teacher account.
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          await supabase.auth.signOut();

                          if (!context.mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text('Logout'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reusable drawer item widget.
  static Widget _drawerItem(String title) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.poppins(color: Colors.white),
      ),
      onTap: () {},
    );
  }

  // Reusable glass-style container for dashboard sections.
  static Widget _glassBox(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// Reusable dashboard card.
// It is used to display shortcut buttons on the dashboard.
class DashboardCard extends StatelessWidget {
  final String title;

  const DashboardCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    // Glass-style card used for quick dashboard actions.
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: Text(
            title,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      ),
    );
  }
}