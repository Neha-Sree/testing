import 'package:flutter/material.dart';

import '../../doctor_pills_screen.dart';

class PrescriptionsSection extends StatelessWidget {
  const PrescriptionsSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context) {
    return buildPrescriptionsContent(doctorId: doctorId);
  }
}
