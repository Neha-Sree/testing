import 'package:flutter/material.dart';

import 'services/mom_api_service.dart';

/// Today's personalised diet plan view for the mother.
///
/// Backed by `/diet/plan/today/{patient_id}` and `/diet/plan/complete-meal`.
/// Mothers can:
/// - See each of the 6 meal slots with name, portion, calories and tags
/// - Tap a meal to expand the full description
/// - Mark a meal as completed (mark-eaten)
/// - See today's nutrition score and water goal
/// - Force regenerate the plan
class MotherDietScreen extends StatefulWidget {
  const MotherDietScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<MotherDietScreen> createState() => _MotherDietScreenState();
}

class _MotherDietScreenState extends State<MotherDietScreen> {
  static const _slotOrder = <String>[
    'breakfast',
    'mid_morning',
    'lunch',
    'evening_snack',
    'dinner',
    'bedtime',
  ];

  static const _slotLabels = <String, String>{
    'breakfast': 'Breakfast',
    'mid_morning': 'Mid-morning snack',
    'lunch': 'Lunch',
    'evening_snack': 'Evening snack',
    'dinner': 'Dinner',
    'bedtime': 'Bedtime',
  };

  static const _slotIcons = <String, IconData>{
    'breakfast': Icons.wb_sunny,
    'mid_morning': Icons.local_cafe,
    'lunch': Icons.restaurant,
    'evening_snack': Icons.cake,
    'dinner': Icons.restaurant_menu,
    'bedtime': Icons.bedtime,
  };

  final MomApiService _api = MomApiService();
  late Future<Map<String, dynamic>> _planFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _planFuture = _api.fetchTodayDietPlan(widget.patientId);
  }

  Future<void> _reload() async {
    setState(() {
      _planFuture = _api.fetchTodayDietPlan(widget.patientId);
    });
  }

  Future<void> _regenerate() async {
    setState(() => _busy = true);
    try {
      await _api.regenerateDietPlan(widget.patientId);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fresh plan generated for today.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to regenerate: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }



  Future<void> _toggleMeal({
    required int planId,
    required String slot,
    required bool currentlyCompleted,
  }) async {
    setState(() => _busy = true);
    try {
      await _api.markMealComplete(
        planId: planId,
        slot: slot,
        completed: !currentlyCompleted,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update meal: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF26A69A);
    const surface = Color(0xFFF6FBF9);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: const Text('Today\'s Diet Plan'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Regenerate today\'s plan',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _regenerate,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _planFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error);
          }
          final plan = snapshot.data;
          if (plan == null) {
            return const Center(child: Text('No plan yet'));
          }
          return RefreshIndicator(
            onRefresh: _reload,
            color: primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildSummaryCard(plan, primary),
                const SizedBox(height: 12),
                if (plan['rationale'] != null &&
                    (plan['rationale'] as String).trim().isNotEmpty)
                  _buildRationaleCard(plan['rationale'] as String, primary),
                const SizedBox(height: 16),
                ..._slotOrder.map((slot) {
                  final meals = plan['meals'] as Map<String, dynamic>? ?? {};
                  final meal = meals[slot] as Map<String, dynamic>?;
                  return _buildMealCard(
                    slot: slot,
                    meal: meal ?? const {'name': '—'},
                    planId: plan['id'] as int,
                    primary: primary,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not load your plan.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _reload, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> plan, Color primary) {
    final score = (plan['score'] is Map)
        ? (plan['score']['score'] as num?)?.toInt() ?? 0
        : 0;
    final calories = (plan['daily_calories'] as num?)?.toInt() ?? 0;
    final iron = (plan['daily_iron_mg'] as num?)?.toDouble() ?? 0;
    final calcium = (plan['daily_calcium_mg'] as num?)?.toDouble() ?? 0;
    final water = (plan['water_goal_ml'] as num?)?.toInt() ?? 2500;
    final trimester = plan['trimester'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trimester != null ? 'Trimester $trimester' : 'Pregnancy',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const Spacer(),
              const Icon(Icons.restaurant_menu, color: Colors.white, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Nutrition score: $score / 100',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat('Cal', '$calories', Icons.whatshot),
              _miniStat('Iron', '${iron.toStringAsFixed(1)}mg', Icons.flash_on),
              _miniStat('Ca', '${calcium.toStringAsFixed(0)}mg', Icons.spa),
              _miniStat(
                'Water',
                '${(water / 1000).toStringAsFixed(1)}L',
                Icons.local_drink,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRationaleCard(String rationale, Color primary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rationale,
              style: TextStyle(color: primary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard({
    required String slot,
    required Map<String, dynamic> meal,
    required int planId,
    required Color primary,
  }) {
    final completed = meal['completed'] as bool? ?? false;
    final name = (meal['name'] as String?) ?? '—';
    final description = meal['description'] as String?;
    final portion = meal['portion'] as String?;
    final calories = meal['calories'];
    final tags = (meal['tags'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: completed
              ? primary.withValues(alpha: 0.6)
              : Colors.grey.shade200,
          width: completed ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: primary.withValues(alpha: 0.12),
            child: Icon(
              _slotIcons[slot] ?? Icons.restaurant,
              color: primary,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _slotLabels[slot] ?? slot,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (calories != null)
                Text(
                  '$calories kcal',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                color: completed ? Colors.grey : Colors.black87,
                decoration: completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          trailing: IconButton(
            tooltip: completed ? 'Mark as not eaten' : 'Mark as eaten',
            icon: Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: completed ? primary : Colors.grey.shade400,
              size: 28,
            ),
            onPressed: _busy
                ? null
                : () => _toggleMeal(
                    planId: planId,
                    slot: slot,
                    currentlyCompleted: completed,
                  ),
          ),
          children: [
            if (portion != null && portion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.straighten,
                      color: Colors.grey.shade500,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      portion,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            if (description != null && description.isNotEmpty)
              Text(
                description,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        t.replaceAll('_', ' '),
                        style: TextStyle(color: primary, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }


}
