import 'package:favouritesub/config/play_store_update_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';

class PlayStoreUpdateService {
  PlayStoreUpdateService._();
  static final PlayStoreUpdateService instance = PlayStoreUpdateService._();
  bool _isChecking = false;

  Future<void> checkForUpdate({ScaffoldMessengerState? messenger}) async {
    if (!PlayStoreUpdateConfig.enabled ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _isChecking) {
      return;
    }
    _isChecking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress &&
          info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      final mode = _mode(info);
      if (mode == PlayStoreUpdateMode.immediate &&
          info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          messenger?.showSnackBar(
            SnackBar(
              content: const Text('Update downloaded. Restart to install it.'),
              duration: const Duration(seconds: 12),
              action: SnackBarAction(
                label: 'Restart',
                onPressed: InAppUpdate.completeFlexibleUpdate,
              ),
            ),
          );
        }
      } else if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } on PlatformException catch (error) {
      if (kDebugMode) debugPrint('Play update unavailable: ${error.code}');
    } catch (error) {
      if (kDebugMode) debugPrint('Play update check failed: $error');
    } finally {
      _isChecking = false;
    }
  }

  PlayStoreUpdateMode _mode(AppUpdateInfo info) {
    if (PlayStoreUpdateConfig.mode != PlayStoreUpdateMode.automatic) {
      return PlayStoreUpdateConfig.mode;
    }
    final stale =
        info.clientVersionStalenessDays != null &&
        info.clientVersionStalenessDays! >=
            PlayStoreUpdateConfig.immediateStalenessDaysThreshold;
    final priority =
        info.updatePriority >= PlayStoreUpdateConfig.immediatePriorityThreshold;
    return (stale || priority) && info.immediateUpdateAllowed
        ? PlayStoreUpdateMode.immediate
        : PlayStoreUpdateMode.flexible;
  }
}
