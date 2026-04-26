import 'package:flutter/material.dart';
import 'Screens/splash_screen.dart';
import 'Screens/login_screen.dart';
import 'Screens/signup_screen.dart';
import 'Screens/home_screen.dart';
import 'Screens/emergency_sos_screen.dart';
import 'Screens/user_profile_screen.dart';
import 'Screens/settings_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F5DC), // Soft beige
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Colors.green[700]!,
          secondary: Colors.brown[600]!,
          surface: const Color(0xFFF5F5DC),
        ),
        fontFamily: 'Inter', // Default readable font if available, or fallback
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/sos': (context) => const EmergencySosScreen(),
        '/profile': (context) => const UserProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
