/// Represents a summary of selected apps and categories to block.
class SelectionSummary {
  /// Number of individual apps selected.
  final int apps;

  /// Number of categories selected.
  final int categories;

  /// Number of web domains selected.
  final int webDomains;

  const SelectionSummary({
    required this.apps,
    required this.categories,
    required this.webDomains,
  });

  /// Empty selection summary.
  static const empty = SelectionSummary(apps: 0, categories: 0, webDomains: 0);

  /// Total number of items selected.
  int get total => apps + categories + webDomains;

  /// Whether any items are selected.
  bool get isEmpty => total == 0;

  /// Whether any items are selected.
  bool get isNotEmpty => !isEmpty;

  /// Creates a [SelectionSummary] from a map.
  factory SelectionSummary.fromMap(Map<Object?, Object?> map) {
    return SelectionSummary(
      apps: map['apps'] as int? ?? 0,
      categories: map['categories'] as int? ?? 0,
      webDomains: map['websites'] as int? ?? 0,
    );
  }

  /// Converts this summary to a map.
  Map<String, int> toMap() {
    return {'apps': apps, 'categories': categories, 'websites': webDomains};
  }

  @override
  String toString() =>
      'SelectionSummary(apps: $apps, categories: $categories, webDomains: $webDomains)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionSummary &&
          runtimeType == other.runtimeType &&
          apps == other.apps &&
          categories == other.categories &&
          webDomains == other.webDomains;

  @override
  int get hashCode => Object.hash(apps, categories, webDomains);
}
