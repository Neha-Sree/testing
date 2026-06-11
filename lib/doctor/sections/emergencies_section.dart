import 'package:flutter/material.dart';

import '../../services/mom_api_service.dart';
import '../doctor_theme.dart';

class EmergenciesSection extends StatefulWidget {
  const EmergenciesSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<EmergenciesSection> createState() => _EmergenciesSectionState();
}

class _EmergenciesSectionState extends State<EmergenciesSection> with SingleTickerProviderStateMixin {
  final _api = MomApiService();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  bool _loading = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load(String status) async {
    setState(() => _loading = true);
    try {
      final rows = await _api.doctorEmergencies(widget.doctorId, status: status);
      if (mounted) {
        setState(() {
          _cache[status] = rows;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load('open');
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        final st = ['open', 'acknowledged', 'resolved'][_tabs.index];
        _load(st);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ['open', 'acknowledged', 'resolved'][_tabs.index];
    final list = _cache[st] ?? [];

    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: DoctorTheme.primary,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'Acknowledged'),
            Tab(text: 'Resolved'),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final e = list[i];
              final id = e['id'] as int;
              return ListTile(
                leading: Icon(Icons.emergency, color: DoctorTheme.levelColor('${e['level']}')),
                title: Text('${e['summary']}'),
                subtitle: Text('${e['patient_id']} · ${e['source']} · ${e['created_at']}'),
                trailing: st == 'open'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await _api.acknowledgeEmergency(id);
                              await _load('open');
                              await _load('acknowledged');
                            },
                            child: const Text('Ack'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await _api.resolveEmergency(id);
                              await _load('open');
                              await _load('resolved');
                            },
                            child: const Text('Resolve'),
                          ),
                        ],
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
