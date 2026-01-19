import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'models/models.dart';
import 'screen_time_blocker_method_channel.dart';

/// The interface that implementations of screen_time_blocker must implement.
///
/// Platform implementations should extend this class rather than implement it
/// as `screen_time_blocker` does not consider newly added methods to be breaking
/// changes. Extending this class ensures that the subclass will get the default
/// implementation, while platform implementations that merely implement the
/// interface will be broken by newly added methods.
abstract class ScreenTimeBlockerPlatform extends PlatformInterface {
  /// Constructs a ScreenTimeBlockerPlatform.
  ScreenTimeBlockerPlatform() : super(token: _token);

  static final Object _token = Object();

  static ScreenTimeBlockerPlatform _instance = MethodChannelScreenTimeBlocker();

  /// The default instance of [ScreenTimeBlockerPlatform] to use.
  ///
  /// Defaults to [MethodChannelScreenTimeBlocker].
  static ScreenTimeBlockerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ScreenTimeBlockerPlatform] when
  /// they register themselves.
  static set instance(ScreenTimeBlockerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Requests authorization to use Screen Time features.
  ///
  /// Returns `true` if authorization was granted, `false` otherwise.
  /// Throws [UnsupportedError] on platforms that don't support this feature.
  Future<bool> requestAuthorization() {
    throw UnimplementedError(
      'requestAuthorization() has not been implemented.',
    );
  }

  /// Checks if the app is authorized to use Screen Time features.
  ///
  /// Returns the current [AuthorizationStatus].
  Future<AuthorizationStatus> getAuthorizationStatus() {
    throw UnimplementedError(
      'getAuthorizationStatus() has not been implemented.',
    );
  }

  /// Opens the native app/category picker for selecting items to block.
  ///
  /// Returns a [SelectionSummary] with the selected items count.
  Future<SelectionSummary> selectAppsToBlock() {
    throw UnimplementedError('selectAppsToBlock() has not been implemented.');
  }

  /// Gets the current selection summary without opening the picker.
  Future<SelectionSummary> getSelectionSummary() {
    throw UnimplementedError('getSelectionSummary() has not been implemented.');
  }

  /// Starts monitoring and blocking based on the schedule.
  ///
  /// [hour] and [minute] specify when blocking should start daily.
  /// Returns `true` if the schedule was started successfully.
  Future<bool> startSchedule({
    required String scheduleId,
    required int hour,
    required int minute,
  }) {
    throw UnimplementedError('startSchedule() has not been implemented.');
  }

  /// Stops a specific schedule by its ID.
  Future<bool> stopSchedule(String scheduleId) {
    throw UnimplementedError('stopSchedule() has not been implemented.');
  }

  /// Stops the current monitoring schedule and removes all blocks.
  Future<bool> stopAllSchedules();

  /// Temporarily unblocks apps until the next scheduled time.
  ///
  /// The schedule remains active and will re-block at the next interval.
  Future<bool> unblockUntilNextSchedule() {
    throw UnimplementedError('unblockUntilNextSchedule() has not been implemented.');
  }

  /// Immediately blocks the selected apps without waiting for schedule.
  Future<bool> blockNow() {
    throw UnimplementedError('blockNow() has not been implemented.');
  }

  /// Gets the list of installed apps that can be blocked (Android only).
  ///
  /// Returns a list of [AppInfo] objects containing app details.
  /// On iOS, this returns an empty list as iOS uses the native Family Activity Picker.
  Future<List<AppInfo>> getInstalledApps() {
    throw UnimplementedError('getInstalledApps() has not been implemented.');
  }

  /// Sets the apps to be blocked (Android only).
  ///
  /// [packageNames] is a list of package names to block.
  /// On iOS, this does nothing as iOS uses the native Family Activity Picker.
  Future<bool> setSelectedApps(List<String> packageNames) {
    throw UnimplementedError('setSelectedApps() has not been implemented.');
  }

  /// Checks if the app has overlay permission (Android only).
  ///
  /// This permission is required to show the blocking overlay on Android.
  /// On iOS, this always returns true.
  Future<bool> hasOverlayPermission() {
    throw UnimplementedError('hasOverlayPermission() has not been implemented.');
  }

  /// Requests overlay permission (Android only).
  ///
  /// Opens the system settings to grant "Display over other apps" permission.
  /// On iOS, this does nothing and returns true.
  Future<bool> requestOverlayPermission() {
    throw UnimplementedError('requestOverlayPermission() has not been implemented.');
  }

  /// Checks if this platform supports Screen Time blocking.
  bool get isSupported;
}
