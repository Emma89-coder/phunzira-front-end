// main.dart
import 'package:flutter/material.dart';
import 'package:phunzira/screens/registration_screen.dart';
import 'screens/login_screen.dart';
import 'screens/learner_dashboard.dart';
import 'screens/forgot_password_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learning Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const LearnerDashboard(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
      },
    );
  }
}