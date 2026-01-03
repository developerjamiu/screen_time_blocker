/// Represents the authorization status for Screen Time access.
enum AuthorizationStatus {
  /// Authorization has not been determined yet.
  notDetermined,

  /// The user has approved Screen Time access.
  approved,

  /// The user has denied Screen Time access.
  denied;

  /// Creates an [AuthorizationStatus] from a string value.
  static AuthorizationStatus fromString(String? value) {
    return switch (value) {
      'approved' => AuthorizationStatus.approved,
      'denied' => AuthorizationStatus.denied,
      _ => AuthorizationStatus.notDetermined,
    };
  }
}
