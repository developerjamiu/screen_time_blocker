import 'package:flutter/material.dart';
import '../models/app_info.dart';

/// A beautiful bottom sheet for selecting apps to block (Android only).
///
/// This widget provides a customizable app picker that can be used
/// instead of the native Android app picker.
class AppPickerBottomSheet extends StatefulWidget {
  /// The list of installed apps to display.
  final List<AppInfo> apps;

  /// Callback when selection is confirmed.
  final void Function(List<String> selectedPackages) onConfirm;

  /// Optional title for the bottom sheet.
  final String title;

  /// Optional subtitle/description.
  final String? subtitle;

  /// Primary color for checkboxes and buttons.
  final Color? primaryColor;

  const AppPickerBottomSheet({
    super.key,
    required this.apps,
    required this.onConfirm,
    this.title = 'Select Apps to Block',
    this.subtitle,
    this.primaryColor,
  });

  /// Shows the app picker bottom sheet and returns the selected package names.
  ///
  /// Returns null if the user dismisses the sheet without confirming.
  static Future<List<String>?> show({
    required BuildContext context,
    required List<AppInfo> apps,
    String title = 'Select Apps to Block',
    String? subtitle,
    Color? primaryColor,
  }) async {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppPickerBottomSheet(
        apps: apps,
        title: title,
        subtitle: subtitle,
        primaryColor: primaryColor,
        onConfirm: (selected) => Navigator.of(context).pop(selected),
      ),
    );
  }

  @override
  State<AppPickerBottomSheet> createState() => _AppPickerBottomSheetState();
}

class _AppPickerBottomSheetState extends State<AppPickerBottomSheet> {
  late Set<String> _selectedPackages;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPackages = widget.apps
        .where((app) => app.isSelected)
        .map((app) => app.packageName)
        .toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppInfo> get _filteredApps {
    if (_searchQuery.isEmpty) {
      return widget.apps;
    }
    final query = _searchQuery.toLowerCase();
    return widget.apps.where((app) {
      return app.appName.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();
  }

  void _toggleApp(String packageName) {
    setState(() {
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPackages = _filteredApps.map((app) => app.packageName).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedPackages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.primaryColor ?? theme.colorScheme.primary;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _selectedPackages.length == _filteredApps.length
                          ? _deselectAll
                          : _selectAll,
                      child: Text(
                        _selectedPackages.length == _filteredApps.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                  ],
                ),
                if (widget.subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Selected count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedPackages.length} app${_selectedPackages.length == 1 ? '' : 's'} selected',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // App list
          Expanded(
            child: _filteredApps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No apps found',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      final isSelected =
                          _selectedPackages.contains(app.packageName);

                      return _AppListTile(
                        app: app,
                        isSelected: isSelected,
                        primaryColor: primaryColor,
                        onTap: () => _toggleApp(app.packageName),
                      );
                    },
                  ),
          ),

          // Confirm button
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.of(context).viewPadding.bottom,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onConfirm(_selectedPackages.toList());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Confirm Selection (${_selectedPackages.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppListTile extends StatelessWidget {
  final AppInfo app;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _AppListTile({
    required this.app,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBytes = app.iconBytes;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // App icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[100],
              ),
              clipBehavior: Clip.antiAlias,
              child: iconBytes != null
                  ? Image.memory(
                      iconBytes,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.android,
                        size: 28,
                        color: Colors.grey,
                      ),
                    )
                  : const Icon(
                      Icons.android,
                      size: 28,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(width: 16),

            // App name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.appName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.packageName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
