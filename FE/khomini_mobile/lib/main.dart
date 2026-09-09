import 'package:flutter/material.dart';

import 'screens/customer/reservation/facility_detail_screen.dart';

void main() {
  runApp(const KhoMiniApp());
}

class KhoMiniApp extends StatelessWidget {
  const KhoMiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KhoMini',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
      home: const FacilityDetailScreen(),
    );
  }
}
