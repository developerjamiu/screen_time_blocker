import 'src/models/models.dart';
import 'src/screen_time_blocker_platform_interface.dart';

export 'src/models/models.dart';
export 'src/widgets/widgets.dart';

/// A Flutter plugin for blocking apps using iOS Screen Time API.
///
/// This plugin provides access to Apple's Screen Time and Family Controls
/// frameworks, allowing apps to block other applications until certain
/// conditions are met (e.g., completing a daily task).
///
/// ## Platform Support
///
/// | Platform | Supported |
/// |----------|-----------|
/// | iOS      | ✅ (15.0+) |
/// | Android  | 🚧 Planned |
/// | macOS    | ✅ (12.0+) |
/// | Web      | ❌         |
/// | Windows  | ❌         |
/// | Linux    | ❌         |
///
/// ## Setup Required
///
/// Before using this plugin, you must configure your iOS project with the
/// required entitlements and App Extensions. See the README for detailed
/// setup instructions.
///
/// ## Basic Usage
///
/// ```dart
/// final blocker = ScreenTimeBlocker();
///
/// // Request permission
/// final granted = await blocker.requestAuthorization();
///
/// // Let user select apps to block
/// final selection = await blocker.selectAppsToBlock();
///
/// // Start blocking at 9:00 AM daily
/// await blocker.startSchedule(hour: 9, minute: 0);
///
/// // When user completes their task, unblock for today
/// await blocker.unblockUntilNextSchedule();
/// ```
class ScreenTimeBlocker {
  /// Creates a new [ScreenTimeBlocker] instance.
  const ScreenTimeBlocker();

  static ScreenTimeBlockerPlatform get _platform =>
      ScreenTimeBlockerPlatform.instance;

  /// Whether the current platform supports Screen Time blocking.
  ///
  /// Returns `true` on iOS 15+ and macOS 12+, `false` otherwise.
  bool get isSupported => _platform.isSupported;

  /// Requests authorization to use Screen Time features.
  ///
  /// On iOS, this presents the system authorization dialog for Family Controls.
  /// The user must approve access for the app to block other applications.
  ///
  /// Returns `true` if authorization was granted, `false` if denied or if
  /// an error occurred.
  ///
  /// Throws [UnsupportedError] on platforms that don't support this feature.
  ///
  /// Example:
  /// ```dart
  /// final granted = await blocker.requestAuthorization();
  /// if (granted) {
  ///   // Proceed with app selection
  /// } else {
  ///   // Show explanation to user
  /// }
  /// ```
  Future<bool> requestAuthorization() => _platform.requestAuthorization();

  /// Gets the current authorization status.
  ///
  /// Use this to check if the user has already granted permission without
  /// prompting them again.
  ///
  /// Returns [AuthorizationStatus.approved] if previously authorized,
  /// [AuthorizationStatus.denied] if explicitly denied, or
  /// [AuthorizationStatus.notDetermined] if not yet asked.
  Future<AuthorizationStatus> getAuthorizationStatus() =>
      _platform.getAuthorizationStatus();

  /// Opens the native Family Activity Picker for selecting apps to block.
  ///
  /// This presents iOS's native UI for selecting individual apps, app
  /// categories, and web domains. The selection is persisted automatically.
  ///
  /// Returns a [SelectionSummary] containing counts of selected items.
  ///
  /// Note: Authorization must be granted before calling this method.
  ///
  /// Example:
  /// ```dart
  /// final selection = await blocker.selectAppsToBlock();
  /// print('Selected ${selection.apps} apps and ${selection.categories} categories');
  /// ```
  Future<SelectionSummary> selectAppsToBlock() => _platform.selectAppsToBlock();

  /// Gets the current selection summary without opening the picker.
  ///
  /// Use this to display the current selection state in your UI.
  Future<SelectionSummary> getSelectionSummary() =>
      _platform.getSelectionSummary();

  /// Starts the blocking schedule.
  ///
  /// Once started, selected apps will be blocked daily starting at the
  /// specified [hour] and [minute] until either:
  /// - [unblockUntilNextSchedule] is called
  /// - [stopSchedule] is called
  /// - The day ends (23:59)
  ///
  /// The schedule repeats daily until [stopSchedule] is called.
  ///
  /// Parameters:
  /// - [hour]: Hour in 24-hour format (0-23)
  /// - [minute]: Minute (0-59)
  ///
  /// Returns `true` if the schedule was started successfully.
  ///
  /// Throws [ArgumentError] if hour or minute are out of valid range.
  ///
  /// Example:
  /// ```dart
  /// // Block apps starting at 2:30 PM
  /// await blocker.startSchedule(hour: 14, minute: 30);
  /// ```
  Future<bool> startSchedule({
    required String scheduleId,
    required int hour,
    required int minute,
  }) => _platform.startSchedule(
    scheduleId: scheduleId,
    hour: hour,
    minute: minute,
  );

  /// Stops a specific schedule by its ID.
  Future<bool> stopSchedule(String scheduleId) =>
      _platform.stopSchedule(scheduleId);

  /// Stops all active schedules and removes all blocks.
  Future<bool> stopAllSchedules() => _platform.stopAllSchedules();

  Future<bool> unblockUntilNextSchedule() => _platform.unblockUntilNextSchedule();

  /// Immediately blocks the selected apps without waiting for schedule.
  ///
  /// Useful for testing or when you want to block apps right away
  /// based on some condition rather than a time-based schedule.
  Future<bool> blockNow() => _platform.blockNow();

  /// Gets the list of installed apps that can be blocked (Android only).
  ///
  /// Returns a list of [AppInfo] objects containing app details including
  /// package name, display name, icon, and selection state.
  ///
  /// On iOS, this returns an empty list as iOS uses the native
  /// Family Activity Picker which cannot be replaced with a custom UI.
  ///
  /// Example:
  /// ```dart
  /// final apps = await blocker.getInstalledApps();
  /// for (final app in apps) {
  ///   print('${app.appName} (${app.packageName})');
  /// }
  /// ```
  Future<List<AppInfo>> getInstalledApps() => _platform.getInstalledApps();

  /// Sets the apps to be blocked (Android only).
  ///
  /// [packageNames] is a list of package names to block.
  /// This is typically called after the user makes a selection in
  /// your custom app picker UI.
  ///
  /// On iOS, this does nothing as iOS uses the native Family Activity Picker.
  ///
  /// Example:
  /// ```dart
  /// await blocker.setSelectedApps(['com.facebook.katana', 'com.instagram.android']);
  /// ```
  Future<bool> setSelectedApps(List<String> packageNames) =>
      _platform.setSelectedApps(packageNames);

  /// Checks if the app has overlay permission (Android only).
  ///
  /// This permission is required to show the blocking overlay on Android.
  /// Without this permission, blocking will still work but will navigate
  /// to the home screen instead of showing the custom overlay.
  ///
  /// On iOS, this always returns true.
  Future<bool> hasOverlayPermission() => _platform.hasOverlayPermission();

  /// Requests overlay permission (Android only).
  ///
  /// Opens the system settings to grant "Display over other apps" permission.
  /// The user must manually enable this permission.
  ///
  /// On iOS, this does nothing and returns true.
  ///
  /// Example:
  /// ```dart
  /// if (!await blocker.hasOverlayPermission()) {
  ///   await blocker.requestOverlayPermission();
  /// }
  /// ```
  Future<bool> requestOverlayPermission() => _platform.requestOverlayPermission();
}
