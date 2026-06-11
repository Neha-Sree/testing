import 'package:flutter/material.dart';

import '../../chat_screen.dart';
import '../../services/mom_api_service.dart';
import '../doctor_theme.dart';
import '../mother_clinical_profile_screen.dart';

class HighRiskSection extends StatefulWidget {
  const HighRiskSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<HighRiskSection> createState() => _HighRiskSectionState();
}

class _HighRiskSectionState extends State<HighRiskSection> with SingleTickerProviderStateMixin {
  final _api = MomApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.doctorRiskFeed(widget.doctorId, level: 'all', limit: 50);
      final raw = (d['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          _items = raw;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat(String patientId, String name) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => ChatScreen(
          currentUserId: widget.doctorId,
          currentUserType: 'doctor',
          otherUserId: patientId,
          otherUserName: name,
          otherUserType: 'mother',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final it = _items[i];
          final level = '${it['level']}'.toLowerCase();
          final critical = level == 'critical';
          final card = Card(
            elevation: critical ? 3 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: DoctorTheme.levelColor(level).withValues(alpha: 0.5)),
            ),
            child: ListTile(
              title: Text('${it['mother_name']} · ${it['patient_id']}'),
              subtitle: Text('${it['summary']}', maxLines: 3, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 4,
                children: [
                  Chip(label: Text(level), backgroundColor: DoctorTheme.levelColor(level).withValues(alpha: 0.2)),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (ctx) => MotherClinicalProfileScreen(
                            doctorId: widget.doctorId,
                            patientId: '${it['patient_id']}',
                          ),
                        ),
                      );
                    },
                    child: const Text('View'),
                  ),
                  TextButton(onPressed: () => _openChat('${it['patient_id']}', '${it['mother_name']}'), child: const Text('Chat')),
                ],
              ),
            ),
          );
          if (!critical) return card;
          return AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = 0.35 + 0.35 * _pulse.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: DoctorTheme.criticalRed.withValues(alpha: t),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: card,
          );
        },
      ),
    );
  }
}
