import 'package:flutter/material.dart';

import 'health_worker/assign_mother_dialog.dart';
import 'health_worker/health_worker_theme.dart';
import 'health_worker/hw_patient_detail_screen.dart';
import 'health_worker/risk_chip.dart';
import 'models/health_worker_models.dart';
import 'services/health_worker_api_service.dart';

class HealthWorkerDashboardScreen extends StatefulWidget {
  const HealthWorkerDashboardScreen({super.key, required this.workerId, this.workerName});

  final String workerId;
  final String? workerName;

  @override
  State<HealthWorkerDashboardScreen> createState() => _HealthWorkerDashboardScreenState();
}

class _HealthWorkerDashboardScreenState extends State<HealthWorkerDashboardScreen> {
  final _api = HealthWorkerApiService();

  late Future<List<AssignedMother>> _mothersFuture;
  String _filter = 'all'; // all | high | yellow | green

  @override
  void initState() {
    super.initState();
    _ensureRegistered();
    _mothersFuture = _api.fetchAssignedMothers(widget.workerId);
  }

  Future<void> _ensureRegistered() async {
    try {
      final existing = await _api.fetchHealthWorker(widget.workerId);
      if (existing == null) {
        await _api.upsertHealthWorker(
          workerId: widget.workerId,
          fullName: widget.workerName ?? 'Health Worker',
        );
      }
    } catch (_) {
      // Soft fail — the dashboard still loads with assigned-mother list.
    }
  }

  Future<void> _reload() async {
    setState(() {
      _mothersFuture = _api.fetchAssignedMothers(widget.workerId);
    });
    await _mothersFuture;
  }

  Future<void> _openAssignDialog() async {
    final patientId = await showDialog<String>(
      context: context,
      builder: (_) => const AssignMotherDialog(),
    );
    if (patientId == null || patientId.isEmpty) return;
    try {
      await _api.assignMother(workerId: widget.workerId, patientId: patientId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mother $patientId assigned to you')),
        );
      }
      await _reload();
    } on HealthWorkerApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    }
  }

  List<AssignedMother> _applyFilter(List<AssignedMother> mothers) {
    switch (_filter) {
      case 'high':
        return mothers
            .where((m) => m.risk.level == RiskLevel.red || m.risk.level == RiskLevel.critical)
            .toList(growable: false);
      case 'yellow':
        return mothers.where((m) => m.risk.level == RiskLevel.yellow).toList(growable: false);
      case 'green':
        return mothers.where((m) => m.risk.level == RiskLevel.green).toList(growable: false);
      default:
        return mothers;
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = widget.workerName == null || widget.workerName!.isEmpty
        ? 'Health Worker'
        : widget.workerName!;
    return Scaffold(
      backgroundColor: HwTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: HwTheme.primary,
          onRefresh: _reload,
          child: FutureBuilder<List<AssignedMother>>(
            future: _mothersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: HwTheme.primary));
              }
              if (snapshot.hasError) {
                return _ErrorView(
                  message: snapshot.error.toString(),
                  onRetry: _reload,
                );
              }
              final mothers = snapshot.data ?? const <AssignedMother>[];
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _HeroBanner(greeting: greeting, workerId: widget.workerId),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _StatsRow(mothers: mothers),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: _FilterChips(
                        current: _filter,
                        onChanged: (v) => setState(() => _filter = v),
                      ),
                    ),
                  ),
                  if (mothers.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else
                    SliverList.builder(
                      itemCount: _applyFilter(mothers).length,
                      itemBuilder: (context, index) {
                        final list = _applyFilter(mothers);
                        return _MotherCard(
                          mother: list[index],
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HwPatientDetailScreen(
                                  workerId: widget.workerId,
                                  patient: list[index],
                                ),
                              ),
                            );
                            _reload();
                          },
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: HwTheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Assign mother'),
        onPressed: _openAssignDialog,
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.greeting, required this.workerId});
  final String greeting;
  final String workerId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: HwTheme.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: HwTheme.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $greeting 👋',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Community care · Field visits · Risk monitoring',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    workerId,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.health_and_safety_outlined, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.mothers});
  final List<AssignedMother> mothers;

  @override
  Widget build(BuildContext context) {
    final highRisk = mothers
        .where((m) => m.risk.level == RiskLevel.red || m.risk.level == RiskLevel.critical)
        .length;
    final moderate = mothers.where((m) => m.risk.level == RiskLevel.yellow).length;
    final healthy = mothers.where((m) => m.risk.level == RiskLevel.green).length;

    return Row(
      children: [
        _StatTile(
          icon: Icons.pregnant_woman,
          label: 'Assigned',
          value: '${mothers.length}',
          color: Colors.green.shade600,
        ),
        const SizedBox(width: 8),
        _StatTile(
          icon: Icons.warning_amber_rounded,
          label: 'High risk',
          value: '$highRisk',
          color: Colors.red.shade600,
        ),
        const SizedBox(width: 8),
        _StatTile(
          icon: Icons.error_outline,
          label: 'Moderate',
          value: '$moderate',
          color: Colors.amber.shade800,
        ),
        const SizedBox(width: 8),
        _StatTile(
          icon: Icons.favorite,
          label: 'Healthy',
          value: '$healthy',
          color: Colors.teal.shade600,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.75), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.current, required this.onChanged});
  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('all', 'All'),
      ('high', 'High risk'),
      ('yellow', 'Moderate'),
      ('green', 'Healthy'),
    ];
    final colors = {
      'all': HwTheme.primary,
      'high': Colors.red.shade700,
      'yellow': Colors.amber.shade800,
      'green': HwTheme.accent,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, label) in items)
          FilterChip(
            label: Text(label, style: const TextStyle(fontSize: 13)),
            selected: current == id,
            onSelected: (_) => onChanged(id),
            selectedColor: (colors[id] ?? HwTheme.primary).withValues(alpha: 0.18),
            checkmarkColor: colors[id] ?? HwTheme.primary,
            backgroundColor: HwTheme.surface,
            side: BorderSide(
              color: current == id ? (colors[id] ?? HwTheme.primary) : HwTheme.border,
            ),
          ),
      ],
    );
  }
}

class _MotherCard extends StatelessWidget {
  const _MotherCard({required this.mother, required this.onTap});
  final AssignedMother mother;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isHigh = mother.risk.level == RiskLevel.red || mother.risk.level == RiskLevel.critical;
    final riskColor = RiskColors.of(mother.risk.level).bg;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: HwTheme.softCard(),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 52,
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: HwTheme.primary.withValues(alpha: 0.12),
                    child: Text(
                      _initials(mother.fullName),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: HwTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mother.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${mother.patientId} • '
                          '${mother.pregnantWeeks == null ? '—' : '${mother.pregnantWeeks} wks'}'
                          '${mother.age != null ? ' • ${mother.age}y' : ''}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  RiskChip(level: mother.risk.level),
                ],
              ),
              if (isHigh && mother.risk.reasons.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final reason in mother.risk.reasons.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 3, right: 6),
                                child: Icon(Icons.priority_high, size: 14, color: Colors.red),
                              ),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pregnant_woman, size: 72, color: HwTheme.primary.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          const Text(
            'No mothers assigned yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "Assign mother" below to start managing pregnancies.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: HwTheme.primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
