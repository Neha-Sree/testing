import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/mom_api_service.dart';
import '../doctor_theme.dart';

class FetalMonitoringSection extends StatefulWidget {
  const FetalMonitoringSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<FetalMonitoringSection> createState() => _FetalMonitoringSectionState();
}

class _FetalMonitoringSectionState extends State<FetalMonitoringSection> {
  final _api = MomApiService();
  List<Map<String, dynamic>> _mothers = [];
  String? _selectedPid;
  Map<String, dynamic>? _growth;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final list = await _api.fetchPatientsByDoctor(widget.doctorId);
      if (mounted) {
        setState(() {
          _mothers = list;
          _selectedPid = list.isNotEmpty ? '${list.first['patient_id']}' : null;
          _loading = false;
        });
        if (_selectedPid != null) await _loadGrowth();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGrowth() async {
    final pid = _selectedPid;
    if (pid == null) return;
    try {
      final g = await _api.motherFetalGrowth(pid);
      if (mounted) setState(() => _growth = g);
    } catch (_) {
      if (mounted) setState(() => _growth = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final series =
        (_growth?['series'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('Mother: '),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedPid,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: _mothers
                      .map(
                        (m) => DropdownMenuItem(
                          value: '${m['patient_id']}',
                          child: Text('${m['full_name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    setState(() => _selectedPid = v);
                    await _loadGrowth();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: series.isEmpty
              ? const Center(child: Text('No fetal growth series yet.'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, m) => Text(
                              '${v.toInt()}w',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (v, m) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          color: DoctorTheme.primary,
                          spots: [
                            for (final r in series)
                              if (r['fetal_weight_g'] != null)
                                FlSpot(
                                  (r['week'] as num).toDouble(),
                                  (r['fetal_weight_g'] as num).toDouble(),
                                ),
                          ],
                          isCurved: true,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
