import 'dart:convert';
import 'dart:typed_data';

/// Information about an installed app that can be blocked.
class AppInfo {
  /// The package name (Android) or bundle identifier (iOS).
  final String packageName;

  /// The display name of the app.
  final String appName;

  /// Whether the app is currently selected for blocking.
  final bool isSelected;

  /// The app icon as base64-encoded PNG (Android only).
  final String? iconBase64;

  const AppInfo({
    required this.packageName,
    required this.appName,
    this.isSelected = false,
    this.iconBase64,
  });

  /// Creates an AppInfo from a map returned by the platform.
  factory AppInfo.fromMap(Map<Object?, Object?> map) {
    return AppInfo(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      isSelected: map['isSelected'] as bool? ?? false,
      iconBase64: map['icon'] as String?,
    );
  }

  /// Decodes the icon from base64 to bytes for use with Image.memory().
  Uint8List? get iconBytes {
    if (iconBase64 == null || iconBase64!.isEmpty) {
      return null;
    }
    try {
      return base64Decode(iconBase64!);
    } catch (e) {
      return null;
    }
  }

  /// Creates a copy with updated selection state.
  AppInfo copyWith({bool? isSelected}) {
    return AppInfo(
      packageName: packageName,
      appName: appName,
      isSelected: isSelected ?? this.isSelected,
      iconBase64: iconBase64,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppInfo &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;
}
