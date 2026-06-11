import 'package:flutter/material.dart';

import 'prescription_schedule_utils.dart';
import 'mother_pills_history_screen.dart';
import 'services/mom_api_service.dart';
import 'services/notification_service.dart';

class MotherPillsScreen extends StatefulWidget {
  const MotherPillsScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<MotherPillsScreen> createState() => _MotherPillsScreenState();
}

class _MotherPillsScreenState extends State<MotherPillsScreen> {
  final MomApiService _apiService = MomApiService();
  final NotificationService _notificationService = NotificationService();
  late Future<List<Map<String, dynamic>>> _prescriptionsFuture;
  late Future<List<Map<String, dynamic>>> _intakesFuture;

  final DateTime _selectedDate = DateTime.now();
  final Map<String, String> _intakeNotes = {};
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    final enabled = await _notificationService.areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
      });
    }
    if (enabled) {
      await _scheduleNotificationsForPrescriptions();
    }
  }

  void _loadData() {
    _prescriptionsFuture = _apiService.fetchPillPrescriptions(widget.patientId);
    _intakesFuture = _apiService.fetchPillIntakes(
      widget.patientId,
      date: _selectedDate,
    );
  }

  Future<void> _refreshData() async {
    setState(_loadData);
  }

  Future<void> _scheduleNotificationsForPrescriptions() async {
    if (!_notificationsEnabled) return;

    try {
      final prescriptions = await _prescriptionsFuture;
      for (final prescription in prescriptions) {
        for (final slot in expandPrescriptionDoses(prescription)) {
          await _notificationService.schedulePillNotifications(
            pillName: '${prescription['pill_name']}',
            dosage: '${prescription['dosage']}',
            timing: slot.timing,
            mealTime: slot.doseId,
            startDate: DateTime.now(),
            patientId: widget.patientId,
          );
        }
      }
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
    }
  }

  Map<String, bool> _intakeMap(List<Map<String, dynamic>> intakes) {
    final map = <String, bool>{};
    for (final intake in intakes) {
      final pid = intake['prescription_id'];
      final meal = '${intake['meal_time'] ?? ''}'.toLowerCase().trim();
      final taken = intake['taken'] == true ||
          intake['taken'] == 'true' ||
          intake['taken'] == 1;
      map['${pid}_$meal'] = taken;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFE91E63);
    const surface = Color(0xFFFFF6F9);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: const Text('My Pills'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _notificationsEnabled ? Icons.notifications : Icons.notifications_off,
              color: _notificationsEnabled ? Colors.white : Colors.white70,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _scheduleNotificationsForPrescriptions();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Notifications scheduled for each dose slot.')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'View history',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MotherPillsHistoryScreen(patientId: widget.patientId),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today\'s doses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF880E4F),
                    ),
                  ),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(fontSize: 16, color: Color(0xFFC2185B)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _prescriptionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: themeColor));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading prescriptions: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  final prescriptions = snapshot.data ?? [];
                  if (prescriptions.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No prescriptions found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Your doctor will prescribe medications here',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _intakesFuture,
                    builder: (context, intakeSnapshot) {
                      final intakes = intakeSnapshot.data ?? [];
                      final intakeMap = _intakeMap(intakes);
                      final takenSlots = <PrescriptionDoseSlot>[];
                      final pendingSlots = <PrescriptionDoseSlot>[];
                      for (final p in prescriptions) {
                        for (final slot in expandPrescriptionDoses(p)) {
                          final key = '${slot.prescriptionId}_${slot.doseId}';
                          if (intakeMap[key] ?? false) {
                            takenSlots.add(slot);
                          } else {
                            pendingSlots.add(slot);
                          }
                        }
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          _buildPillSection(
                            'Taken today',
                            takenSlots,
                            intakeMap,
                            Colors.green,
                            true,
                          ),
                          const SizedBox(height: 20),
                          _buildPillSection(
                            'Yet to take',
                            pendingSlots,
                            intakeMap,
                            Colors.orange,
                            false,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillSection(
    String title,
    List<PrescriptionDoseSlot> slots,
    Map<String, bool> intakeMap,
    Color color,
    bool isTakenSection,
  ) {
    if (slots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(
              isTakenSection ? Icons.check_circle : Icons.schedule,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              isTakenSection ? 'No doses marked taken yet' : 'All caught up for today',
              style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(isTakenSection ? Icons.check_circle : Icons.schedule, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              '$title (${slots.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...slots.map((s) => _buildDoseCard(s, intakeMap, color)),
      ],
    );
  }

  Widget _buildDoseCard(
    PrescriptionDoseSlot slot,
    Map<String, bool> intakeMap,
    Color color,
  ) {
    final p = slot.prescription;
    final key = '${slot.prescriptionId}_${slot.doseId}';
    final taken = intakeMap[key] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['pill_name']}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p['dosage']}',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slot.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF880E4F),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: taken ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        taken ? Icons.check_circle : Icons.schedule,
                        size: 16,
                        color: taken ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        taken ? 'Taken' : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: taken ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatTimingLabel(slot.timing),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            if ((p['interaction_warnings'] as String?)?.trim().isNotEmpty == true ||
                (p['allergy_concerns'] as String?)?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ('${p['allergy_concerns'] ?? ''}'.trim().isNotEmpty)
                      Text(
                        'Allergies / cautions: ${p['allergy_concerns']}',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                      ),
                    if ('${p['interaction_warnings'] ?? ''}'.trim().isNotEmpty)
                      Text(
                        'Interactions: ${p['interaction_warnings']}',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                      ),
                  ],
                ),
              ),
            ],
            if (!taken)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markAsTaken(slot),
                    icon: const Icon(Icons.check),
                    label: const Text('Mark this dose as taken'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsTaken(PrescriptionDoseSlot slot) async {
    try {
      await _apiService.recordPillIntake(
        patientId: widget.patientId,
        prescriptionId: slot.prescriptionId,
        intakeDate: DateTime.now(),
        mealTime: slot.doseId,
        taken: true,
        notes: _intakeNotes[slot.prescriptionId.toString()] ?? '',
      );
      await _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked ${slot.label} — ${slot.prescription['pill_name']} as taken')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
