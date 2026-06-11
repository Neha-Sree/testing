import 'package:flutter/material.dart';

import 'services/mom_api_service.dart';
import 'theme/mom_ui.dart';

/// Quick mood check-in for the mother app (happy, sad, grumpy, etc.).
class MotherMoodScreen extends StatefulWidget {
  const MotherMoodScreen({super.key, required this.patientId});

  final String patientId;

  /// Shared with [MomDashboardScreen] home quick chips.
  static const quickMoods = <({String code, String label, String emoji})>[
    (code: 'happy', label: 'Happy', emoji: '😊'),
    (code: 'calm', label: 'Calm', emoji: '😌'),
    (code: 'neutral', label: 'Neutral', emoji: '😐'),
    (code: 'tired', label: 'Tired', emoji: '😴'),
    (code: 'sad', label: 'Sad', emoji: '😢'),
    (code: 'anxious', label: 'Anxious', emoji: '😰'),
    (code: 'grumpy', label: 'Grumpy', emoji: '😤'),
    (code: 'angry', label: 'Angry', emoji: '😠'),
    (code: 'stressed', label: 'Stressed', emoji: '😣'),
    (code: 'overwhelmed', label: 'Overwhelmed', emoji: '🫠'),
  ];

  @override
  State<MotherMoodScreen> createState() => _MotherMoodScreenState();
}

class _MotherMoodScreenState extends State<MotherMoodScreen> {
  final _api = MomApiService();
  final _notes = TextEditingController();
  bool _saving = false;

  static const _moods = MotherMoodScreen.quickMoods;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit(String mood) async {
    setState(() => _saving = true);
    try {
      final res = await _api.logMotherMood(
        widget.patientId,
        mood: mood,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      final risk = res['risk'] as Map<String, dynamic>?;
      final reasons = (risk?['reasons'] as List?)?.cast<dynamic>() ?? const [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            risk == null
                ? 'Mood saved'
                : 'Mood saved — care summary: ${risk['level'] ?? ''}',
          ),
        ),
      );
      if (reasons.isNotEmpty && mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Wellbeing check-in'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Level: ${risk?['level'] ?? ''}'),
                  const SizedBox(height: 8),
                  ...reasons.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $r'),
                      )),
                  const SizedBox(height: 8),
                  const Text(
                    'This is not a diagnosis. Contact your doctor if you feel unsafe or very unwell.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } on MomApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomUi.background,
      appBar: AppBar(
        title: const Text('How are you feeling?'),
        backgroundColor: MomUi.surface,
        foregroundColor: MomUi.pink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tap a mood that fits best right now. You can add a short note below.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Optional note',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _moods.map((m) {
              return ActionChip(
                avatar: Text(m.emoji, style: const TextStyle(fontSize: 18)),
                label: Text(m.label),
                onPressed: _saving ? null : () => _submit(m.code),
              );
            }).toList(),
          ),
          if (_saving) const Padding(
            padding: EdgeInsets.only(top: 24),
            child: const Center(child: CircularProgressIndicator(color: MomUi.pink)),
          ),
        ],
      ),
    );
  }
}
