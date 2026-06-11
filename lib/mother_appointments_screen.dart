import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'mother_vaccine_checklist.dart';
import 'services/mom_api_service.dart';
import 'services/notification_service.dart';
import 'theme/mom_ui.dart';

String _safeStr(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

DateTime? _parseAppointmentDate(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

class MotherAppointmentsScreen extends StatefulWidget {
  const MotherAppointmentsScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<MotherAppointmentsScreen> createState() => _MotherAppointmentsScreenState();
}

class _MotherAppointmentsScreenState extends State<MotherAppointmentsScreen> {
  final MomApiService _apiService = MomApiService();
  late Future<List<Map<String, dynamic>>> _appointmentsFuture;

  Set<String> _vaccineChecks = {};
  bool _vaccineLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _loadVaccineChecks();
  }

  Future<void> _loadVaccineChecks() async {
    final done = await loadMotherVaccineChecks(widget.patientId);
    if (!mounted) return;
    setState(() {
      _vaccineChecks = done;
      _vaccineLoading = false;
    });
  }

  Future<void> _toggleVaccineCheck(String id, bool checked) async {
    setState(() {
      if (checked) {
        _vaccineChecks.add(id);
      } else {
        _vaccineChecks.remove(id);
      }
    });
    await saveMotherVaccineChecks(widget.patientId, _vaccineChecks);
  }

  void _loadAppointments() {
    _appointmentsFuture = _apiService.fetchAppointments(widget.patientId).then((list) {
      NotificationService().scheduleAppointmentReminders(
        list,
        patientId: widget.patientId,
      );
      return list;
    });
  }

  Future<void> _refreshAppointments() async {
    setState(() {
      _loadAppointments();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Icons.event;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomUi.background,
      appBar: AppBar(
        title: const Text('Appointments & wellness'),
        backgroundColor: MomUi.surface,
        foregroundColor: MomUi.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshAppointments,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildVaccineChecklist(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _appointmentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading appointments: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final appointments = _sortedAppointments(snapshot.data ?? []);

                  if (appointments.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No appointments found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Your appointments will appear here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final appointment = appointments[index];
                      final typeStr = _safeStr(appointment['appointment_type'], 'Appointment');
                      final statusStr = _safeStr(appointment['status'], 'scheduled');
                      final apptDate = _parseAppointmentDate(appointment['appointment_date']);
                      final timeStr = _safeStr(appointment['appointment_time'], '--:--');
                      final duration = appointment['duration_minutes'];
                      final durationStr = duration == null ? '—' : '$duration';
                      final hwId = _safeStr(appointment['health_worker_id'], '—');
                      final notes = appointment['notes'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: MomUi.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: MomUi.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with status
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      typeStr,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(statusStr).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getStatusIcon(statusStr),
                                          size: 16,
                                          color: _getStatusColor(statusStr),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusStr.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(statusStr),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Date and Time
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Color(0xFFC2185B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    apptDate != null
                                        ? DateFormat('MMM dd, yyyy').format(apptDate)
                                        : 'Date unavailable',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFC2185B),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Color(0xFFC2185B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFC2185B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Duration and Health Worker
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$durationStr minutes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'HW: $hwId',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Notes
                              if (notes != null && notes.toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    notes.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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

  List<Map<String, dynamic>> _sortedAppointments(List<Map<String, dynamic>> raw) {
    final copy = List<Map<String, dynamic>>.from(raw);
    copy.sort((a, b) {
      final da = _parseAppointmentDate(a['appointment_date']);
      final db = _parseAppointmentDate(b['appointment_date']);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return copy;
  }

  Widget _buildVaccineChecklist() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: MomUi.softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vaccines_outlined, color: MomUi.pink),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mother wellness checklist',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tick off vaccines and screens at your clinic visits. Baby immunizations are tracked after birth at appointments.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if (_vaccineLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            ...motherVaccineChecklist.map((item) {
              final checked = _vaccineChecks.contains(item.id);
              return CheckboxListTile(
                value: checked,
                onChanged: (v) {
                  if (v == null) return;
                  _toggleVaccineCheck(item.id, v);
                },
                title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(item.hint, style: const TextStyle(fontSize: 12)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
        ],
      ),
    );
  }
}
