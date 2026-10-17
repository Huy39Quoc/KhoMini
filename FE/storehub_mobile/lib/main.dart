import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/network/http_client.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/session_gate.dart';
import 'models/user_model.dart';
import 'core/constants/api_endpoints.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'vi';
  await initializeDateFormatting('vi');
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('custom_api_base_url');
  if (savedUrl != null && savedUrl.isNotEmpty) {
    try {
      HttpClient.instance.updateBaseUrl(savedUrl);
    } on FormatException {
      await prefs.remove('custom_api_base_url');
    } on StateError {
      await prefs.remove('custom_api_base_url');
    }
  }
  ApiEndpoints.validateReleaseConfiguration();
  final links = AppLinks();
  runApp(StoreHubApp(incomingLinks: links.uriLinkStream));
}

class StoreHubApp extends StatefulWidget {
  final Future<UserModel?> Function()? restoreSession;
  final Stream<Uri>? incomingLinks;

  const StoreHubApp({super.key, this.restoreSession, this.incomingLinks});

  @override
  State<StoreHubApp> createState() => _StoreHubAppState();
}

class _StoreHubAppState extends State<StoreHubApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linksSubscription;

  @override
  void initState() {
    super.initState();
    _linksSubscription =
        widget.incomingLinks?.listen(_onLink, onError: (Object _) {});
  }

  void _onLink(Uri uri) {
    if (uri.scheme != 'storehub' || uri.host != 'reset-password') return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => LoginScreen(initialResetToken: token)),
        (_) => false,
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _linksSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'StoreHub',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: SessionGate(restoreSession: widget.restoreSession),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
