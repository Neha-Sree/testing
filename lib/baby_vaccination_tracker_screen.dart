import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/mom_api_service.dart';

/// Month-of-life–based immunization checklist (simplified common schedule).
/// Always follow your national programme and your paediatrician; this is a tracker aid only.
class BabyVaccinationTrackerScreen extends StatefulWidget {
  const BabyVaccinationTrackerScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<BabyVaccinationTrackerScreen> createState() => _BabyVaccinationTrackerScreenState();
}

class _VaccineRow {
  const _VaccineRow({
    required this.id,
    required this.label,
    required this.monthLabel,
    required this.fromAgeMonths,
  });

  final String id;
  final String label;
  final String monthLabel;
  final int fromAgeMonths;
}

const _schedule = <_VaccineRow>[
  _VaccineRow(id: 'BCG', label: 'BCG', monthLabel: 'Birth (month 0)', fromAgeMonths: 0),
  _VaccineRow(id: 'Hep B birth', label: 'Hepatitis B — birth dose', monthLabel: 'Birth (month 0)', fromAgeMonths: 0),
  _VaccineRow(id: 'OPV-0', label: 'OPV — birth dose', monthLabel: 'Birth (month 0)', fromAgeMonths: 0),
  _VaccineRow(id: 'Penta 1', label: 'Pentavalent / DPT-HepB-Hib — dose 1', monthLabel: '~6 weeks (by end of month 1)', fromAgeMonths: 1),
  _VaccineRow(id: 'OPV-1', label: 'OPV — dose 1', monthLabel: '~6 weeks (by end of month 1)', fromAgeMonths: 1),
  _VaccineRow(id: 'IPV-1', label: 'IPV — dose 1', monthLabel: '~6 weeks (by end of month 1)', fromAgeMonths: 1),
  _VaccineRow(id: 'RV-1', label: 'Rotavirus — dose 1', monthLabel: '~6 weeks (by end of month 1)', fromAgeMonths: 1),
  _VaccineRow(id: 'Penta 2', label: 'Pentavalent — dose 2', monthLabel: '~10 weeks (by end of month 2)', fromAgeMonths: 2),
  _VaccineRow(id: 'OPV-2', label: 'OPV — dose 2', monthLabel: '~10 weeks (by end of month 2)', fromAgeMonths: 2),
  _VaccineRow(id: 'IPV-2', label: 'IPV — dose 2', monthLabel: '~10 weeks (by end of month 2)', fromAgeMonths: 2),
  _VaccineRow(id: 'RV-2', label: 'Rotavirus — dose 2', monthLabel: '~10 weeks (by end of month 2)', fromAgeMonths: 2),
  _VaccineRow(id: 'Penta 3', label: 'Pentavalent — dose 3', monthLabel: '~14 weeks (by end of month 3)', fromAgeMonths: 3),
  _VaccineRow(id: 'OPV-3', label: 'OPV — dose 3', monthLabel: '~14 weeks (by end of month 3)', fromAgeMonths: 3),
  _VaccineRow(id: 'IPV-3', label: 'IPV — dose 3', monthLabel: '~14 weeks (by end of month 3)', fromAgeMonths: 3),
  _VaccineRow(id: 'RV-3', label: 'Rotavirus — dose 3', monthLabel: '~14 weeks (by end of month 3)', fromAgeMonths: 3),
  _VaccineRow(id: 'Vit A 1', label: 'Vitamin A — 1st dose', monthLabel: 'Month 6', fromAgeMonths: 6),
  _VaccineRow(id: 'MCV-1', label: 'Measles / MCV — 1st dose', monthLabel: 'Month 9', fromAgeMonths: 9),
  _VaccineRow(id: 'MMR / MCV-2', label: 'MMR or measles 2nd dose (as per schedule)', monthLabel: 'Month 12', fromAgeMonths: 12),
];

