import 'package:flutter/material.dart';
import 'state/app_state.dart';
import 'Screens/splash_screen.dart';
import 'Screens/login_screen.dart';
import 'Screens/signup_screen.dart';
import 'Screens/home_screen.dart';
import 'Screens/user_profile_screen.dart';
import 'Screens/settings_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.themeNotifier,
      builder: (_, ThemeMode currentTheme, __) {
        return ValueListenableBuilder<Locale>(
          valueListenable: AppState.localeNotifier,
          builder: (_, Locale currentLocale, __) {
            return ValueListenableBuilder<double>(
              valueListenable: AppState.textScaleNotifier,
              builder: (_, double textScale, __) {
                return ValueListenableBuilder<bool>(
                  valueListenable: AppState.highContrastNotifier,
                  builder: (_, bool highContrast, __) {
                    return MaterialApp(
                      title: AppState.getString('app_title'),
                      debugShowCheckedModeBanner: false,
                      themeMode: currentTheme,
                      theme: ThemeData(
                        scaffoldBackgroundColor: highContrast ? Colors.white : const Color(0xFFF5F5DC),
                        colorScheme: ColorScheme.fromSeed(
                          seedColor: Colors.green,
                          primary: highContrast ? Colors.black : Colors.green[700]!,
                          secondary: highContrast ? Colors.black : Colors.brown[600]!,
                          surface: highContrast ? Colors.white : const Color(0xFFF5F5DC),
                        ),
                        fontFamily: 'Inter',
                        useMaterial3: true,
                      ),
                      darkTheme: ThemeData.dark().copyWith(
                        scaffoldBackgroundColor: highContrast ? Colors.black : const Color(0xFF121212),
                        colorScheme: ColorScheme.fromSeed(
                          seedColor: Colors.green,
                          brightness: Brightness.dark,
                          primary: highContrast ? Colors.white : Colors.green[300]!,
                          secondary: highContrast ? Colors.white : Colors.brown[300]!,
                          surface: highContrast ? Colors.black : const Color(0xFF121212),
                        ),
                        useMaterial3: true,
                      ),
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                          child: child!,
                        );
                      },
                      initialRoute: '/splash',
                      routes: {
                        '/splash': (context) => const SplashScreen(),
                        '/login': (context) => const LoginScreen(),
                        '/signup': (context) => const SignupScreen(),
                        '/home': (context) => const HomeScreen(),
                        '/profile': (context) => const UserProfileScreen(),
                        '/settings': (context) => const SettingsScreen(),
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
