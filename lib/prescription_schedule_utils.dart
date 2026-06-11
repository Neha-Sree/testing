import 'dart:convert';

/// One logical dose slot for a prescription row (custom JSON or inferred from frequency).
class PrescriptionDoseSlot {
  const PrescriptionDoseSlot({
    required this.prescription,
    required this.doseId,
    required this.label,
    required this.timing,
  });

  final Map<String, dynamic> prescription;
  final String doseId;
  final String label;
  final String timing;

  int get prescriptionId => prescription['id'] as int;
}

int inferDosesPerDay(String? frequency) {
  final f = (frequency ?? '').toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ');
  if (f.contains('qid') ||
      f.contains('four time') ||
      f.contains('4 time') ||
      f.contains('4x daily') ||
      f.contains('4 x')) {
    return 4;
  }
  if (f.contains('tid') ||
      f.contains('three time') ||
      f.contains('3 time') ||
      f.contains('3x daily') ||
      f.contains('3 x')) {
    return 3;
  }
  if (f.contains('bid') ||
      f.contains('twice') ||
      f.contains('2 time') ||
      f.contains('2x daily') ||
      f.contains('2 x') ||
      f.contains('two time')) {
    return 2;
  }
  final m = RegExp(r'\b([2-4])\s*time').firstMatch(f);
  if (m != null) {
    return int.tryParse(m.group(1)!) ?? 1;
  }
  return 1;
}

String _humanDoseIndex(int i) {
  switch (i) {
    case 0:
      return 'First dose';
    case 1:
      return 'Second dose';
    case 2:
      return 'Third dose';
    case 3:
      return 'Fourth dose';
    default:
      return 'Dose ${i + 1}';
  }
}

String _periodLabel(String key) {
  switch (key) {
    case 'breakfast':
      return 'Breakfast';
    case 'lunch':
      return 'Lunch';
    case 'dinner':
      return 'Dinner';
    case 'morning':
      return 'Morning';
    case 'afternoon':
      return 'Afternoon';
    case 'evening':
      return 'Evening';
    case 'night':
      return 'Night';
    case 'bedtime':
      return 'Bedtime';
    default:
      if (key.startsWith('dose_')) return key.replaceAll('_', ' ').toUpperCase();
      return key;
  }
}

/// Expand backend prescription JSON into per-dose UI rows.
List<PrescriptionDoseSlot> expandPrescriptionDoses(Map<String, dynamic> p) {
  final raw = p['dose_schedule_json'];
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final doses = map['doses'];
      if (doses is List && doses.isNotEmpty) {
        final out = <PrescriptionDoseSlot>[];
        for (var i = 0; i < doses.length; i++) {
          final d = doses[i];
          if (d is! Map) continue;
          var id = '${d['id'] ?? ''}'.trim().toLowerCase();
          if (id.isEmpty) {
            id = 'dose_$i';
          }
          final label = '${d['label'] ?? _periodLabel(id)}'.trim();
          final timing = '${d['timing'] ?? p['timing'] ?? 'before_food'}';
          out.add(PrescriptionDoseSlot(prescription: p, doseId: id, label: label, timing: timing));
        }
        if (out.isNotEmpty) {
          return out;
        }
      }
    } catch (_) {
      // fall through
    }
  }

  final n = inferDosesPerDay(p['frequency'] as String?);
  final baseTiming = '${p['timing'] ?? 'before_food'}';
  final meal = '${p['meal_time'] ?? 'breakfast'}'.toLowerCase();
  if (n <= 1) {
    return [
      PrescriptionDoseSlot(
        prescription: p,
        doseId: meal,
        label: _periodLabel(meal),
        timing: baseTiming,
      ),
    ];
  }
  return List.generate(
    n,
    (i) => PrescriptionDoseSlot(
      prescription: p,
      doseId: 'dose_$i',
      label: _humanDoseIndex(i),
      timing: baseTiming,
    ),
  );
}

String formatTimingLabel(String timing) {
  switch (timing) {
    case 'before_food':
      return 'Before food';
    case 'after_food':
      return 'After food';
    case 'with_food':
      return 'With food';
    default:
      return timing;
  }
}
