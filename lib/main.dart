import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';

// Application entry point.
void main() async {
  // Prepare Flutter before loading backend services.
  WidgetsFlutterBinding.ensureInitialized();
  // Connect the app to Supabase backend.
  await Supabase.initialize(
    // Supabase project URL and anon key
    url: 'https://celzxcaciqjayubgwoxp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNlbHp4Y2FjaXFqYXl1Ymd3b3hwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNzQxMzMsImV4cCI6MjA4OTk1MDEzM30.pnErnxrSGGDWHtjswEbDax8XhdAEiiMtqGdkqtCN41M',
  );
  // Launch the application.
  runApp(const MyApp());
}
// Root widget of the application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // Configure global application settings.
  @override
  Widget build(BuildContext context) {
    // Define application structure.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MauQuiz', //application name
      home: const LoginScreen(), // Open login screen when app starts.
    );
  }
}