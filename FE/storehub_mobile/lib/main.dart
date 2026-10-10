import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/session_gate.dart';
import 'models/user_model.dart';

void main() {
  runApp(const StoreHubApp());
}

class StoreHubApp extends StatelessWidget {
  final Future<UserModel?> Function()? restoreSession;

  const StoreHubApp({super.key, this.restoreSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StoreHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SessionGate(restoreSession: restoreSession),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
