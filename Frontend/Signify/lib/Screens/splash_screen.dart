import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // App logo (hand gesture icon placeholder)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sign_language,
                  size: 60,
                  color: Colors.green[800],
                ),
              ),
              const SizedBox(height: 32),
              // App name
              const Text(
                'Signify',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'Gesture to Intent Translator',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.brown[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              // Hand illustration placeholder
              Icon(
                Icons.waving_hand_rounded,
                size: 80,
                color: Colors.brown[300],
              ),
              const Spacer(),
              // Button
              CustomButton(
                text: 'Start Communicating',
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
