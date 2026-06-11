import 'package:shared_preferences/shared_preferences.dart';

/// Pregnancy vaccine / visit checklist for the mother (local tracker).
class MotherVaccineCheckItem {
  const MotherVaccineCheckItem({
    required this.id,
    required this.label,
    required this.hint,
  });

  final String id;
  final String label;
  final String hint;
}

const motherVaccineChecklist = <MotherVaccineCheckItem>[
  MotherVaccineCheckItem(
    id: 'booking_bloods',
    label: 'Booking blood tests',
    hint: 'Usually at first antenatal visit',
  ),
  MotherVaccineCheckItem(
    id: 'flu',
    label: 'Influenza vaccine',
    hint: 'Recommended in pregnancy (seasonal)',
  ),
  MotherVaccineCheckItem(
    id: 'tdap',
    label: 'Whooping cough (Tdap)',
    hint: 'Often given around 27–36 weeks',
  ),
  MotherVaccineCheckItem(
    id: 'gdm_screen',
    label: 'Gestational diabetes screen',
    hint: 'Timing per your clinic schedule',
  ),
  MotherVaccineCheckItem(
    id: 'gbs',
    label: 'Group B strep swab',
    hint: 'Often around 36–37 weeks if offered',
  ),
  MotherVaccineCheckItem(
    id: 'covid',
    label: 'COVID-19 vaccine (if advised)',
    hint: 'Follow national guidance',
  ),
];

Future<Set<String>> loadMotherVaccineChecks(String patientId) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'mother_vaccine_checks_${patientId.trim().toUpperCase()}';
  return (prefs.getStringList(key) ?? []).toSet();
}

Future<void> saveMotherVaccineChecks(String patientId, Set<String> done) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'mother_vaccine_checks_${patientId.trim().toUpperCase()}';
  await prefs.setStringList(key, done.toList());
}
