import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';

bool isSessionExpiredError(Object error) {
  final message = error.toString().toLowerCase();
  final mentionsToken =
      message.contains('token') ||
      message.contains('credential') ||
      message.contains('authentication');
  final isInvalid =
      message.contains('expired') ||
      message.contains('invalid') ||
      message.contains('not valid') ||
      message.contains('unauthorized') ||
      message.contains('401') ||
      message.contains('403');

  return message.contains('no access token') ||
      message.contains('session expired') ||
      (mentionsToken && isInvalid);
}

bool isSessionRefreshFailure(String? message) {
  if (message == null || message.trim().isEmpty) return false;
  final lower = message.toLowerCase();
  return lower.contains('token refresh failed') ||
      lower.contains('invalid token refresh response') ||
      lower.contains('no saved session') ||
      isSessionExpiredError(Exception(message));
}

Future<void> logoutToLogin(BuildContext context) async {
  final auth = Provider.of<AuthProvider>(context, listen: false);
  await auth.logout();
  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
