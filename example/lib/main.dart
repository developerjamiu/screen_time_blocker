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

class _HomeScreenState extends State<HomeScreen> {
  final _blocker = const ScreenTimeBlocker();

  AuthorizationStatus _authStatus = AuthorizationStatus.notDetermined;
  SelectionSummary _selection = SelectionSummary.empty;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final status = await _blocker.getAuthorizationStatus();
    final selection = await _blocker.getSelectionSummary();

    setState(() {
      _authStatus = status;
      _selection = selection;
    });
  }

  Future<void> _requestAuthorization() async {
    _setStatus('Requesting authorization...');

    final granted = await _blocker.requestAuthorization();

    setState(() {
      _authStatus = granted
          ? AuthorizationStatus.approved
          : AuthorizationStatus.denied;
    });

    _setStatus(granted ? 'Authorization granted ✅' : 'Authorization denied ❌');
  }

  Future<void> _selectApps() async {
    _setStatus('Opening app picker...');

    final selection = await _blocker.selectAppsToBlock();

    setState(() {
      _selection = selection;
    });

    _setStatus('Selected ${selection.total} items');
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
          ? 'Schedule started ✅ (blocking in ~1 min)'
          : 'Failed to start schedule ❌',
    );
  }

  Future<void> _stopBlocking() async {
    _setStatus('Stopping schedule...');

    final success = await _blocker.stopSchedule('default');

    _setStatus(success ? 'Schedule stopped ✅' : 'Failed to stop ❌');
  }

  Future<void> _unblockToday() async {
    _setStatus('Unblocking for today...');

    final success = await _blocker.unblockForToday();

    _setStatus(success ? 'Unblocked for today ✅' : 'Failed to unblock ❌');
  }

  void _setStatus(String message) {
    setState(() {
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Time Blocker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
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
                      value: _blocker.isSupported ? 'Yes ✅' : 'No ❌',
                    ),
                    _StatusRow(label: 'Authorization', value: _authStatus.name),
                    _StatusRow(
                      label: 'Apps Selected',
                      value: '${_selection.apps}',
                    ),
                    _StatusRow(
                      label: 'Categories Selected',
                      value: '${_selection.categories}',
                    ),
                    _StatusRow(
                      label: 'Web Domains Selected',
                      value: '${_selection.webDomains}',
                    ),
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

            // Start Blocking Button
            ElevatedButton.icon(
              onPressed:
                  _authStatus == AuthorizationStatus.approved &&
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
              label: const Text('Stop Schedule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade900,
              ),
            ),

            const SizedBox(height: 12),

            // Unblock Today Button
            ElevatedButton.icon(
              onPressed: _unblockToday,
              icon: const Icon(Icons.today),
              label: const Text('Unblock for Today'),
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
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
