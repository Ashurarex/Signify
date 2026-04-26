import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class AppState {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.light,
  );
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(
    const Locale('en'),
  );
  static final ValueNotifier<double> textScaleNotifier = ValueNotifier(1.0);
  static final ValueNotifier<bool> highContrastNotifier = ValueNotifier(false);
  static final ValueNotifier<List<Map<String, String>>> emergencyContactsNotifier = ValueNotifier([]);

  // Auth State
  static final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier(false);
  static SharedPreferences? prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();

    // Load Settings
    final savedTheme = prefs?.getString('themeMode') ?? 'light';
    themeNotifier.value = savedTheme == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;

    final savedLocale = prefs?.getString('locale') ?? 'en';
    localeNotifier.value = Locale(savedLocale);

    highContrastNotifier.value = prefs?.getBool('highContrast') ?? false;
    textScaleNotifier.value = prefs?.getDouble('textScale') ?? 1.0;

    // Load Auth state
    isLoggedInNotifier.value = prefs?.getBool('isLoggedIn') ?? false;

    // Load Emergency Contacts
    if (isLoggedInNotifier.value) {
      await _loadEmergencyContactsFromFirestore();
    } else {
      final contactsJson = prefs?.getString('emergencyContacts');
      if (contactsJson != null) {
        try {
          final List<dynamic> decoded = json.decode(contactsJson);
          emergencyContactsNotifier.value = decoded.map((e) => Map<String, String>.from(e)).toList();
        } catch (e) {
          debugPrint("Error loading emergency contacts: \$e");
        }
      }
    }
  }

  static Future<void> _loadEmergencyContactsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      emergencyContactsNotifier.value = [];
      return;
    }
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('emergencyContacts')) {
        final List<dynamic> contactsData = doc.data()!['emergencyContacts'];
        emergencyContactsNotifier.value = contactsData.map((e) => Map<String, String>.from(e as Map)).toList();
        // Sync local cache
        await prefs?.setString('emergencyContacts', json.encode(emergencyContactsNotifier.value));
      } else {
        emergencyContactsNotifier.value = [];
      }
    } catch (e) {
      debugPrint("Error loading contacts from Firestore: \$e");
      // Fallback to local cache
      final contactsJson = prefs?.getString('emergencyContacts');
      if (contactsJson != null) {
        final List<dynamic> decoded = json.decode(contactsJson);
        emergencyContactsNotifier.value = decoded.map((e) => Map<String, String>.from(e)).toList();
      }
    }
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    await prefs?.setString(
      'themeMode',
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
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

  static Future<void> saveEmergencyContacts(List<Map<String, String>> contacts) async {
    emergencyContactsNotifier.value = List.from(contacts);
    // create a new list reference so UI updates
    emergencyContactsNotifier.notifyListeners();
    
    // Save to local cache
    await prefs?.setString('emergencyContacts', json.encode(contacts));
    
    // Save to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'emergencyContacts': contacts,
        }, SetOptions(merge: true));
        debugPrint("Saved emergency contacts to Firestore for \${user.uid}");
      } catch (e) {
        debugPrint("Error saving contacts to Firestore: \$e");
      }
    }
  }

  static Future<void> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      
      final user = userCredential.user;
      if (user != null) {
        await prefs?.setString('user_name', user.displayName ?? 'User');
        await prefs?.setString('user_email', user.email ?? normalizedEmail);
        debugPrint("Logged in: ${user.displayName} / ${user.email}");
      }
      
      isLoggedInNotifier.value = true;
      await prefs?.setBool('isLoggedIn', true);
      await _loadEmergencyContactsFromFirestore();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No account found. Please register.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Incorrect password.');
      } else {
        throw Exception(e.message ?? 'Login failed. Please try again.');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }

  static Future<void> register(String name, String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(name);
      
      await prefs?.setString('user_name', name);
      await prefs?.setString('user_email', normalizedEmail);
      debugPrint("Registered: $name / $normalizedEmail");

      isLoggedInNotifier.value = true;
      await prefs?.setBool('isLoggedIn', true);
      emergencyContactsNotifier.value = [];
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('The account already exists for that email.');
      } else {
        throw Exception(e.message ?? 'Registration failed. Please try again.');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }

  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    isLoggedInNotifier.value = false;
    await prefs?.setBool('isLoggedIn', false);
    await prefs?.remove('user_name');
    await prefs?.remove('user_email');
    emergencyContactsNotifier.value = [];
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
    },
  };

  static String getString(String key) {
    return _translations[localeNotifier.value.languageCode]?[key] ??
        _translations['en']?[key] ??
        key;
  }
}
