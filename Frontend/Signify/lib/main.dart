import 'package:flutter/material.dart';
import 'app.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.init();
  runApp(const MyApp());
}