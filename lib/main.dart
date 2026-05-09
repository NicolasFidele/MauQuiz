import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://celzxcaciqjayubgwoxp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNlbHp4Y2FjaXFqYXl1Ymd3b3hwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNzQxMzMsImV4cCI6MjA4OTk1MDEzM30.pnErnxrSGGDWHtjswEbDax8XhdAEiiMtqGdkqtCN41M',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart EduQuiz',
      home: const LoginScreen(),
    );
  }
}