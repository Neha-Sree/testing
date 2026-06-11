import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/health_worker_models.dart';
import '../services/health_worker_api_service.dart';
import 'health_worker_theme.dart';
import 'home_visit_form_screen.dart';
import 'lab_test_entry_screen.dart';
import 'fetal_growth_entry_screen.dart';
import 'report_upload_screen.dart';
import 'risk_chip.dart';
import 'vital_signs_entry_screen.dart';

/// Detail screen for a single assigned mother, showing risk, recent visits,
/// labs, and quick-action buttons for the health worker.
class HwPatientDetailScreen extends StatefulWidget {
  const HwPatientDetailScreen({super.key, required this.workerId, required this.patient});

  final String workerId;
  final AssignedMother patient;

  @override
  State<HwPatientDetailScreen> createState() => _HwPatientDetailScreenState();
}

class _HwPatientDetailScreenState extends State<HwPatientDetailScreen> {
  final _api = HealthWorkerApiService();
  late Future<_PatientDetailBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PatientDetailBundle> _load() async {
    final pid = widget.patient.patientId;
    final results = await Future.wait([
      _api.fetchPatientRisk(pid),
      _api.fetchPatientVisits(pid),
      _api.fetchLabTests(pid),
      _api.fetchReports(pid),
    ]);
    return _PatientDetailBundle(
      risk: results[0] as RiskAssessment,
      visits: results[1] as List<HomeVisit>,
      labs: results[2] as List<LabTest>,
      reports: results[3] as List<PatientReport>,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return Scaffold(
      backgroundColor: HwTheme.background,
      body: RefreshIndicator(
        color: HwTheme.primary,
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<_PatientDetailBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: HwTheme.primary));
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(snapshot.error.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _reload,
                        style: FilledButton.styleFrom(backgroundColor: HwTheme.primary),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final bundle = snapshot.data!;
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  backgroundColor: HwTheme.primary,
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(gradient: HwTheme.heroGradient),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(56, 8, 16, 16),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              p.fullName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    child: Column(
                      children: [
                _PatientHeader(patient: p, risk: bundle.risk),
                const SizedBox(height: 16),
                _ActionGrid(
                  onVitals: () => _open(VitalSignsEntryScreen(
                    patientId: p.patientId,
                    workerId: widget.workerId,
                  )),
                  onLab: () => _open(LabTestEntryScreen(
                    patientId: p.patientId,
                    workerId: widget.workerId,
                  )),
                  onFetal: () => _open(FetalGrowthEntryScreen(
                    patientId: p.patientId,
                    workerId: widget.workerId,
                    pregnantWeeks: p.pregnantWeeks,
                  )),
                  onVisit: () => _open(HomeVisitFormScreen(
                    patientId: p.patientId,
                    workerId: widget.workerId,
                  )),
                  onReport: () => _open(ReportUploadScreen(
                    patientId: p.patientId,
                    workerId: widget.workerId,
                    pregnantWeeks: p.pregnantWeeks,
                  )),
                ),
                const SizedBox(height: 16),
                _RiskCard(risk: bundle.risk),
                const SizedBox(height: 16),
                _SectionTitle(icon: Icons.home_work_outlined, label: 'Recent home visits'),
                if (bundle.visits.isEmpty)
                  const _EmptyTile(text: 'No visits recorded yet')
                else
                  ...bundle.visits.take(5).map(_VisitTile.new),
                const SizedBox(height: 16),
                _SectionTitle(icon: Icons.science_outlined, label: 'Recent lab tests'),
                if (bundle.labs.isEmpty)
                  const _EmptyTile(text: 'No lab tests on file')
                else
                  ...bundle.labs.take(5).map(_LabTile.new),
                const SizedBox(height: 16),
                _SectionTitle(icon: Icons.folder_outlined, label: 'Reports'),
                if (bundle.reports.isEmpty)
                  const _EmptyTile(text: 'No reports uploaded')
                else
                  ...bundle.reports.take(5).map(_ReportTile.new),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PatientDetailBundle {
  _PatientDetailBundle({
    required this.risk,
    required this.visits,
    required this.labs,
    required this.reports,
  });
  final RiskAssessment risk;
  final List<HomeVisit> visits;
  final List<LabTest> labs;
  final List<PatientReport> reports;
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patient, required this.risk});
  final AssignedMother patient;
  final RiskAssessment risk;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return HwSoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: HwTheme.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.pregnant_woman, color: HwTheme.primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient.patientId,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              RiskChip(level: risk.level),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(icon: Icons.cake_outlined, text: patient.age == null ? 'Age —' : '${patient.age} y'),
              _Pill(
                icon: Icons.timer_outlined,
                text: patient.pregnantWeeks == null ? 'Wks —' : '${patient.pregnantWeeks} wks',
              ),
              _Pill(
                icon: Icons.calendar_today_outlined,
                text: patient.dueDate == null ? 'Due —' : df.format(patient.dueDate!),
              ),
              if (patient.bloodGroup != null && patient.bloodGroup!.isNotEmpty)
                _Pill(icon: Icons.bloodtype_outlined, text: patient.bloodGroup!),
              if (patient.doctorId != null && patient.doctorId!.isNotEmpty)
                _Pill(icon: Icons.medical_services_outlined, text: 'Dr ${patient.doctorId}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HwTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HwTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: HwTheme.primary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: HwTheme.text)),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onVitals,
    required this.onLab,
    required this.onFetal,
    required this.onVisit,
    required this.onReport,
  });
  final VoidCallback onVitals;
  final VoidCallback onLab;
  final VoidCallback onFetal;
  final VoidCallback onVisit;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.35,
      children: [
        _ActionBtn(
          color: Colors.pink.shade400,
          icon: Icons.favorite_outline,
          label: 'Enter vitals',
          onTap: onVitals,
        ),
        _ActionBtn(
          color: Colors.deepPurple.shade400,
          icon: Icons.science_outlined,
          label: 'Lab test',
          onTap: onLab,
        ),
        _ActionBtn(
          color: Colors.purple.shade600,
          icon: Icons.child_care,
          label: 'Fetal growth',
          onTap: onFetal,
        ),
        _ActionBtn(
          color: Colors.teal.shade600,
          icon: Icons.home_work_outlined,
          label: 'Home visit',
          onTap: onVisit,
        ),
        _ActionBtn(
          color: Colors.orange.shade700,
          icon: Icons.upload_file_outlined,
          label: 'Upload report',
          onTap: onReport,
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.color, required this.icon, required this.label, required this.onTap});
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.risk});
  final RiskAssessment risk;

  @override
  Widget build(BuildContext context) {
    final colors = RiskColors.of(risk.level);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.bg.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: colors.bg),
              const SizedBox(width: 8),
              const Text(
                'Risk assessment',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              RiskChip(level: risk.level),
            ],
          ),
          const SizedBox(height: 10),
          if (risk.reasons.isEmpty)
            const Text('No abnormalities detected.', style: TextStyle(color: Colors.black54))
          else
            ...risk.reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.fiber_manual_record, size: 10, color: colors.bg),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green.shade800),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.green.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile(this.visit);
  final HomeVisit visit;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    final isCompleted = visit.status == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted ? Colors.green.shade100 : Colors.amber.shade100,
          child: Icon(
            isCompleted ? Icons.check : Icons.event_note,
            color: isCompleted ? Colors.green.shade700 : Colors.amber.shade800,
          ),
        ),
        title: Text(df.format(visit.scheduledDate)),
        subtitle: Text(
          [
            visit.status.toUpperCase(),
            if (visit.observations != null && visit.observations!.isNotEmpty) visit.observations!,
            if (visit.address != null && visit.address!.isNotEmpty) visit.address!,
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: visit.gpsLat != null && visit.gpsLon != null
            ? Icon(Icons.location_on, color: Colors.green.shade700)
            : null,
      ),
    );
  }
}

