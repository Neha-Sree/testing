/// Shared pregnancy symptom options for home chips and symptom check-in.
class MotherSymptomChoice {
  const MotherSymptomChoice({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.severity,
    this.shortLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final String severity; // green | yellow | red | critical
  final String? shortLabel;

  String get chipLabel => shortLabel ?? title;
}

const motherSymptomChoices = <MotherSymptomChoice>[
  MotherSymptomChoice(
    id: 'swelling',
    title: 'Sudden swelling of face, hands, or eyes',
    shortLabel: 'Swelling',
    subtitle: 'Possible pre-eclampsia — needs prompt review',
    severity: 'red',
  ),
  MotherSymptomChoice(
    id: 'headache',
    title: 'Severe or persistent headache',
    shortLabel: 'Headache',
    subtitle: 'Especially with vision changes',
    severity: 'red',
  ),
  MotherSymptomChoice(
    id: 'vision',
    title: 'Vision changes (blurry, spots, flashing lights)',
    shortLabel: 'Vision',
    subtitle: 'Urgent assessment',
    severity: 'red',
  ),
  MotherSymptomChoice(
    id: 'bleeding',
    title: 'Heavy bleeding or clots from vagina',
    shortLabel: 'Bleeding',
    subtitle: 'Emergency',
    severity: 'critical',
  ),
  MotherSymptomChoice(
    id: 'waters',
    title: 'Fluid gush / possible waters broken',
    shortLabel: 'Waters',
    subtitle: 'Call maternity line or go in',
    severity: 'red',
  ),
  MotherSymptomChoice(
    id: 'less_movement',
    title: 'Baby moving less than usual',
    shortLabel: 'Less movement',
    subtitle: 'Same-day fetal movement check',
    severity: 'red',
  ),
  MotherSymptomChoice(
    id: 'abdominal_pain',
    title: 'Severe abdominal pain',
    shortLabel: 'Abdominal pain',
    subtitle: 'Constant or worsening pain',
    severity: 'red',
  ),
  MotherSymptomChoice(
    id: 'breath',
    title: 'Chest pain or severe shortness of breath',
    shortLabel: 'Breath/chest',
    subtitle: 'Seek urgent care',
    severity: 'critical',
  ),
  MotherSymptomChoice(
    id: 'fever',
    title: 'Fever or chills',
    shortLabel: 'Fever',
    subtitle: 'Temperature feeling high',
    severity: 'yellow',
  ),
  MotherSymptomChoice(
    id: 'ankle_swelling',
    title: 'Mild ankle or foot swelling only',
    shortLabel: 'Ankle swelling',
    subtitle: 'Common; still mention at next visit',
    severity: 'green',
  ),
  MotherSymptomChoice(
    id: 'nausea',
    title: 'Nausea / vomiting (usual pregnancy)',
    shortLabel: 'Nausea',
    subtitle: 'Hydration and small meals',
    severity: 'green',
  ),
];
