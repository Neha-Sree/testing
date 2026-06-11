import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/health_worker_models.dart';
import '../services/health_worker_api_service.dart';
import 'extracted_report_values.dart';
import 'risk_chip.dart';

class VitalSignsEntryScreen extends StatefulWidget {
  const VitalSignsEntryScreen({
    super.key,
    required this.patientId,
    required this.workerId,
    this.initial,
  });

  final String patientId;
  final String workerId;
  final ExtractedReportValues? initial;

  @override
  State<VitalSignsEntryScreen> createState() => _VitalSignsEntryScreenState();
}

class _VitalSignsEntryScreenState extends State<VitalSignsEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  final _hr = TextEditingController();
  final _sugar = TextEditingController();
  final _temp = TextEditingController();
  final _spo2 = TextEditingController();
  final _notes = TextEditingController();

  String? _fetalMovement; // normal | reduced | none
  String? _swelling; // none | feet_mild | face_hands_sudden

  bool _saving = false;
  RiskAssessment? _newRisk;
  final _api = HealthWorkerApiService();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial.hasVitals) {
      initial.applyToVitals(
        setWeight: (v) => _weight.text = v,
        setSys: (v) => _sys.text = v,
        setDia: (v) => _dia.text = v,
        setHr: (v) => _hr.text = v,
        setSugar: (v) => _sugar.text = v,
        setTemp: (v) => _temp.text = v,
        setSpo2: (v) => _spo2.text = v,
        setFetalMovement: (v) => _fetalMovement = v,
        setNotes: (v) {
          if (_notes.text.trim().isEmpty) _notes.text = v;
        },
      );
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _sys.dispose();
    _dia.dispose();
    _hr.dispose();
    _sugar.dispose();
    _temp.dispose();
    _spo2.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _anyFilled() =>
      [_weight, _sys, _dia, _hr, _sugar, _temp, _spo2].any((c) => c.text.trim().isNotEmpty) ||
      (_fetalMovement != null && _fetalMovement!.isNotEmpty) ||
      (_swelling != null && _swelling!.isNotEmpty);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_anyFilled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one measurement.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final risk = await _api.recordVitalSigns(
        patientId: widget.patientId,
        weightKg: double.tryParse(_weight.text.trim()),
        bpSystolic: int.tryParse(_sys.text.trim()),
        bpDiastolic: int.tryParse(_dia.text.trim()),
        heartRateBpm: int.tryParse(_hr.text.trim()),
        bloodSugar: double.tryParse(_sugar.text.trim()),
        temperatureCelsius: double.tryParse(_temp.text.trim()),
        oxygenSaturation: double.tryParse(_spo2.text.trim()),
        fetalMovement: _fetalMovement,
        swelling: _swelling,
        measuredBy: widget.workerId,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      setState(() => _newRisk = risk);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vitals saved. Risk: ${risk.level.name.toUpperCase()}')),
      );
    } on HealthWorkerApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromReport = widget.initial?.hasVitals == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: Colors.pink.shade400,
        foregroundColor: Colors.white,
        title: const Text('Enter vital signs'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (fromReport)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pink.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.pink.shade400, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Values pre-filled from uploaded report. Review and save.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_pin, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text('Patient: ${widget.patientId}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _NumField(controller: _weight, label: 'Weight (kg)', icon: Icons.monitor_weight, decimal: true),
            _Row2(
              left: _NumField(controller: _sys, label: 'BP systolic', icon: Icons.favorite),
              right: _NumField(controller: _dia, label: 'BP diastolic', icon: Icons.favorite_border),
            ),
            _Row2(
              left: _NumField(controller: _hr, label: 'Pulse (bpm)', icon: Icons.monitor_heart),
              right: _NumField(
                controller: _sugar,
                label: 'Fasting glucose (mg/dL)',
                icon: Icons.water_drop,
                decimal: true,
              ),
            ),
            _Row2(
              left: _NumField(controller: _temp, label: 'Temperature (\u00b0C)', icon: Icons.thermostat, decimal: true),
              right: _NumField(controller: _spo2, label: 'SpO2 (%)', icon: Icons.air, decimal: true),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String?>(
              value: _fetalMovement,
              decoration: const InputDecoration(
                labelText: 'Fetal movement',
                prefixIcon: Icon(Icons.child_care_outlined),
              ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('Not assessed')),
                DropdownMenuItem<String?>(value: 'normal', child: Text('Normal movement')),
                DropdownMenuItem<String?>(value: 'reduced', child: Text('Reduced movement')),
                DropdownMenuItem<String?>(value: 'none', child: Text('No movement')),
              ],
              onChanged: (v) => setState(() => _fetalMovement = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _swelling,
              decoration: const InputDecoration(
                labelText: 'Swelling',
                prefixIcon: Icon(Icons.accessibility_new),
              ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('Not assessed')),
                DropdownMenuItem<String?>(value: 'none', child: Text('No notable swelling')),
                DropdownMenuItem<String?>(value: 'feet_mild', child: Text('Mild feet / ankle swelling')),
                DropdownMenuItem<String?>(
                  value: 'face_hands_sudden',
                  child: Text('Sudden face or hand swelling'),
                ),
              ],
              onChanged: (v) => setState(() => _swelling = v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save vitals'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.pink.shade500,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_newRisk != null) ...[
              const SizedBox(height: 16),
              _RiskOutcome(risk: _newRisk!),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.decimal = false,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: (v) {
          final s = (v ?? '').trim();
          if (s.isEmpty) return null;
          final n = double.tryParse(s);
          if (n == null || n < 0) return 'Invalid number';
          return null;
        },
      ),
    );
  }
}

class _Row2 extends StatelessWidget {
  const _Row2({required this.left, required this.right});
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) {
    return Row(children: [Expanded(child: left), const SizedBox(width: 10), Expanded(child: right)]);
  }
}

class _RiskOutcome extends StatelessWidget {
  const _RiskOutcome({required this.risk});
  final RiskAssessment risk;

  @override
  Widget build(BuildContext context) {
    final c = RiskColors.of(risk.level);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.bg.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Updated risk:', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              RiskChip(level: risk.level),
            ],
          ),
          const SizedBox(height: 10),
          if (risk.reasons.isEmpty)
            const Text('No abnormalities detected.')
          else
            ...risk.reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('• $r'),
              ),
            ),
        ],
      ),
    );
  }
}