class _LabTile extends StatelessWidget {
  const _LabTile(this.lab);
  final LabTest lab;

  @override
  Widget build(BuildContext context) {
    final summary = <String>[
      if (lab.hemoglobin != null) 'Hb ${lab.hemoglobin}',
      if (lab.bloodSugarFasting != null) 'FBS ${lab.bloodSugarFasting}',
      if (lab.bloodSugarPost != null) 'PPBS ${lab.bloodSugarPost}',
      if (lab.urineProtein != null && lab.urineProtein!.isNotEmpty)
        'Urine prot ${lab.urineProtein}',
      if (lab.urineSugar != null && lab.urineSugar!.isNotEmpty)
        'Urine sug ${lab.urineSugar}',
      if (lab.thyroidTsh != null) 'TSH ${lab.thyroidTsh}',
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.shade50,
          child: Icon(Icons.science, color: Colors.deepPurple.shade700),
        ),
        title: Text(DateFormat.yMMMd().format(lab.testDate)),
        subtitle: Text(
          summary.isEmpty ? 'No measurements recorded' : summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile(this.report);
  final PatientReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade50,
          child: Icon(Icons.description, color: Colors.orange.shade700),
        ),
        title: Text(report.fileName),
        subtitle: Text(
          '${report.reportType.toUpperCase()} • ${report.createdAt == null ? '' : DateFormat.yMMMd().format(report.createdAt!)}',
        ),
      ),
    );
  }
}
