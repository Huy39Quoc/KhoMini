import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_api_service.dart';
import '../common/role_dispatch_screen.dart';
import 'login_screen.dart';

class SessionGate extends StatefulWidget {
  final Future<UserModel?> Function()? restoreSession;

  const SessionGate({super.key, this.restoreSession});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late Future<UserModel?> _session;

  @override
  void initState() {
    super.initState();
    _session = _restore();
  }

  Future<UserModel?> _restore() =>
      (widget.restoreSession ?? AuthApiService().restoreSession)();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not restore your session. Check your connection.'),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _session = _restore();
                      });
                    },
                    child: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('Sign in with another account'),
                  ),
                ],
              ),
            ),
          );
        }
        final user = snapshot.data;
        return user == null
            ? const LoginScreen()
            : RoleDispatchScreen(user: user);
      },
    );
  }
}
