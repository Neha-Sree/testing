import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/health_worker_models.dart';
import '../services/health_worker_api_service.dart';
import 'extracted_report_values.dart';
import 'risk_chip.dart';

class LabTestEntryScreen extends StatefulWidget {
  const LabTestEntryScreen({
    super.key,
    required this.patientId,
    required this.workerId,
    this.initial,
  });

  final String patientId;
  final String workerId;
  final ExtractedReportValues? initial;

  @override
  State<LabTestEntryScreen> createState() => _LabTestEntryScreenState();
}

class _LabTestEntryScreenState extends State<LabTestEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hb = TextEditingController();
  final _fbs = TextEditingController();
  final _ppbs = TextEditingController();
  final _tsh = TextEditingController();
  final _ferritin = TextEditingController();
  final _calcium = TextEditingController();
  final _infection = TextEditingController();
  final _femur = TextEditingController();
  final _hc = TextEditingController();
  final _notes = TextEditingController();
  String _urineSugar = 'neg';
  String _urineProtein = 'neg';

  DateTime _testDate = DateTime.now();
  bool _saving = false;
  RiskAssessment? _newRisk;

  final _api = HealthWorkerApiService();

  static const _urineOptions = ['neg', 'trace', '+', '++', '+++'];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial.hasLab) {
      initial.applyToLab(
        setHb: (v) => _hb.text = v,
        setFbs: (v) => _fbs.text = v,
        setPpbs: (v) => _ppbs.text = v,
        setTsh: (v) => _tsh.text = v,
        setFerritin: (v) => _ferritin.text = v,
        setCalcium: (v) => _calcium.text = v,
        setInfection: (v) => _infection.text = v,
        setFemur: (v) => _femur.text = v,
        setHc: (v) => _hc.text = v,
        setUrineSugar: (v) => _urineSugar = v,
        setUrineProtein: (v) => _urineProtein = v,
      );
    }
  }

  @override
  void dispose() {
    _hb.dispose();
    _fbs.dispose();
    _ppbs.dispose();
    _tsh.dispose();
    _ferritin.dispose();
    _calcium.dispose();
    _infection.dispose();
    _femur.dispose();
    _hc.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _anyFilled() {
    if ([_hb, _fbs, _ppbs, _tsh, _ferritin, _calcium, _femur, _hc]
        .any((c) => c.text.trim().isNotEmpty)) {
      return true;
    }
    if (_urineSugar != 'neg' || _urineProtein != 'neg') return true;
    return _infection.text.trim().isNotEmpty;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _testDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _testDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_anyFilled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one lab measurement.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _api.createLabTest(
        patientId: widget.patientId,
        testDate: _testDate,
        measuredBy: widget.workerId,
        hemoglobin: double.tryParse(_hb.text.trim()),
        bloodSugarFasting: double.tryParse(_fbs.text.trim()),
        bloodSugarPost: double.tryParse(_ppbs.text.trim()),
        urineSugar: _urineSugar,
        urineProtein: _urineProtein,
        thyroidTsh: double.tryParse(_tsh.text.trim()),
        ironFerritin: double.tryParse(_ferritin.text.trim()),
        calcium: double.tryParse(_calcium.text.trim()),
        infectionNotes: _infection.text.trim().isEmpty ? null : _infection.text.trim(),
        femurLengthCm: double.tryParse(_femur.text.trim()),
        headCircumferenceCm: double.tryParse(_hc.text.trim()),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      setState(() => _newRisk = result.risk);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lab test saved. Risk: ${result.risk.level.name.toUpperCase()}')),
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
    final fromReport = widget.initial?.hasLab == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade500,
        foregroundColor: Colors.white,
        title: const Text('Enter lab results'),
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
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.deepPurple.shade500, size: 20),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.person_pin, color: Colors.deepPurple.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Patient: ${widget.patientId}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('${_testDate.year}-${_testDate.month.toString().padLeft(2, '0')}-${_testDate.day.toString().padLeft(2, '0')}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _Section('Blood'),
            _Field(controller: _hb, label: 'Hemoglobin (g/dL)', decimal: true),
            Row(children: [
              Expanded(child: _Field(controller: _fbs, label: 'Fasting sugar (mg/dL)', decimal: true)),
              const SizedBox(width: 10),
              Expanded(child: _Field(controller: _ppbs, label: 'Post-meal sugar (mg/dL)', decimal: true)),
            ]),
            const SizedBox(height: 8),
            const _Section('Urine'),
            Row(children: [
              Expanded(
                child: _UrineDropdown(
                  label: 'Urine sugar',
                  value: _urineSugar,
                  options: _urineOptions,
                  onChanged: (v) => setState(() => _urineSugar = v ?? 'neg'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _UrineDropdown(
                  label: 'Urine protein',
                  value: _urineProtein,
                  options: _urineOptions,
                  onChanged: (v) => setState(() => _urineProtein = v ?? 'neg'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            const _Section('Fetal (from scan, optional)'),
            Row(
              children: [
                Expanded(child: _Field(controller: _femur, label: 'Femur length (cm)', decimal: true)),
                const SizedBox(width: 10),
                Expanded(child: _Field(controller: _hc, label: 'Head circumference (cm)', decimal: true)),
              ],
            ),
            const SizedBox(height: 8),
            const _Section('Other'),
            _Field(controller: _tsh, label: 'Thyroid TSH (mIU/L)', decimal: true),
            _Field(controller: _ferritin, label: 'Iron / Ferritin (ng/mL)', decimal: true),
            _Field(controller: _calcium, label: 'Calcium (mg/dL)', decimal: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _infection,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Infection signs (optional)',
                prefixIcon: Icon(Icons.bug_report_outlined),
              ),
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
              label: const Text('Save lab results'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade500,
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

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.black54,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.decimal = false});
  final TextEditingController controller;
  final String label;
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
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          final s = (v ?? '').trim();
          if (s.isEmpty) return null;
          if (double.tryParse(s) == null) return 'Invalid number';
          return null;
        },
      ),
    );
  }
}

class _UrineDropdown extends StatelessWidget {
  const _UrineDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(growable: false),
        onChanged: onChanged,
      ),
    );
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
