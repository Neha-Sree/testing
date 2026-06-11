import 'package:flutter/material.dart';

import '../../services/mom_api_service.dart';
import '../doctor_theme.dart';
import '../mother_clinical_profile_screen.dart';

class AssignedMothersSection extends StatefulWidget {
  const AssignedMothersSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<AssignedMothersSection> createState() => _AssignedMothersSectionState();
}

class _AssignedMothersSectionState extends State<AssignedMothersSection> {
  final _api = MomApiService();
  List<Map<String, dynamic>> _all = [];
  String _q = '';
  int? _trimesterFilter;
  String _blood = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _api.fetchPatientsByDoctor(widget.doctorId);
      if (mounted) {
        setState(() {
          _all = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _weeksToTrimester(int? w) {
    if (w == null) return null;
    if (w <= 13) return 1;
    if (w <= 27) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _all.where((m) {
      final name = '${m['full_name'] ?? ''} ${m['patient_id'] ?? ''}'.toLowerCase();
      if (_q.isNotEmpty && !name.contains(_q.toLowerCase())) return false;
      final t = _weeksToTrimester(m['pregnant_weeks'] as int?);
      if (_trimesterFilter != null && t != _trimesterFilter) return false;
      final bg = (m['blood_group'] as String?) ?? '';
      if (_blood.isNotEmpty && bg.toUpperCase() != _blood.toUpperCase()) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              DropdownButton<int?>(
                value: _trimesterFilter,
                hint: const Text('Trimester'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All trimesters')),
                  DropdownMenuItem(value: 1, child: Text('T1')),
                  DropdownMenuItem(value: 2, child: Text('T2')),
                  DropdownMenuItem(value: 3, child: Text('T3')),
                ],
                onChanged: (v) => setState(() => _trimesterFilter = v),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Blood', border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => _blood = v.trim()),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final m = filtered[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: DoctorTheme.primary.withValues(alpha: 0.12),
                    child: Text('${m['pregnant_weeks'] ?? '?'}', style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text('${m['full_name'] ?? m['patient_id']}'),
                  subtitle: Text('${m['patient_id']} · ${m['blood_group'] ?? '-'} · ${m['pregnant_weeks'] ?? '?'} wk'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (ctx) => MotherClinicalProfileScreen(
                          doctorId: widget.doctorId,
                          patientId: '${m['patient_id']}',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
