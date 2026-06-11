import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/mom_api_service.dart';
import '../doctor_theme.dart';

class NewbornSection extends StatefulWidget {
  const NewbornSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<NewbornSection> createState() => _NewbornSectionState();
}

class _NewbornSectionState extends State<NewbornSection> {
  final _api = MomApiService();
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _vitals = [];
  List<Map<String, dynamic>> _vax = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.doctorNewborns(widget.doctorId);
      final list = (d['newborns'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          _rows = list;
          _selected = list.isNotEmpty ? list.first : null;
          _loading = false;
        });
        if (_selected != null) await _loadDetails();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDetails() async {
    final id = _selected?['id'] as int?;
    if (id == null) return;
    try {
      final v = await _api.listNewbornVitals(id);
      final z = await _api.listNewbornVaccinations(id);
      if (mounted) {
        setState(() {
          _vitals = v;
          _vax = z;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _vitals = [];
          _vax = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_rows.isEmpty) {
      return const Center(child: Text('No newborn records for your panel.'));
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < _vitals.length && i < 20; i++) {
      final w = _vitals[i]['weight_g'];
      if (w != null) spots.add(FlSpot(i.toDouble(), (w as num).toDouble()));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: DropdownButtonFormField<int>(
            initialValue: _selected?['id'] as int?,
            decoration: const InputDecoration(
              labelText: 'Newborn',
              border: OutlineInputBorder(),
            ),
            items: _rows
                .map(
                  (r) => DropdownMenuItem(
                    value: r['id'] as int,
                    child: Text(
                      '${r['name'] ?? r['patient_id']} (${r['mother_name']})',
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) async {
              final row = _rows.firstWhere((e) => e['id'] == id);
              setState(() => _selected = row);
              await _loadDetails();
            },
          ),
        ),
        SizedBox(
          height: 180,
          child: spots.isEmpty
              ? const Center(child: Text('No vitals yet'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots.reversed.toList(),
                          color: DoctorTheme.accentTeal,
                          isCurved: true,
                        ),
                      ],
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: true),
                    ),
                  ),
                ),
        ),
        const ListTile(title: Text('Vaccinations')),
        Expanded(
          child: ListView.builder(
            itemCount: _vax.length,
            itemBuilder: (context, i) {
              final x = _vax[i];
              return ListTile(
                dense: true,
                title: Text('${x['vaccine_name']}'),
                subtitle: Text(
                  'Scheduled ${x['scheduled_date'] ?? '-'} · Given ${x['given_date'] ?? '-'}',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
