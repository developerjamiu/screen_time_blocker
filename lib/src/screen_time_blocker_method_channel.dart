import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/models.dart';
import 'screen_time_blocker_platform_interface.dart';

/// An implementation of [ScreenTimeBlockerPlatform] that uses method channels.
class MethodChannelScreenTimeBlocker extends ScreenTimeBlockerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'com.developerjamiu.screen_time_blocker',
  );

  @override
  bool get isSupported {
    // Screen Time API is available on iOS 15+, macOS 12+, and Android
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  Future<bool> requestAuthorization() async {
    _ensureSupported();
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'requestAuthorization',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        'ScreenTimeBlocker: Authorization request failed: ${e.message}',
      );
      return false;
    }
  }

  @override
  Future<AuthorizationStatus> getAuthorizationStatus() async {
    _ensureSupported();
    try {
      final result = await methodChannel.invokeMethod<String>(
        'getAuthorizationStatus',
      );
      return AuthorizationStatus.fromString(result);
    } on PlatformException catch (e) {
      debugPrint(
        'ScreenTimeBlocker: Failed to get authorization status: ${e.message}',
      );
      return AuthorizationStatus.notDetermined;
    }
  }

  @override
  Future<SelectionSummary> selectAppsToBlock() async {
    _ensureSupported();
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'selectApps',
      );
      if (result != null) {
        return SelectionSummary.fromMap(result);
      }
      return SelectionSummary.empty;
    } on PlatformException catch (e) {
      debugPrint('ScreenTimeBlocker: App selection failed: ${e.message}');
      return SelectionSummary.empty;
    }
  }

  @override
  Future<SelectionSummary> getSelectionSummary() async {
    _ensureSupported();
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getSelectionSummary',
      );
      if (result != null) {
        return SelectionSummary.fromMap(result);
      }
      return SelectionSummary.empty;
    } on PlatformException catch (e) {
      debugPrint(
        'ScreenTimeBlocker: Failed to get selection summary: ${e.message}',
      );
      return SelectionSummary.empty;
    }
  }

  @override
  Future<bool> startSchedule({
    required String scheduleId,
    required int hour,
    required int minute,
  }) async {
    _ensureSupported();
    _validateTime(hour, minute);
    try {
      final result = await methodChannel.invokeMethod<bool>('startSchedule', {
        'scheduleId': scheduleId,
        'hour': hour,
        'minute': minute,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenTimeBlocker: Failed to start schedule: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> stopSchedule(String scheduleId) async {
    _ensureSupported();
    try {
      final result = await methodChannel.invokeMethod<bool>('stopSchedule', {
        'scheduleId': scheduleId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('ScreenTimeBlocker: Failed to stop schedule: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> stopAllSchedules() async {
    _ensureSupported();
    try {
      final result = await methodChannel.invokeMethod<bool>('stopAllSchedules');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        'ScreenTimeBlocker: Failed to stop all schedules: ${e.message}',
      );
      return false;
    }
  }

  @override
  Future<bool> unblockUntilNextSchedule() async {
    _ensureSupported();
    try {
      final result = await methodChannel.invokeMethod<bool>('unblockUntilNextSchedule');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        'ScreenTimeBlocker: Failed to unblock until next schedule: ${e.message}',
      );
      return false;
    }
  }

  @override
  Future<bool> blockNow() async {
    _ensureSupported();
    try {
      final result = await methodChannel.invokeMethod<bool>('blockNow');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        'ScreenTimeBlocker: Failed to block immediately: ${e.message}',
      );
      return false;
    }
  }

  @override
  Future<List<AppInfo>> getInstalledApps() async {
    _ensureSupported();
    // Only supported on Android
    if (defaultTargetPlatform != TargetPlatform.android) {
      return [];
    }
    try {
      final result = await methodChannel.invokeMethod<List<Object?>>('getInstalledApps');
      if (result == null) return [];
      return result
          .whereType<Map<Object?, Object?>>()
          .map((map) => AppInfo.fromMap(map))
          .toList();
    } on PlatformException catch (e) {
      debugPrint(
        'ScreenTimeBlocker: Failed to get installed apps: ${e.message}',
      );
      return [];
    }
  }

  @override
  Future<bool> setSelectedApps(List<String> packageNames) async {
    _ensureSupported();
    // Only supported on Android
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'setSelectedApps',
        {'packageNames': packageNames},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        'ScreenTimeBlocker: Failed to set selected apps: ${e.message}',
      );
      return false;
    }
  }

  @override
  Future<bool> hasOverlayPermission() async {
    _ensureSupported();
    // Only applicable on Android
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final result = await methodChannel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        'ScreenTimeBlocker: Failed to check overlay permission: ${e.message}',
      );
      return false;
    }
  }

  @override
  Future<bool> requestOverlayPermission() async {
    _ensureSupported();
    // Only applicable on Android
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final result = await methodChannel.invokeMethod<bool>('requestOverlayPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        'ScreenTimeBlocker: Failed to request overlay permission: ${e.message}',
      );
      return false;
    }
  }

  void _ensureSupported() {
    if (!isSupported) {
      throw UnsupportedError(
        'ScreenTimeBlocker is only supported on iOS 15+, macOS 12+, and Android. '
        'Current platform: $defaultTargetPlatform',
      );
    }
  }

  void _validateTime(int hour, int minute) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'Must be between 0 and 23');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'Must be between 0 and 59');
    }
  }
}
