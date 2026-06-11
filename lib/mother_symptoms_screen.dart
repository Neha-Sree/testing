import 'package:flutter/material.dart';

import 'mother_symptom_choices.dart';
import 'services/mom_api_service.dart';
import 'theme/mom_ui.dart';

/// Mother-facing symptom check-in with toggle chips.
class MotherSymptomsScreen extends StatefulWidget {
  const MotherSymptomsScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<MotherSymptomsScreen> createState() => _MotherSymptomsScreenState();
}

class _MotherSymptomsScreenState extends State<MotherSymptomsScreen> {
  final _api = MomApiService();
  final _extra = TextEditingController();
  bool _busy = false;
  final Set<String> _selectedIds = {};
  final Set<String> _loggedTodayTitles = {};

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  @override
  void dispose() {
    _extra.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    try {
      final logs = await _api.motherSymptoms(widget.patientId, limit: 30);
      final now = DateTime.now();
      final titles = <String>{};
      for (final log in logs) {
        final raw = log['logged_at'] ?? log['created_at'];
        if (raw is! String) continue;
        DateTime? d;
        try {
          d = DateTime.parse(raw);
        } catch (_) {
          continue;
        }
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          final t = log['symptom_text']?.toString() ?? '';
          if (t.isNotEmpty) titles.add(t);
        }
      }
      if (!mounted) return;
      setState(() {
        _loggedTodayTitles
          ..clear()
          ..addAll(titles);
        _selectedIds
          ..clear()
          ..addAll(
            motherSymptomChoices
                .where((c) => titles.contains(c.title))
                .map((c) => c.id),
          );
      });
    } catch (_) {}
  }

  Future<void> _toggle(MotherSymptomChoice c, bool selected) async {
    if (!selected) {
      setState(() => _selectedIds.remove(c.id));
      return;
    }
    if (_loggedTodayTitles.contains(c.title)) {
      setState(() => _selectedIds.add(c.id));
      return;
    }
    setState(() {
      _busy = true;
      _selectedIds.add(c.id);
    });
    try {
      final res = await _api.createMotherSymptom(
        widget.patientId,
        symptomText: c.title,
        severity: c.severity,
        notes: _extra.text.trim().isEmpty ? null : _extra.text.trim(),
      );
      if (!mounted) return;
      _loggedTodayTitles.add(c.title);
      final risk = res['risk'] as Map<String, dynamic>?;
      final reasons = (risk?['reasons'] as List?)?.cast<dynamic>() ?? const [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged: ${c.chipLabel}')),
      );
      if (c.severity == 'critical' || c.severity == 'red') {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Please note'),
            content: Text(
              reasons.isEmpty
                  ? 'If this is an emergency, call your local emergency number or maternity triage now.'
                  : reasons.map((r) => '• $r').join('\n'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } on MomApiException catch (e) {
      if (mounted) {
        setState(() => _selectedIds.remove(c.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomUi.background,
      appBar: AppBar(
        title: const Text('Symptom check-in'),
        backgroundColor: MomUi.surface,
        foregroundColor: MomUi.pink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tap the boxes that apply today. Each selection is saved for your care team.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _extra,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Add detail (optional, added to each new log)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(color: MomUi.pink),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: motherSymptomChoices.map((c) {
              final selected = _selectedIds.contains(c.id);
              Color? selectedColor;
              if (c.severity == 'critical') selectedColor = Colors.deepPurple;
              if (c.severity == 'red') selectedColor = Colors.redAccent;
              if (c.severity == 'yellow') selectedColor = Colors.amber.shade800;
              if (c.severity == 'green') selectedColor = Colors.green.shade700;
              return FilterChip(
                label: Text(c.chipLabel, style: const TextStyle(fontSize: 12)),
                selected: selected,
                showCheckmark: true,
                selectedColor: (selectedColor ?? MomUi.pink).withValues(alpha: 0.2),
                checkmarkColor: selectedColor ?? MomUi.pink,
                onSelected: _busy ? null : (v) => _toggle(c, v),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
