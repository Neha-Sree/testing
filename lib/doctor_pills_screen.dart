import 'dart:convert';

import 'package:flutter/material.dart';

import 'prescription_schedule_utils.dart';
import 'services/mom_api_service.dart';
import 'services/notification_service.dart';

/// Embedded prescriptions hub for the doctor shell (patient picker + form + open full screen).
Widget buildPrescriptionsContent({required String doctorId}) {
  return DoctorPrescriptionsHub(doctorId: doctorId);
}

class DoctorPrescriptionsHub extends StatefulWidget {
  const DoctorPrescriptionsHub({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<DoctorPrescriptionsHub> createState() => _DoctorPrescriptionsHubState();
}

class _DoctorPrescriptionsHubState extends State<DoctorPrescriptionsHub> {
  final MomApiService _api = MomApiService();
  List<Map<String, dynamic>> _patients = [];
  String? _pid;
  List<Map<String, dynamic>> _rx = [];
  bool _loading = true;
  Map<String, dynamic>? _pillHistory;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _loading = true);
    try {
      final list = await _api.fetchPatientsByDoctor(widget.doctorId);
      if (!mounted) return;
      setState(() {
        _patients = list;
        _pid = list.isNotEmpty ? '${list.first['patient_id']}' : null;
        _loading = false;
      });
      if (_pid != null) {
        await _loadRx();
        await _loadHistory();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRx() async {
    final pid = _pid;
    if (pid == null) return;
    try {
      final list = await _api.fetchPillPrescriptions(pid);
      if (mounted) setState(() => _rx = list);
    } catch (_) {
      if (mounted) setState(() => _rx = []);
    }
  }

  Future<void> _loadHistory() async {
    final pid = _pid;
    if (pid == null) return;
    try {
      final h = await _api.fetchPillHistory(pid, days: 14);
      if (mounted) setState(() => _pillHistory = h);
    } catch (_) {
      if (mounted) setState(() => _pillHistory = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_patients.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No mothers assigned to you yet. Assign a patient first.'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            value: _pid,
            decoration: const InputDecoration(labelText: 'Mother', border: OutlineInputBorder()),
            items: _patients
                .map(
                  (m) => DropdownMenuItem(
                    value: '${m['patient_id']}',
                    child: Text('${m['full_name']}'),
                  ),
                )
                .toList(),
            onChanged: (v) async {
              setState(() => _pid = v);
              await _loadRx();
              await _loadHistory();
            },
          ),
        ),
        if (_pillHistory != null) _buildHistorySummary(_pillHistory!),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: OutlinedButton.icon(
            onPressed: _pid == null
                ? null
                : () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (ctx) => DoctorPillsScreen(
                          doctorId: widget.doctorId,
                          patientId: _pid!,
                        ),
                      ),
                    );
                    await _loadRx();
                    await _loadHistory();
                  },
            icon: const Icon(Icons.add),
            label: const Text('New prescription'),
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: _rx.length,
            itemBuilder: (context, i) {
              final p = _rx[i];
              final slots = expandPrescriptionDoses(p);
              final sched = slots.map((s) => '${s.label} (${formatTimingLabel(s.timing)})').join(' · ');
              return ListTile(
                title: Text('${p['pill_name']}'),
                subtitle: Text(
                  '${p['dosage']} · ${p['frequency']}\n$sched',
                  maxLines: 3,
                ),
                isThreeLine: true,
                trailing: p['refill_reminder_days'] != null
                    ? Chip(
                        label: Text('Refill ~${p['refill_reminder_days']}d'),
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySummary(Map<String, dynamic> env) {
    final adherence = env['window_adherence_pct'] ?? 0;
    final taken = env['total_taken'] ?? 0;
    final missed = env['total_missed'] ?? 0;
    final active = _rx.where((r) => r['is_active'] == true).length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medication overview (14 days)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _statChip('Adherence', '$adherence%'),
                _statChip('Doses taken', '$taken'),
                _statChip('Missed / skipped', '$missed'),
                _statChip('Active Rx', '$active'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String k, String v) {
    return Chip(
      avatar: const Icon(Icons.analytics, size: 18),
      label: Text('$k: $v'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class DoctorPillsScreen extends StatefulWidget {
  const DoctorPillsScreen({
    super.key,
    required this.doctorId,
    required this.patientId,
    this.doctorName,
  });

  final String doctorId;
  final String patientId;
  final String? doctorName;

  @override
  State<DoctorPillsScreen> createState() => _DoctorPillsScreenState();
}

class _DoseEditorRow {
  _DoseEditorRow({required this.period, required this.timing});

  String period;
  String timing;
}

class _DoctorPillsScreenState extends State<DoctorPillsScreen> {
  final MomApiService _apiService = MomApiService();
  final NotificationService _notificationService = NotificationService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _pillNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _durationDaysController = TextEditingController();
  final TextEditingController _refillDaysController = TextEditingController();
  final TextEditingController _interactionController = TextEditingController();
  final TextEditingController _allergyController = TextEditingController();

  String _trimesterSafety = 'generally_safe';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  final List<_DoseEditorRow> _doseRows = [
    _DoseEditorRow(period: 'morning', timing: 'before_food'),
  ];

  static const _periods = [
    ('morning', 'Morning'),
    ('afternoon', 'Afternoon'),
    ('evening', 'Evening'),
    ('night', 'Night'),
    ('breakfast', 'Breakfast'),
    ('lunch', 'Lunch'),
    ('dinner', 'Dinner'),
    ('bedtime', 'Bedtime'),
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _pillNameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _notesController.dispose();
    _durationDaysController.dispose();
    _refillDaysController.dispose();
    _interactionController.dispose();
    _allergyController.dispose();
    super.dispose();
  }

  String _doseScheduleJson() {
    final doses = <Map<String, dynamic>>[];
    for (var i = 0; i < _doseRows.length; i++) {
      final r = _doseRows[i];
      doses.add({
        'id': 'dose_$i',
        'label': _periods.firstWhere((e) => e.$1 == r.period, orElse: () => (r.period, r.period)).$2,
        'timing': r.timing,
        'period': r.period,
      });
    }
    return jsonEncode({'doses': doses});
  }

  Future<void> _createPrescription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_doseRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one dose time.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final durationDays = int.tryParse(_durationDaysController.text.trim());
    DateTime? computedEnd = _endDate;
    if (computedEnd == null && durationDays != null && durationDays > 0) {
      computedEnd = _startDate.add(Duration(days: durationDays));
    }

    final first = _doseRows.first;
    final freq =
        '${_doseRows.length}x daily — ${_doseRows.map((e) => _periods.firstWhere((p) => p.$1 == e.period, orElse: () => (e.period, e.period)).$2).join(', ')}';

    try {
      await _apiService.createPillPrescription(
        patientId: widget.patientId,
        doctorId: widget.doctorId,
        pillName: _pillNameController.text.trim(),
        dosage: _dosageController.text.trim(),
        timing: first.timing,
        mealTime: first.period,
        frequency: _frequencyController.text.trim().isEmpty ? freq : _frequencyController.text.trim(),
        startDate: _startDate,
        endDate: computedEnd,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        doseScheduleJson: _doseScheduleJson(),
        trimesterSafety: _trimesterSafety,
        refillReminderDays: int.tryParse(_refillDaysController.text.trim()),
        interactionWarnings:
            _interactionController.text.trim().isEmpty ? null : _interactionController.text.trim(),
        allergyConcerns: _allergyController.text.trim().isEmpty ? null : _allergyController.text.trim(),
      );

      await _notificationService.initialize();
      for (final row in _doseRows) {
        await _notificationService.schedulePillNotifications(
          pillName: _pillNameController.text.trim(),
          dosage: _dosageController.text.trim(),
          timing: row.timing,
          mealTime: row.period,
          startDate: _startDate,
          endDate: computedEnd,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription saved. Mother sees each dose separately on her dashboard.'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _pillNameController.clear();
    _dosageController.clear();
    _frequencyController.clear();
    _notesController.clear();
    _durationDaysController.clear();
    _refillDaysController.clear();
    _interactionController.clear();
    _allergyController.clear();
    _trimesterSafety = 'generally_safe';
    _startDate = DateTime.now();
    _endDate = null;
    setState(() {
      _doseRows
        ..clear()
        ..add(_DoseEditorRow(period: 'morning', timing: 'before_food'));
    });
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text('Prescribe medication'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headerCard(themeColor),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _pillNameController,
                  decoration: _dec('Medicine name *', Icons.medication),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dosageController,
                  decoration: _dec('Dosage * (e.g. 500 mg, 1 tablet)', Icons.scale),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _frequencyController,
                  decoration: _dec(
                    'Frequency (optional — auto from schedule if empty)',
                    Icons.schedule,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _trimesterSafety,
                  decoration: _dec('Trimester safety', Icons.pregnant_woman),
                  items: const [
                    DropdownMenuItem(value: 'generally_safe', child: Text('Generally safe (all trimesters)')),
                    DropdownMenuItem(value: 'caution_first', child: Text('Caution in 1st trimester')),
                    DropdownMenuItem(value: 'caution_third', child: Text('Caution in 3rd trimester')),
                    DropdownMenuItem(value: 'consult_specialist', child: Text('Specialist consult advised')),
                  ],
                  onChanged: (v) => setState(() => _trimesterSafety = v ?? 'generally_safe'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationDaysController,
                        keyboardType: TextInputType.number,
                        decoration: _dec('Duration (days)', Icons.date_range),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _refillDaysController,
                        keyboardType: TextInputType.number,
                        decoration: _dec('Refill reminder (days)', Icons.notifications_active),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Duration sets end date from start. You can still pick a fixed end date below.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _interactionController,
                  maxLines: 2,
                  decoration: _dec(
                    'Drug interactions / overdose cautions',
                    Icons.warning_amber,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _allergyController,
                  maxLines: 2,
                  decoration: _dec('Allergy cross-check & alerts', Icons.coronavirus_outlined),
                ),
                const SizedBox(height: 20),
                Text(
                  'Dose schedule (${_doseRows.length} time${_doseRows.length == 1 ? '' : 's'} / day)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...List.generate(_doseRows.length, (i) => _doseRowEditor(i)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _doseRows.add(_DoseEditorRow(period: 'evening', timing: 'after_food'));
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add another daily time'),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text('Start: ${_startDate.toString().split(' ')[0]}'),
                  leading: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _startDate = d);
                  },
                ),
                ListTile(
                  title: Text('End date: ${_endDate?.toString().split(' ')[0] ?? 'From duration or open-ended'}'),
                  leading: const Icon(Icons.event_busy),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate,
                      firstDate: _startDate,
                      lastDate: _startDate.add(const Duration(days: 730)),
                    );
                    if (d != null) setState(() => _endDate = d);
                  },
                  trailing: _endDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _endDate = null),
                        )
                      : null,
                ),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: _dec('Special instructions for the mother', Icons.note_alt),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearForm,
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createPrescription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save prescription'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      prefixIcon: Icon(icon),
    );
  }

  Widget _headerCard(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Doctor: ${widget.doctorName ?? widget.doctorId}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text('Patient: ${widget.patientId}', style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _doseRowEditor(int index) {
    final row = _doseRows[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: row.period,
                    decoration: const InputDecoration(labelText: 'Time of day', border: OutlineInputBorder()),
                    items: _periods
                        .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => row.period = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: row.timing,
                    decoration: const InputDecoration(labelText: 'With food', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'before_food', child: Text('Before food')),
                      DropdownMenuItem(value: 'after_food', child: Text('After food')),
                      DropdownMenuItem(value: 'with_food', child: Text('With food')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => row.timing = v);
                    },
                  ),
                ),
                if (_doseRows.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _doseRows.removeAt(index)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
