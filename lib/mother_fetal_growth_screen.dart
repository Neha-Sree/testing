import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/mom_api_service.dart';

/// Fetal growth chart for mothers — data entered by the health worker team.
class MotherFetalGrowthScreen extends StatefulWidget {
  const MotherFetalGrowthScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<MotherFetalGrowthScreen> createState() => _MotherFetalGrowthScreenState();
}

class _MotherFetalGrowthScreenState extends State<MotherFetalGrowthScreen> {
  final _api = MomApiService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _api.motherFetalGrowth(widget.patientId);
    });
  }

  List<Map<String, dynamic>> _series(Map<String, dynamic> raw) {
    return (raw['series'] as List?)
            ?.whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false) ??
        const [];
  }

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFF06292);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        title: const Text('Fetal growth'),
        backgroundColor: Colors.white,
        foregroundColor: pink,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: pink));
          }
          if (snap.hasError) {
            return Center(child: Text('Could not load: ${snap.error}'));
          }
          final series = _series(snap.data ?? {});
          final weightPoints = <FlSpot>[
            for (final r in series)
              if (r['fetal_weight_g'] != null)
                FlSpot(
                  (r['week'] as num).toDouble(),
                  (r['fetal_weight_g'] as num).toDouble(),
                ),
          ]..sort((a, b) => a.x.compareTo(b.x));

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Measurements from your health worker and clinic visits. Your doctor can explain what they mean for you and your baby.',
                  style: TextStyle(color: Colors.black54, height: 1.35),
                ),
                const SizedBox(height: 16),
                if (weightPoints.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No growth measurements yet. Your health worker can add them after a scan or upload a report.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else ...[
                  Text(
                    'Estimated fetal weight (grams)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.pink.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 240,
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: LineChart(
                      LineChartData(
                        minX: weightPoints.first.x - 1,
                        maxX: weightPoints.last.x + 1,
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, m) => Text(
                                '${v.toInt()}w',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
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
                            color: pink,
                            spots: weightPoints,
                            isCurved: true,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: pink.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Visit history',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...series.reversed.map((r) => _MeasurementTile(record: r)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  const _MeasurementTile({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final week = record['week'];
    final weight = record['fetal_weight_g'];
    final hr = record['heart_rate'];
    final femur = record['femur_length'];
    final hc = record['head_circumference'];
    final dateRaw = record['measurement_date'] as String?;
    String dateLabel = '';
    if (dateRaw != null && dateRaw.isNotEmpty) {
      try {
        dateLabel = DateFormat.yMMMd().format(DateTime.parse(dateRaw));
      } catch (_) {
        dateLabel = dateRaw;
      }
    }

    final parts = <String>[
      if (weight != null) '$weight g',
      if (hr != null) 'HR $hr bpm',
      if (femur != null) 'FL $femur cm',
      if (hc != null) 'HC $hc cm',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFCE4EC),
          child: Text(
            '${week ?? '—'}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFF06292),
              fontSize: 12,
            ),
          ),
        ),
        title: Text('Week $week'),
        subtitle: Text(
          [
            if (dateLabel.isNotEmpty) dateLabel,
            if (parts.isEmpty) 'Measurements on file' else parts.join(' · '),
          ].join(' · '),
        ),
      ),
    );
  }
}
