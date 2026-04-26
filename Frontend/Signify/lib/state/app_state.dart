import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));
  static final ValueNotifier<double> textScaleNotifier = ValueNotifier(1.0);
  static final ValueNotifier<bool> highContrastNotifier = ValueNotifier(false);

  // Auth State
  static final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier(false);
  static SharedPreferences? prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    
    // Load Settings
    final savedTheme = prefs?.getString('themeMode') ?? 'light';
    themeNotifier.value = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    
    final savedLocale = prefs?.getString('locale') ?? 'en';
    localeNotifier.value = Locale(savedLocale);
    
    highContrastNotifier.value = prefs?.getBool('highContrast') ?? false;
    textScaleNotifier.value = prefs?.getDouble('textScale') ?? 1.0;

    // Load Auth state
    isLoggedInNotifier.value = prefs?.getBool('isLoggedIn') ?? false;
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    await prefs?.setString('themeMode', mode == ThemeMode.dark ? 'dark' : 'light');
  }

  static Future<void> setLocale(Locale locale) async {
    localeNotifier.value = locale;
    await prefs?.setString('locale', locale.languageCode);
  }

  static Future<void> setHighContrast(bool value) async {
    highContrastNotifier.value = value;
    await prefs?.setBool('highContrast', value);
  }

  static Future<void> setTextScale(double value) async {
    textScaleNotifier.value = value;
    await prefs?.setDouble('textScale', value);
  }

  static Future<void> login(String email, String password) async {
    final registeredEmail = prefs?.getString('user_email');
    final registeredPassword = prefs?.getString('user_password');

    if (registeredEmail == null || registeredPassword == null) {
      throw Exception('User not found. Please register first.');
    }

    if (registeredEmail == email && registeredPassword == password) {
      isLoggedInNotifier.value = true;
      await prefs?.setBool('isLoggedIn', true);
    } else {
      throw Exception('Invalid credentials.');
    }
  }

  static Future<void> register(String name, String email, String password) async {
    await prefs?.setString('user_name', name);
    await prefs?.setString('user_email', email);
    await prefs?.setString('user_password', password);
    
    // Auto-login after registration
    isLoggedInNotifier.value = true;
    await prefs?.setBool('isLoggedIn', true);
  }

  static Future<void> logout() async {
    isLoggedInNotifier.value = false;
    await prefs?.setBool('isLoggedIn', false);
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'app_title': 'Signify',
      'settings': 'Settings',
      'profile': 'Profile',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'accessibility': 'Accessibility Settings',
      'logout': 'Logout',
      'start_camera': 'Start Camera',
      'stop_camera': 'Stop Camera',
      'start_gesture': 'Start Gesture',
      'stop_gesture': 'Stop Gesture',
      'emergency': 'Emergency',
      'welcome_back': 'Welcome Back',
      'login': 'Login',
      'signup': 'Sign Up',
      'create_account': 'Create Account',
      'edit_profile': 'Edit Profile',
      'save': 'Save',
      'name': 'Full Name',
      'email': 'Email',
      'password': 'Password',
      'high_contrast': 'High Contrast Mode',
      'text_size': 'Text Size',
      'preferences': 'Preferences',
    },
    'hi': {
      'app_title': 'सिग्निफाई',
      'settings': 'सेटिंग्स',
      'profile': 'प्रोफ़ाइल',
      'dark_mode': 'डार्क मोड',
      'language': 'भाषा',
      'accessibility': 'एक्सेसिबिलिटी सेटिंग्स',
      'logout': 'लॉग आउट',
      'start_camera': 'कैमरा शुरू करें',
      'stop_camera': 'कैमरा बंद करें',
      'start_gesture': 'जेस्चर शुरू करें',
      'stop_gesture': 'जेस्चर बंद करें',
      'emergency': 'आपातकाल',
      'welcome_back': 'वापसी पर स्वागत है',
      'login': 'लॉगिन',
      'signup': 'साइन अप',
      'create_account': 'खाता बनाएँ',
      'edit_profile': 'प्रोफ़ाइल संपादित करें',
      'save': 'सहेजें',
      'name': 'पूरा नाम',
      'email': 'ईमेल',
      'password': 'पासवर्ड',
      'high_contrast': 'हाई कंट्रास्ट मोड',
      'text_size': 'टेक्स्ट का आकार',
      'preferences': 'प्राथमिकताएं',
    }
  };

  static String getString(String key) {
    return _translations[localeNotifier.value.languageCode]?[key] ?? 
           _translations['en']?[key] ?? key;
  }
}