class _BabyVaccinationTrackerScreenState extends State<BabyVaccinationTrackerScreen> {
  final _api = MomApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _newborn;
  List<Map<String, dynamic>> _given = [];
  final Set<String> _checked = <String>{};
  bool _savingChecklist = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wrap = await _api.getMotherNewborn(widget.patientId);
      final nb = wrap['newborn'];
      Map<String, dynamic>? newbornMap;
      if (nb is Map<String, dynamic>) {
        newbornMap = nb;
      } else if (nb is Map) {
        newbornMap = nb.cast<String, dynamic>();
      }
      List<Map<String, dynamic>> shots = [];
      if (newbornMap != null) {
        final id = (newbornMap['id'] as num?)?.toInt();
        if (id != null) {
          shots = await _api.listNewbornVaccinations(id);
        }
      }
      if (!mounted) return;
      setState(() {
        _newborn = newbornMap;
        _given = shots;
        _checked
          ..clear()
          ..addAll(
            shots
                .map((g) => '${g['vaccine_name']}'.trim())
                .where((name) => name.isNotEmpty),
          );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  DateTime? _birthApprox(Map<String, dynamic> nb) {
    final raw = nb['created_at'];
    if (raw is String && raw.isNotEmpty) {
      try {
        return DateTime.parse(raw);
      } catch (_) {}
    }
    return null;
  }

  int _ageMonths(DateTime? birth, DateTime now) {
    if (birth == null) return 0;
    var m = (now.year - birth.year) * 12 + now.month - birth.month;
    if (now.day < birth.day) m--;
    return m.clamp(0, 48);
  }

  bool _isRecorded(String id) {
    for (final g in _given) {
      if ('${g['vaccine_name']}'.trim() == id) return true;
    }
    return false;
  }

  Future<void> _saveChecklist() async {
    final nb = _newborn;
    if (nb == null || _savingChecklist) return;
    final nid = (nb['id'] as num?)?.toInt();
    if (nid == null) return;

    final toSave = _schedule
        .where((row) => _checked.contains(row.id) && !_isRecorded(row.id))
        .toList(growable: false);
    if (toSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No new checklist items to save.')),
      );
      return;
    }

    setState(() => _savingChecklist = true);
    try {
      for (final row in toSave) {
        await _api.createNewbornVaccination(
          newbornId: nid,
          vaccineName: row.id,
          givenDate: DateTime.now(),
          notes: 'Saved from LifeNest checklist',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vaccination checklist saved.')),
      );
      await _load();
    } on MomApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _savingChecklist = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFF06292);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        title: const Text('Baby immunizations'),
        backgroundColor: Colors.white,
        foregroundColor: pink,
        elevation: 0,
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: pink))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  color: pink,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'This schedule is a simplified month guide only. Your country’s immunization card '
                            'and your doctor decide exact dates and vaccines.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_newborn == null) ...[
                        const Text(
                          'No newborn record is linked to your profile yet. You can still preview the schedule; '
                          'ask your hospital or doctor to add your baby so you can record doses here.',
                          style: TextStyle(height: 1.35),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Builder(
                          builder: (context) {
                            final birth = _birthApprox(_newborn!);
                            final age = _ageMonths(birth, DateTime.now());
                            final birthStr = birth != null ? DateFormat.yMMMd().format(birth) : '—';
                            return Card(
                              color: Colors.teal.shade50,
                              child: ListTile(
                                leading: const Icon(Icons.child_care, color: Colors.teal),
                                title: Text(_newborn!['name'] != null ? '${_newborn!['name']}' : 'Your baby'),
                                subtitle: Text('Approx. age: $age months · Record started: $birthStr'),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Schedule',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: pink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_newborn != null)
                            FilledButton(
                              onPressed: _savingChecklist ? null : _saveChecklist,
                              style: FilledButton.styleFrom(
                                backgroundColor: pink,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(_savingChecklist ? 'Saving...' : 'Save checklist'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._schedule.map((row) {
                        final due = _newborn != null && _ageMonths(_birthApprox(_newborn!), DateTime.now()) >= row.fromAgeMonths;
                        final done = _newborn != null && _isRecorded(row.id);
                        final checked = _checked.contains(row.id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            value: checked || done,
                            onChanged: _newborn == null || done
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value == true) {
                                        _checked.add(row.id);
                                      } else {
                                        _checked.remove(row.id);
                                      }
                                    });
                                  },
                            title: Text(row.label),
                            subtitle: Text('${row.monthLabel}${due && !done ? ' · due window' : ''}'),
                            secondary: Icon(
                              done ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: done ? Colors.green : (due ? Colors.orange : Colors.grey),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                        );
                      }),
                      if (_given.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Your log', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ..._given.map(
                          (g) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.verified_outlined, size: 20),
                            title: Text('${g['vaccine_name']}'),
                            subtitle: Text('Given: ${g['given_date'] ?? '—'}'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
