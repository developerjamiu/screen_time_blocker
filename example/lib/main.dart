import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_time_blocker/screen_time_blocker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Time Blocker Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _blocker = const ScreenTimeBlocker();

  AuthorizationStatus _authStatus = AuthorizationStatus.notDetermined;
  SelectionSummary _selection = SelectionSummary.empty;
  bool _hasOverlayPermission = false;
  String _statusMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh authorization status when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _loadInitialState() async {
    setState(() => _isLoading = true);

    final status = await _blocker.getAuthorizationStatus();
    final selection = await _blocker.getSelectionSummary();
    final hasOverlay = await _blocker.hasOverlayPermission();

    setState(() {
      _authStatus = status;
      _selection = selection;
      _hasOverlayPermission = hasOverlay;
      _isLoading = false;
    });
  }

  Future<void> _refreshStatus() async {
    final status = await _blocker.getAuthorizationStatus();
    final selection = await _blocker.getSelectionSummary();
    final hasOverlay = await _blocker.hasOverlayPermission();

    if (mounted) {
      setState(() {
        _authStatus = status;
        _selection = selection;
        _hasOverlayPermission = hasOverlay;
      });

      if (status == AuthorizationStatus.approved &&
          _statusMessage.contains('denied')) {
        _setStatus('Authorization granted');
      }
    }
  }

  Future<void> _requestAuthorization() async {
    _setStatus('Opening settings...');

    // On Android, this opens accessibility settings
    // User must manually enable the service and return
    await _blocker.requestAuthorization();

    // Don't immediately set to denied - wait for user to return
    // The didChangeAppLifecycleState will refresh the status
    _setStatus('Enable accessibility service and return');
  }

  Future<void> _requestOverlayPermission() async {
    _setStatus('Opening overlay settings...');

    await _blocker.requestOverlayPermission();

    _setStatus('Enable "Display over other apps" and return');
  }

  Future<void> _selectApps() async {
    // On Android, use the beautiful Flutter bottom sheet
    if (Platform.isAndroid) {
      await _selectAppsWithBottomSheet();
    } else {
      // On iOS, use the native picker (required by Apple)
      _setStatus('Opening app picker...');
      final selection = await _blocker.selectAppsToBlock();
      setState(() {
        _selection = selection;
      });
      _setStatus('Selected ${selection.total} items');
    }
  }

  Future<void> _selectAppsWithBottomSheet() async {
    _setStatus('Loading apps...');

    // Get the list of installed apps
    final apps = await _blocker.getInstalledApps();

    if (!mounted) return;

    if (apps.isEmpty) {
      _setStatus('No apps found');
      return;
    }

    _setStatus('');

    // Show the beautiful bottom sheet picker
    final selectedPackages = await AppPickerBottomSheet.show(
      context: context,
      apps: apps,
      title: 'Select Apps to Block',
      subtitle: 'Choose which apps you want to restrict access to',
      primaryColor: Theme.of(context).colorScheme.primary,
    );

    if (selectedPackages == null) {
      // User dismissed without confirming
      return;
    }

    // Save the selection
    await _blocker.setSelectedApps(selectedPackages);

    // Refresh the selection summary
    final selection = await _blocker.getSelectionSummary();
    setState(() {
      _selection = selection;
    });

    _setStatus('Selected ${selection.total} apps');
  }

  Future<void> _startBlocking() async {
    if (_selection.isEmpty) {
      _setStatus('Please select apps first');
      return;
    }

    final now = DateTime.now();
    // Start blocking 1 minute from now for testing
    final startMinute = (now.minute + 1) % 60;
    final startHour = now.minute + 1 >= 60 ? (now.hour + 1) % 24 : now.hour;

    _setStatus(
      'Starting schedule at $startHour:${startMinute.toString().padLeft(2, '0')}...',
    );

    final success = await _blocker.startSchedule(
      scheduleId: 'default',
      hour: startHour,
      minute: startMinute,
    );

    _setStatus(
      success
          ? 'Schedule started (blocking in ~1 min)'
          : 'Failed to start schedule',
    );
  }

  Future<void> _blockImmediately() async {
    if (_selection.isEmpty) {
      _setStatus('Please select apps first');
      return;
    }

    // Check overlay permission first
    if (Platform.isAndroid && !_hasOverlayPermission) {
      _setStatus('Overlay permission required. Requesting...');
      await _blocker.requestOverlayPermission();
      return;
    }

    _setStatus('Blocking apps now...');

    final success = await _blocker.blockNow();

    _setStatus(success ? 'Apps are now blocked' : 'Failed to block apps');
  }

  Future<void> _stopBlocking() async {
    _setStatus('Stopping schedule...');

    final success = await _blocker.stopAllSchedules();

    _setStatus(success ? 'All schedules stopped' : 'Failed to stop');
  }

  Future<void> _unblockUntilNextSchedule() async {
    _setStatus('Unblocking until next schedule...');

    final success = await _blocker.unblockUntilNextSchedule();

    _setStatus(
        success ? 'Unblocked until next schedule' : 'Failed to unblock');
  }

  void _setStatus(String message) {
    setState(() {
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final needsOverlayPermission = Platform.isAndroid && !_hasOverlayPermission;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Time Blocker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialState,
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _StatusRow(
                            label: 'Platform Supported',
                            value: _blocker.isSupported ? 'Yes' : 'No',
                            isPositive: _blocker.isSupported,
                          ),
                          _StatusRow(
                            label: 'Authorization',
                            value: _authStatusDisplay,
                            isPositive:
                                _authStatus == AuthorizationStatus.approved,
                          ),
                          if (Platform.isAndroid)
                            _StatusRow(
                              label: 'Overlay Permission',
                              value: _hasOverlayPermission ? 'Granted' : 'Required',
                              isPositive: _hasOverlayPermission,
                            ),
                          _StatusRow(
                            label: 'Apps Selected',
                            value: '${_selection.apps}',
                            isPositive: _selection.apps > 0,
                          ),
                          if (!Platform.isAndroid) ...[
                            _StatusRow(
                              label: 'Categories Selected',
                              value: '${_selection.categories}',
                              isPositive: _selection.categories > 0,
                            ),
                            _StatusRow(
                              label: 'Web Domains Selected',
                              value: '${_selection.webDomains}',
                              isPositive: _selection.webDomains > 0,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Message
                  if (_statusMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(color: Colors.blue.shade900),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Authorization Button
                  ElevatedButton.icon(
                    onPressed: _authStatus == AuthorizationStatus.approved
                        ? null
                        : _requestAuthorization,
                    icon: const Icon(Icons.security),
                    label: Text(
                      _authStatus == AuthorizationStatus.approved
                          ? 'Authorized'
                          : 'Request Authorization',
                    ),
                  ),

                  // Overlay Permission Button (Android only)
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _hasOverlayPermission
                          ? null
                          : _requestOverlayPermission,
                      icon: const Icon(Icons.layers),
                      label: Text(
                        _hasOverlayPermission
                            ? 'Overlay Granted'
                            : 'Request Overlay Permission',
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Select Apps Button
                  ElevatedButton.icon(
                    onPressed: _authStatus == AuthorizationStatus.approved
                        ? _selectApps
                        : null,
                    icon: const Icon(Icons.apps),
                    label: const Text('Select Apps to Block'),
                  ),

                  const SizedBox(height: 12),

                  // Block Now Button
                  ElevatedButton.icon(
                    onPressed: _authStatus == AuthorizationStatus.approved &&
                            _selection.isNotEmpty
                        ? _blockImmediately
                        : null,
                    icon: const Icon(Icons.block),
                    label: Text(
                      needsOverlayPermission
                          ? 'Block Now (needs overlay)'
                          : 'Block Now',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Start Blocking Button
                  ElevatedButton.icon(
                    onPressed: _authStatus == AuthorizationStatus.approved &&
                            _selection.isNotEmpty
                        ? _startBlocking
                        : null,
                    icon: const Icon(Icons.lock),
                    label: const Text('Start Blocking (in 1 min)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade900,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Stop Blocking Button
                  ElevatedButton.icon(
                    onPressed: _stopBlocking,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Stop All Schedules'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.orange.shade900,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Unblock Until Next Schedule Button
                  ElevatedButton.icon(
                    onPressed: _unblockUntilNextSchedule,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Unblock Until Next Schedule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String get _authStatusDisplay {
    switch (_authStatus) {
      case AuthorizationStatus.approved:
        return 'Approved';
      case AuthorizationStatus.denied:
        return 'Denied';
      case AuthorizationStatus.notDetermined:
        return 'Not Determined';
    }
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPositive;

  const _StatusRow({
    required this.label,
    required this.value,
    this.isPositive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(
                isPositive ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: isPositive ? Colors.green : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
