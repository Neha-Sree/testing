import 'package:flutter/material.dart';

import '../../services/mom_api_service.dart';
import '../doctor_theme.dart';

class OverviewSection extends StatefulWidget {
  const OverviewSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<OverviewSection> {
  final _api = MomApiService();
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _today;
  bool _loading = true;
  String? _error;

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
      final o = await _api.doctorOverview(widget.doctorId);
      final t = await _api.doctorTodayAppointments(widget.doctorId);
      if (mounted) {
        setState(() {
          _overview = o;
          _today = t;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  IconData _iconForKey(String key) {
    switch (key.toLowerCase()) {
      case 'assigned':
        return Icons.people_outline;
      case 'appointments_today':
        return Icons.event_available;
      case 'high_risk':
        return Icons.warning_amber_rounded;
      case 'emergency_open':
        return Icons.emergency_outlined;
      case 'delivered':
        return Icons.local_hospital_outlined;
      default:
        return Icons.insights_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: DoctorTheme.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_outlined, size: 48, color: DoctorTheme.criticalRed.withValues(alpha: 0.7)),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: DoctorTheme.caption),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: DoctorTheme.primary),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final cards = ((_overview?['cards'] as List?)?.cast<Map<String, dynamic>>() ?? [])
        .where((c) {
          final key = '${c['key']}'.toLowerCase();
          final label = '${c['label'] ?? c['key']}'.toLowerCase();
          final combined = '$key $label';
          return !combined.contains('near delivery') &&
              !combined.contains('near_delivery') &&
              !combined.contains('missed medication') &&
              !combined.contains('missed medications') &&
              !combined.contains('missed_medications') &&
              !combined.contains('newborn observation') &&
              !combined.contains('new born observation') &&
              !combined.contains('newborn_observation');
        })
        .toList(growable: false);
    final pending = (_today?['pending'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      color: DoctorTheme.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: DoctorTheme.heroGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: DoctorTheme.primary.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Doctor Dashboard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Live overview of your patient panel',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Key metrics', style: DoctorTheme.sectionTitle.copyWith(color: DoctorTheme.primary)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 1100 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: MediaQuery.sizeOf(context).width > 1100 ? 1.2 : 1.0,
            children: cards.map((c) {
              final colorStr = (c['color'] as String?) ?? '#1976D2';
              final color = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
              final key = '${c['key']}';
              return Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_iconForKey(key), color: color, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${c['count']}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      key.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.85),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${c['trend_hint']}',
                      style: DoctorTheme.caption.copyWith(height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.event_note, color: DoctorTheme.accentTeal, size: 20),
              const SizedBox(width: 8),
              Text(
                "Today's appointments",
                style: DoctorTheme.sectionTitle.copyWith(color: DoctorTheme.accentTeal),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            DoctorSoftCard(
              child: Row(
                children: [
                  Icon(Icons.event_busy, color: DoctorTheme.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(width: 12),
                  Text('No appointments scheduled for today.', style: DoctorTheme.caption),
                ],
              ),
            )
          else
            ...pending.take(6).map((a) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DoctorSoftCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: DoctorTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.event, color: DoctorTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${a['mother_name']}',
                              style: DoctorTheme.sectionTitle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${a['appointment_time']} · ${a['appointment_type']}',
                              style: DoctorTheme.caption,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DoctorTheme.accentTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${a['status']}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DoctorTheme.accentTeal),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
