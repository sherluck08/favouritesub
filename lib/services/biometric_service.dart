import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// What the device can do with biometrics right now.
enum BiometricAvailability {
  /// Hardware present, biometric enrolled, ready to authenticate.
  available,

  /// Hardware present but the user hasn't enrolled a fingerprint/face yet.
  notEnrolled,

  /// Device doesn't have biometric hardware (or it's disabled at the OS level).
  notSupported,

  /// Too many failed attempts; the OS has temporarily blocked biometric auth.
  lockedOut,

  /// Anything we couldn't classify.
  unknown,
}

/// Outcome of an authentication attempt.
enum BiometricOutcome { success, failed, cancelled, notAvailable, error }

class BiometricResult {
  final BiometricOutcome outcome;
  final String? message;
  const BiometricResult(this.outcome, {this.message});

  bool get success => outcome == BiometricOutcome.success;
  bool get cancelled => outcome == BiometricOutcome.cancelled;
}

/// Single source of truth for all biometric interactions.
///
/// - [check] caches the device capability for the session (cheap on every call).
/// - [authenticate] returns a typed result so the UI can show appropriate messaging.
/// - [authenticateWithFeedback] is a convenience wrapper that surfaces a snackbar
///   on failure/unavailability — useful where a screen doesn't want to handle UX itself.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static BiometricAvailability? _cached;

  /// Cached capability check. Pass [forceRefresh] after the user enrols a
  /// fingerprint in OS settings (or after a [BiometricOutcome.notAvailable]
  /// result) so we re-query the platform.
  static Future<BiometricAvailability> check({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cached != null) return _cached!;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return _cached = BiometricAvailability.notSupported;

      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return _cached = BiometricAvailability.notSupported;

      final types = await _auth.getAvailableBiometrics();
      if (types.isEmpty) return _cached = BiometricAvailability.notEnrolled;

      return _cached = BiometricAvailability.available;
    } on PlatformException catch (e) {
      switch (e.code) {
        case auth_error.notAvailable:
          return _cached = BiometricAvailability.notSupported;
        case auth_error.notEnrolled:
          return _cached = BiometricAvailability.notEnrolled;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return _cached = BiometricAvailability.lockedOut;
        default:
          return _cached = BiometricAvailability.unknown;
      }
    } catch (_) {
      return _cached = BiometricAvailability.unknown;
    }
  }

  /// Friendly user-facing message for a capability state. Safe for snackbars,
  /// dialogs, or bottom sheets.
  static String messageFor(BiometricAvailability state) {
    switch (state) {
      case BiometricAvailability.available:
        return 'Place your finger on the sensor or look at the camera.';
      case BiometricAvailability.notEnrolled:
        return "No fingerprint or face is set up on this device. Add one in your phone's Settings to use biometric sign in or confirm transactions.";
      case BiometricAvailability.notSupported:
        return "Your device doesn't support biometric authentication.";
      case BiometricAvailability.lockedOut:
        return 'Biometric authentication is temporarily locked. Use your device passcode or try again shortly.';
      case BiometricAvailability.unknown:
        return "We couldn't access biometric authentication. Please try again.";
    }
  }

  /// Title used in the friendly bottom sheet/dialog.
  static String titleFor(BiometricAvailability state) {
    switch (state) {
      case BiometricAvailability.notEnrolled:
        return 'Set up fingerprint first';
      case BiometricAvailability.notSupported:
        return 'Not supported on this device';
      case BiometricAvailability.lockedOut:
        return 'Biometric is locked';
      default:
        return 'Biometric unavailable';
    }
  }

  /// Authenticate with biometrics. Always check capability first — if not
  /// available, returns [BiometricOutcome.notAvailable] with a friendly message
  /// (no platform dialog is shown, so the caller can present their own UI).
  static Future<BiometricResult> tryAuthenticate({
    String reason = 'Confirm it’s you to continue',
    bool biometricOnly = true,
  }) async {
    final state = await check();
    if (state != BiometricAvailability.available) {
      return BiometricResult(
        BiometricOutcome.notAvailable,
        message: messageFor(state),
      );
    }
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (ok) return const BiometricResult(BiometricOutcome.success);
      return const BiometricResult(
        BiometricOutcome.cancelled,
        message: 'Authentication cancelled',
      );
    } on PlatformException catch (e) {
      // The OS state may have changed (e.g. user removed fingerprint),
      // so invalidate our cache and re-check.
      _cached = null;
      switch (e.code) {
        case auth_error.notAvailable:
        case auth_error.notEnrolled:
          final fresh = await check(forceRefresh: true);
          return BiometricResult(
            BiometricOutcome.notAvailable,
            message: messageFor(fresh),
          );
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return BiometricResult(
            BiometricOutcome.notAvailable,
            message: messageFor(BiometricAvailability.lockedOut),
          );
        default:
          return BiometricResult(
            BiometricOutcome.error,
            message: 'Biometric error: ${e.message ?? e.code}',
          );
      }
    } catch (_) {
      return const BiometricResult(
        BiometricOutcome.error,
        message: "Biometric error. Please try again.",
      );
    }
  }

  /// Backwards-compatible wrapper used by existing call sites.
  /// Returns `true` on success; on failure or unavailability shows a friendly
  /// snackbar via [context] and returns `false`.
  static Future<bool> authenticate(
    BuildContext context, {
    String reason = 'Confirm it’s you to continue',
    bool biometricOnly = true,
  }) async {
    final result = await tryAuthenticate(
      reason: reason,
      biometricOnly: biometricOnly,
    );
    if (result.success) return true;
    if (context.mounted && result.message != null && !result.cancelled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message!)));
    }
    return false;
  }
}
