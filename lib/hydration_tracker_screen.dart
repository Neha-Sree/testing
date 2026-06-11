import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/mom_api_service.dart';
import 'services/notification_service.dart';

/// Fixed value sent with each log for backend compatibility (daily goal UI removed).
const double _kHydrationGoalMlForApi = 2500.0;

class HydrationTrackerScreen extends StatefulWidget {
  const HydrationTrackerScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<HydrationTrackerScreen> createState() => _HydrationTrackerScreenState();
}

class _HydrationTrackerScreenState extends State<HydrationTrackerScreen> {
  final MomApiService _apiService = MomApiService();
  final TextEditingController _waterController = TextEditingController();

  List<Map<String, dynamic>> _hydrationLogs = [];
  double _totalWaterToday = 0.0;
  bool _remindersOn = false;
  final NotificationService _notifications = NotificationService();

  String get _remindersPrefKey =>
      'hydration_reminders_on_${widget.patientId}';

  @override
  void initState() {
    super.initState();
    _loadRemindersAndData();
  }

  Future<void> _loadRemindersAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final reminders = prefs.getBool(_remindersPrefKey) ?? false;
    if (mounted) {
      setState(() => _remindersOn = reminders);
    }
    if (reminders) {
      await _notifications.initialize();
      await _notifications.scheduleHydrationReminders(patientId: widget.patientId);
    }
    await _loadHydrationData();
  }

  Future<void> _toggleReminders(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersPrefKey, on);
    setState(() => _remindersOn = on);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      await _notifications.initialize();
      final count = await _notifications.scheduleHydrationReminders(
        patientId: widget.patientId,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Hydration reminders on — $count scheduled (every 2 hours, 8 AM–9 PM).'
                : 'Enable notification permissions to receive reminders.',
          ),
        ),
      );
    } else {
      await _notifications.cancelHydrationReminders();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Hydration reminders turned off.')),
      );
    }
  }

  @override
  void dispose() {
    _waterController.dispose();
    super.dispose();
  }

  Future<void> _loadHydrationData() async {
    try {
      final logs = await _apiService.fetchHydrationLogs(widget.patientId);
      final today = DateTime.now();

      double todayTotal = 0.0;
      final todayLogs = <Map<String, dynamic>>[];

      for (var log in logs) {
        DateTime? logDate;
        for (final key in ['log_date', 'session_date']) {
          final raw = log[key];
          if (raw is String && raw.isNotEmpty) {
            try {
              logDate = DateTime.parse(raw);
              break;
            } catch (_) {}
          }
        }
        if (logDate != null &&
            logDate.day == today.day &&
            logDate.month == today.month &&
            logDate.year == today.year) {
          todayTotal += (log['water_ml'] as num).toDouble();
          todayLogs.add(log);
        }
      }

      if (mounted) {
        setState(() {
          _hydrationLogs = todayLogs;
          _totalWaterToday = todayTotal;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load hydration data: $e');
    }
  }

  Future<void> _addWaterIntake() async {
    final waterText = _waterController.text.trim();
    if (waterText.isEmpty) return;

    final waterAmount = double.tryParse(waterText);
    if (waterAmount == null || waterAmount <= 0) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }

    try {
      await _apiService.createHydrationLog(
        patientId: widget.patientId,
        waterMl: waterAmount,
        goalMl: _kHydrationGoalMlForApi,
      );

      _waterController.clear();
      await _loadHydrationData();
    } catch (e) {
      _showErrorSnackBar('Failed to add water intake: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadHydrationData,
        ),
      ),
    );
  }

  String get _todayTotalLabel =>
      '${(_totalWaterToday / 1000).toStringAsFixed(1)} L today';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        title: const Text(
          'Hydration Tracker',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: _remindersOn
                ? 'Hydration reminders ON'
                : 'Enable hydration reminders',
            onPressed: () => _toggleReminders(!_remindersOn),
            icon: Icon(
              _remindersOn
                  ? Icons.notifications_active
                  : Icons.notifications_none,
            ),
          ),
          IconButton(
            onPressed: _loadHydrationData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildWaterInputCard(),
            const SizedBox(height: 24),
            _buildTodayLogsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s intake',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _todayTotalLabel,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Log water below whenever you drink.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Water Intake',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _waterController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter amount in ml',
                    suffixText: 'ml',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addWaterIntake,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [250, 500, 750, 1000].map((amount) {
              return ActionChip(
                label: Text('${amount}ml'),
                onPressed: () {
                  _waterController.text = amount.toString();
                },
                backgroundColor: const Color(0xFFE3F2FD),
                labelStyle: const TextStyle(color: Color(0xFF1976D2)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayLogsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Intakes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          if (_hydrationLogs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.water_drop_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No water intake recorded today',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _hydrationLogs.length,
              itemBuilder: (context, index) {
                final log = _hydrationLogs[index];
                DateTime time = DateTime.now();
                for (final key in ['log_date', 'session_date']) {
                  final raw = log[key];
                  if (raw is String && raw.isNotEmpty) {
                    try {
                      time = DateTime.parse(raw);
                      break;
                    } catch (_) {}
                  }
                }
                final formattedTime =
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(
                      Icons.water_drop,
                      color: Color(0xFF2196F3),
                      size: 20,
                    ),
                  ),
                  title: Text('${(log['water_ml'] as num).toInt()} ml'),
                  subtitle: Text(formattedTime),
                );
              },
            ),
        ],
      ),
    );
  }
}
