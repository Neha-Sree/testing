import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/mom_api_service.dart';
import '../doctor_theme.dart';

class AnalyticsSection extends StatefulWidget {
  const AnalyticsSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> {
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
      final d = await _api.doctorAnalytics(widget.doctorId);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final appt =
        (_data?['appointments'] as Map?)?.cast<String, dynamic>() ?? {};
    final trim =
        (_data?['trimester_distribution'] as Map?)?.cast<String, dynamic>() ??
        {};
    final completed = (appt['completed'] as num?)?.toDouble() ?? 0;
    final cancelled = (appt['cancelled'] as num?)?.toDouble() ?? 0;
    final other = (appt['scheduled_or_other'] as num?)?.toDouble() ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Analytics',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: DoctorTheme.primary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: completed,
                        color: DoctorTheme.healthyGreen,
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: cancelled,
                        color: DoctorTheme.criticalRed,
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(toY: other, color: DoctorTheme.primary),
                    ],
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, m) {
                        const labels = ['Done', 'Cancel', 'Sched'];
                        final i = v.toInt();
                        if (i >= 0 && i < labels.length) {
                          return Text(
                            labels[i],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Trimester distribution',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    title: 'T1 ${trim['1'] ?? 0}',
                    value: (trim['1'] as num?)?.toDouble() ?? 0.001,
                    color: DoctorTheme.primary,
                  ),
                  PieChartSectionData(
                    title: 'T2 ${trim['2'] ?? 0}',
                    value: (trim['2'] as num?)?.toDouble() ?? 0.001,
                    color: DoctorTheme.accentTeal,
                  ),
                  PieChartSectionData(
                    title: 'T3 ${trim['3'] ?? 0}',
                    value: (trim['3'] as num?)?.toDouble() ?? 0.001,
                    color: DoctorTheme.warningYellow,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
