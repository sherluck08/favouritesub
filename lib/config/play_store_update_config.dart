enum PlayStoreUpdateMode { flexible, immediate, automatic }

class PlayStoreUpdateConfig {
  static const bool enabled = bool.fromEnvironment(
    'PLAY_IN_APP_UPDATE_ENABLED',
    defaultValue: true,
  );
  static const String _modeValue = String.fromEnvironment(
    'PLAY_IN_APP_UPDATE_MODE',
    defaultValue: 'flexible',
  );
  static const int immediatePriorityThreshold = int.fromEnvironment(
    'PLAY_IN_APP_UPDATE_IMMEDIATE_PRIORITY',
    defaultValue: 5,
  );
  static const int immediateStalenessDaysThreshold = int.fromEnvironment(
    'PLAY_IN_APP_UPDATE_IMMEDIATE_STALENESS_DAYS',
    defaultValue: 7,
  );

  static PlayStoreUpdateMode get mode => switch (_modeValue.toLowerCase()) {
    'immediate' || 'force' || 'forced' => PlayStoreUpdateMode.immediate,
    'automatic' || 'auto' => PlayStoreUpdateMode.automatic,
    _ => PlayStoreUpdateMode.flexible,
  };
}
