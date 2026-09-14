import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(const StoreHubApp());
}

class StoreHubApp extends StatelessWidget {
  const StoreHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StoreHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
