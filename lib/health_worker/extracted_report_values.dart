/// Parsed lab / vitals / fetal sections from report AI extraction.
class ExtractedReportValues {
  const ExtractedReportValues({
    this.lab = const {},
    this.vitals = const {},
    this.fetal = const {},
  });

  final Map<String, dynamic> lab;
  final Map<String, dynamic> vitals;
  final Map<String, dynamic> fetal;

  factory ExtractedReportValues.fromExtraction(Map<String, dynamic> extraction) {
    final extracted = extraction['extracted'];
    if (extracted is! Map) {
      return const ExtractedReportValues();
    }
    Map<String, dynamic> section(dynamic key) {
      final value = extracted[key];
      if (value is Map) return value.cast<String, dynamic>();
      return {};
    }

    return ExtractedReportValues(
      lab: section('lab_values'),
      vitals: section('vital_values'),
      fetal: section('fetal_values'),
    );
  }

  bool get hasLab => _hasAny(lab, [
        'hemoglobin',
        'blood_sugar',
        'blood_sugar_fasting',
        'blood_sugar_post',
        'urine_sugar',
        'urine_protein',
        'thyroid_tsh',
        'iron_level',
        'calcium_level',
        'infection_indicators',
        'femur_length_cm',
        'head_circumference_cm',
      ]);

  bool get hasVitals => _hasAny(vitals, [
        'bp_systolic',
        'bp_diastolic',
        'pulse',
        'temperature',
        'oxygen_level',
        'weight_kg',
        'bmi',
      ]) ||
      (fetal['fetal_movement'] != null && '${fetal['fetal_movement']}'.trim().isNotEmpty);

  bool get hasFetal => _hasAny(fetal, [
        'fetal_heartbeat',
        'fetal_weight_g',
        'head_circumference_cm',
        'femur_length_cm',
        'amniotic_fluid_level',
        'placenta_status',
        'growth_percentile',
      ]);

  static bool _hasAny(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v != null && '$v'.trim().isNotEmpty) return true;
    }
    return false;
  }

  static String? _str(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  static double? _num(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v'.replaceAll(',', ''));
  }

  void applyToVitals({
    required void Function(String) setWeight,
    required void Function(String) setSys,
    required void Function(String) setDia,
    required void Function(String) setHr,
    required void Function(String) setSugar,
    required void Function(String) setTemp,
    required void Function(String) setSpo2,
    required void Function(String?) setFetalMovement,
    required void Function(String) setNotes,
  }) {
    final w = _num(vitals, 'weight_kg');
    if (w != null) setWeight(_fmt(w));
    final sys = _num(vitals, 'bp_systolic');
    if (sys != null) setSys(_fmt(sys, decimals: 0));
    final dia = _num(vitals, 'bp_diastolic');
    if (dia != null) setDia(_fmt(dia, decimals: 0));
    final pulse = _num(vitals, 'pulse');
    if (pulse != null) setHr(_fmt(pulse, decimals: 0));
    final sugar = _num(lab, 'blood_sugar_fasting') ??
        _num(lab, 'blood_sugar') ??
        _num(vitals, 'blood_sugar');
    if (sugar != null) setSugar(_fmt(sugar));
    final temp = _num(vitals, 'temperature');
    if (temp != null) setTemp(_fmt(temp));
    final spo2 = _num(vitals, 'oxygen_level');
    if (spo2 != null) setSpo2(_fmt(spo2));
    final movement = _str(fetal, 'fetal_movement');
    if (movement != null) {
      final normalized = movement.toLowerCase();
      if (normalized.contains('reduc')) {
        setFetalMovement('reduced');
      } else if (normalized.contains('none') || normalized.contains('absent')) {
        setFetalMovement('none');
      } else {
        setFetalMovement('normal');
      }
    }
    final bmi = _num(vitals, 'bmi');
    if (bmi != null) {
      setNotes('BMI from report: ${_fmt(bmi)}');
    }
  }

  void applyToLab({
    required void Function(String) setHb,
    required void Function(String) setFbs,
    required void Function(String) setPpbs,
    required void Function(String) setTsh,
    required void Function(String) setFerritin,
    required void Function(String) setCalcium,
    required void Function(String) setInfection,
    required void Function(String) setFemur,
    required void Function(String) setHc,
    required void Function(String) setUrineSugar,
    required void Function(String) setUrineProtein,
  }) {
    final hb = _num(lab, 'hemoglobin');
    if (hb != null) setHb(_fmt(hb));
    final fbs = _num(lab, 'blood_sugar_fasting') ?? _num(lab, 'blood_sugar');
    if (fbs != null) setFbs(_fmt(fbs));
    final ppbs = _num(lab, 'blood_sugar_post');
    if (ppbs != null) setPpbs(_fmt(ppbs));
    final tsh = _num(lab, 'thyroid_tsh');
    if (tsh != null) setTsh(_fmt(tsh));
    final iron = _num(lab, 'iron_level');
    if (iron != null) setFerritin(_fmt(iron));
    final calcium = _num(lab, 'calcium_level');
    if (calcium != null) setCalcium(_fmt(calcium));
    final infection = _str(lab, 'infection_indicators');
    if (infection != null) setInfection(infection);
    final femur = _num(fetal, 'femur_length_cm') ?? _num(lab, 'femur_length_cm');
    if (femur != null) setFemur(_fmt(femur));
    final hc = _num(fetal, 'head_circumference_cm') ?? _num(lab, 'head_circumference_cm');
    if (hc != null) setHc(_fmt(hc));
    final us = _str(lab, 'urine_sugar');
    if (us != null) setUrineSugar(_normalizeUrine(us));
    final up = _str(lab, 'urine_protein');
    if (up != null) setUrineProtein(_normalizeUrine(up));
  }

  void applyToFetal({
    required void Function(String) setWeight,
    required void Function(String) setHr,
    required void Function(String) setFemur,
    required void Function(String) setHc,
    required void Function(String) setAfi,
    required void Function(String) setNotes,
  }) {
    final weight = _num(fetal, 'fetal_weight_g');
    if (weight != null) setWeight(_fmt(weight, decimals: 0));
    final hr = _num(fetal, 'fetal_heartbeat');
    if (hr != null) setHr(_fmt(hr, decimals: 0));
    final femur = _num(fetal, 'femur_length_cm');
    if (femur != null) setFemur(_fmt(femur));
    final hc = _num(fetal, 'head_circumference_cm');
    if (hc != null) setHc(_fmt(hc));
    final afi = _num(fetal, 'amniotic_fluid_level');
    if (afi != null) setAfi(_fmt(afi));
    final notes = <String>[
      if (_str(fetal, 'placenta_status') != null) 'Placenta: ${_str(fetal, 'placenta_status')}',
      if (_num(fetal, 'growth_percentile') != null)
        'Growth percentile: ${_fmt(_num(fetal, 'growth_percentile')!)}',
      if (_str(fetal, 'fetal_movement') != null) 'Movement: ${_str(fetal, 'fetal_movement')}',
    ];
    if (notes.isNotEmpty) setNotes(notes.join('. '));
  }

  static String _fmt(num value, {int decimals = 1}) {
    if (decimals == 0) return value.round().toString();
    final text = value.toStringAsFixed(decimals);
    return text.replaceAll(RegExp(r'\.?0+$'), '');
  }

  static String _normalizeUrine(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('neg')) return 'neg';
    if (lower.contains('trace')) return 'trace';
    if (lower.contains('+++')) return '+++';
    if (lower.contains('++')) return '++';
    if (lower.contains('+')) return '+';
    return 'neg';
  }
}
