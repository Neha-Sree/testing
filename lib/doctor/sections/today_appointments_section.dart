import 'package:flutter/material.dart';

import '../../services/mom_api_service.dart';
import '../doctor_theme.dart';

class TodayAppointmentsSection extends StatefulWidget {
  const TodayAppointmentsSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<TodayAppointmentsSection> createState() =>
      _TodayAppointmentsSectionState();
}

class _TodayAppointmentsSectionState extends State<TodayAppointmentsSection> {
  final _api = MomApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.doctorTodayAppointments(widget.doctorId);
      if (mounted) {
        setState(() {
          _data = d;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _block(String title, List<Map<String, dynamic>> items, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('None', style: TextStyle(color: Colors.grey.shade600))
          else
            ...items.map(
              (a) => Card(
                child: ListTile(
                  dense: true,
                  title: Text('${a['appointment_time']} · ${a['mother_name']}'),
                  subtitle: Text('${a['appointment_type']} · ${a['status']}'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final pending =
        (_data?['pending'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final done =
        (_data?['completed'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final cancelled =
        (_data?['cancelled'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _block('Pending / scheduled', pending, DoctorTheme.warningYellow),
          _block('Completed', done, DoctorTheme.healthyGreen),
          _block('Cancelled', cancelled, Colors.grey),
        ],
      ),
    );
  }
}
