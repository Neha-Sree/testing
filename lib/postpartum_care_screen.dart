import 'package:flutter/material.dart';

import 'baby_vaccination_tracker_screen.dart';
import 'learning_center_screen.dart';
import 'mother_mood_screen.dart';
import 'services/mom_api_service.dart';

/// Postpartum hub: recovery tips, EPDS depression screening, and newborn record.
class PostpartumCareScreen extends StatefulWidget {
  const PostpartumCareScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<PostpartumCareScreen> createState() => _PostpartumCareScreenState();
}

// ─── EPDS Data ────────────────────────────────────────────────────────────────

class _EpdsQuestion {
  const _EpdsQuestion(this.text, this.options);
  final String text;
  final List<String> options; // index 0–3 maps to score 0–3
}

const _epdsQuestions = [
  _EpdsQuestion(
    'I have been able to laugh and see the funny side of things',
    ['As much as I always could', 'Not quite so much now', 'Definitely not so much now', 'Not at all'],
  ),
  _EpdsQuestion(
    'I have looked forward with enjoyment to things',
    ['As much as I ever did', 'Rather less than I used to', 'Definitely less than I used to', 'Hardly at all'],
  ),
  _EpdsQuestion(
    'I have blamed myself unnecessarily when things went wrong',
    ['No, never', 'Not very often', 'Yes, some of the time', 'Yes, most of the time'],
  ),
  _EpdsQuestion(
    'I have been anxious or worried for no good reason',
    ['No, not at all', 'Hardly ever', 'Yes, sometimes', 'Yes, very often'],
  ),
  _EpdsQuestion(
    'I have felt scared or panicky for no good reason',
    ['No, not at all', 'No, not much', 'Yes, sometimes', 'Yes, quite a lot'],
  ),
  _EpdsQuestion(
    'Things have been getting on top of me',
    [
      'No, I have been coping as well as ever',
      'No, most of the time I have coped quite well',
      'Yes, sometimes I have not been coping as well as usual',
      'Yes, most of the time I have been unable to cope at all',
    ],
  ),
  _EpdsQuestion(
    'I have been so unhappy that I have had difficulty sleeping',
    ['No, not at all', 'Not very often', 'Yes, sometimes', 'Yes, most of the time'],
  ),
  _EpdsQuestion(
    'I have felt sad or miserable',
    ['No, not at all', 'Not very often', 'Yes, quite often', 'Yes, most of the time'],
  ),
  _EpdsQuestion(
    'I have been so unhappy that I have been crying',
    ['No, never', 'Only occasionally', 'Yes, quite often', 'Yes, most of the time'],
  ),
  _EpdsQuestion(
    'The thought of harming myself has occurred to me',
    ['Never', 'Hardly ever', 'Sometimes', 'Yes, quite often'],
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class _PostpartumCareScreenState extends State<PostpartumCareScreen> {
  static const _pink = Color(0xFFF06292);

  final _api = MomApiService();
  late Future<Map<String, dynamic>?> _newbornFuture;

  // Mood
  String? _selectedMood;
  bool _savingMood = false;

  // EPDS
  bool _epdsStarted = false;
  bool _epdsCompleted = false;
  int _epdsPage = 0;
  final List<int?> _epdsAnswers = List<int?>.filled(_epdsQuestions.length, null);

  @override
  void initState() {
    super.initState();
    _newbornFuture = _loadNewborn();
  }

  Future<Map<String, dynamic>?> _loadNewborn() async {
    try {
      return await _api.getMotherNewborn(widget.patientId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveMood(String mood) async {
    setState(() {
      _selectedMood = mood;
      _savingMood = true;
    });
    try {
      await _api.logMotherMood(widget.patientId, mood: mood);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mood saved.')),
      );
    } on MomApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMood = false);
    }
  }

  int get _epdsScore => _epdsAnswers.whereType<int>().fold(0, (a, b) => a + b);

  void _submitEpds() {
    setState(() => _epdsCompleted = true);
    final score = _epdsScore;
    final q10 = _epdsAnswers[9] ?? 0;
    if (q10 >= 2 || score >= 13) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text('Please reach out now'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (q10 >= 2)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'You indicated thoughts of self-harm. Please contact your doctor, '
                    'a trusted person, or emergency services right away.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              if (q10 < 2) ...[
                Text(
                  'Your score ($score/30) suggests you may be experiencing postpartum depression.',
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is common and treatable. Please speak with your doctor as soon as possible.',
                  style: TextStyle(height: 1.4),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
              child: const Text('I understand'),
            ),
          ],
        ),
      );
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5FF),
      body: CustomScrollView(
        slivers: [
          _buildHeroAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRecoveryCards(),
                  const SizedBox(height: 24),
                  _buildMoodSection(),
                  const SizedBox(height: 24),
                  _buildEpdsSection(),
                  const SizedBox(height: 24),
                  _buildNewbornSection(),
                  const SizedBox(height: 24),
                  _buildCrisisCard(),
                  const SizedBox(height: 16),
                  _buildLearningButton(),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'For educational support only. Call emergency services for urgent situations.',
                      style: TextStyle(fontSize: 11, color: Colors.black38),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAppBar() {
    return SliverAppBar(
      expandedHeight: 190,
      pinned: true,
      backgroundColor: const Color(0xFF7B1FA2),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFAB47BC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Postpartum Hub',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Recovery · Emotional health · Baby care',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Recovery Cards ─────────────────────────────────────────────────────────

  Widget _buildRecoveryCards() {
    final cards = [
      (
        icon: Icons.bedtime_outlined,
        color: const Color(0xFF9C27B0),
        title: 'Rest & recovery',
        body: 'Sleep when your baby sleeps. Stay hydrated and eat regularly. '
            'Avoid heavy lifting and driving until cleared by your provider.',
      ),
      (
        icon: Icons.bloodtype_outlined,
        color: const Color(0xFFE53935),
        title: 'Bleeding & pain',
        body: 'Some cramping and lochia (bleeding) is normal. Seek urgent care if '
            'you soak more than one pad per hour, pass large clots, develop fever, '
            'or experience worsening pain.',
      ),
      (
        icon: Icons.child_care_outlined,
        color: const Color(0xFF00897B),
        title: 'Feeding your baby',
        body: 'Whether breast or bottle, focus on frequent feeds (8–12 times per day). '
            'Watch for wet nappies, jaundice signs, or poor latching — your nurse can help.',
      ),
      (
        icon: Icons.self_improvement_outlined,
        color: const Color(0xFF3949AB),
        title: 'Emotional wellbeing',
        body: 'Baby blues are very common in the first 2 weeks. If sadness, '
            'anxiety, or difficult thoughts persist beyond two weeks or feel '
            'overwhelming, please speak with your doctor — treatment works.',
      ),
    ];
    return Column(
      children: cards.map((c) => _infoCard(c)).toList(),
    );
  }

  Widget _infoCard(({IconData icon, Color color, String title, String body}) c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 90,
            decoration: BoxDecoration(
              color: c.color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(c.icon, color: c.color, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        c.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: c.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(c.body, style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF4A3550))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mood ────────────────────────────────────────────────────────────────────

  Widget _buildMoodSection() {
    return _sectionContainer(
      icon: Icons.sentiment_satisfied_alt_outlined,
      color: Colors.amber.shade700,
      title: 'How are you feeling right now?',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: MotherMoodScreen.quickMoods.map((m) {
          final selected = _selectedMood == m.code;
          return FilterChip(
            avatar: Text(m.emoji, style: const TextStyle(fontSize: 16)),
            label: Text(m.label, style: const TextStyle(fontSize: 13)),
            selected: selected,
            onSelected: _savingMood ? null : (_) => _saveMood(m.code),
            selectedColor: Colors.amber.withValues(alpha: 0.18),
            checkmarkColor: Colors.amber.shade800,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            side: BorderSide(color: selected ? Colors.amber.shade600 : Colors.grey.shade200),
          );
        }).toList(),
      ),
    );
  }

  // ─── EPDS ────────────────────────────────────────────────────────────────────

  Widget _buildEpdsSection() {
    return _sectionContainer(
      icon: Icons.psychology_outlined,
      color: const Color(0xFF7B1FA2),
      title: 'Postpartum depression screening',
      child: _epdsCompleted ? _buildEpdsResult() : _epdsStarted ? _buildEpdsQuiz() : _buildEpdsIntro(),
    );
  }

  Widget _buildEpdsIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_outlined, size: 22, color: Color(0xFF7B1FA2)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About this screening',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7B1FA2)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'The Edinburgh Postnatal Depression Scale (EPDS) is a validated 10-question '
                      'tool used by healthcare professionals worldwide. It is suitable for all mothers '
                      'during pregnancy and after birth. Takes about 2 minutes.',
                      style: TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF4A1070)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFCC02).withValues(alpha: 0.5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Answer based on how you have felt in the past 7 days, not just today.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF4E2800)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => setState(() => _epdsStarted = true),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start depression screening'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7B1FA2),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildEpdsQuiz() {
    final q = _epdsQuestions[_epdsPage];
    final answered = _epdsAnswers[_epdsPage];
    final isLast = _epdsPage == _epdsQuestions.length - 1;
    final progress = (_epdsPage + 1) / _epdsQuestions.length;
    final isQ10 = _epdsPage == 9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Question ${_epdsPage + 1} of ${_epdsQuestions.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Spacer(),
            Text(
              '${(_epdsAnswers.whereType<int>().length)} answered',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFE1BEE7),
            color: const Color(0xFF7B1FA2),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 18),
        if (isQ10)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'This question is about self-harm. If you are in immediate danger, '
                    'please call emergency services now.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        Text(
          q.text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.45, color: Color(0xFF2C1B47)),
        ),
        const SizedBox(height: 14),
        ...List.generate(q.options.length, (i) {
          final selected = answered == i;
          return GestureDetector(
            onTap: () => setState(() => _epdsAnswers[_epdsPage] = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFF3E5F5) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? const Color(0xFF7B1FA2) : Colors.grey.shade200,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? const Color(0xFF7B1FA2) : Colors.grey.shade400,
                        width: 1.5,
                      ),
                      color: selected ? const Color(0xFF7B1FA2) : Colors.transparent,
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(q.options[i], style: TextStyle(fontSize: 13.5, color: selected ? const Color(0xFF4A1070) : const Color(0xFF4A3550)))),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_epdsPage > 0)
              OutlinedButton(
                onPressed: () => setState(() => _epdsPage--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7B1FA2),
                  side: const BorderSide(color: Color(0xFF7B1FA2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: answered == null
                  ? null
                  : () {
                      if (isLast) {
                        _submitEpds();
                      } else {
                        setState(() => _epdsPage++);
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isLast ? 'See results' : 'Next'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEpdsResult() {
    final score = _epdsScore;
    final q10 = _epdsAnswers[9] ?? 0;
    final Color resultColor;
    final String resultLabel;
    final String resultDetail;
    final IconData resultIcon;

    if (q10 >= 2 || score >= 13) {
      resultColor = Colors.red.shade700;
      resultLabel = 'Please seek support';
      resultDetail = q10 >= 2
          ? 'You indicated thoughts of self-harm. Please contact your doctor or emergency services immediately.'
          : 'Your score suggests possible postpartum depression. This is treatable — please speak with your doctor soon.';
      resultIcon = Icons.warning_amber_rounded;
    } else if (score >= 9) {
      resultColor = Colors.orange.shade700;
      resultLabel = 'Mild concern detected';
      resultDetail = 'You may be experiencing some postnatal distress. '
          'Consider discussing how you feel with your doctor or midwife at your next visit.';
      resultIcon = Icons.info_outline;
    } else {
      resultColor = Colors.green.shade700;
      resultLabel = 'Low risk';
      resultDetail = 'Your responses suggest low postnatal depression risk at this time. '
          'Continue to monitor your mood and reach out if things change.';
      resultIcon = Icons.check_circle_outline;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: resultColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: resultColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(resultIcon, color: resultColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resultLabel,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: resultColor),
                        ),
                        Text(
                          'EPDS Score: $score / 30',
                          style: TextStyle(fontSize: 12, color: resultColor.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(resultDetail, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF4A3550))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'This tool is for screening purposes only and does not replace a clinical diagnosis.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _epdsCompleted = false;
            _epdsStarted = false;
            _epdsPage = 0;
            _epdsAnswers.fillRange(0, _epdsAnswers.length, null);
          }),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retake screening'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF7B1FA2),
            side: const BorderSide(color: Color(0xFF7B1FA2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ─── Newborn ─────────────────────────────────────────────────────────────────

  Widget _buildNewbornSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _newbornFuture,
      builder: (context, snap) {
        Map<String, dynamic>? nb;
        final wrap = snap.data;
        if (wrap != null && wrap.isNotEmpty) {
          final d = wrap['newborn'];
          if (d is Map<String, dynamic>) nb = d;
          if (d is Map) nb = d.cast<String, dynamic>();
        }

        return _sectionContainer(
          icon: Icons.crib_outlined,
          color: const Color(0xFF795548),
          title: 'Your newborn',
          child: nb == null || nb.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No newborn record linked yet. After delivery, your doctor or hospital can '
                      'add your baby\'s details here.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF4A3550)),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BabyVaccinationTrackerScreen(patientId: widget.patientId),
                        ),
                      ),
                      icon: const Icon(Icons.vaccines_outlined, size: 18),
                      label: const Text('Open vaccine tracker'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF795548),
                        side: const BorderSide(color: Color(0xFF795548)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _newbornRow(Icons.person_outline, 'Name', nb['name']),
                    _newbornRow(Icons.wc_outlined, 'Sex', nb['sex']),
                    if (nb['birth_weight_g'] != null)
                      _newbornRow(Icons.monitor_weight_outlined, 'Birth weight', '${nb['birth_weight_g']} g'),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BabyVaccinationTrackerScreen(patientId: widget.patientId),
                        ),
                      ),
                      icon: const Icon(Icons.vaccines_outlined, size: 18),
                      label: const Text('Immunization tracker'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF795548),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _newbornRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF795548)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF795548))),
          Text('${value ?? '—'}', style: const TextStyle(fontSize: 13, color: Color(0xFF4A3550))),
        ],
      ),
    );
  }

  // ─── Crisis card ─────────────────────────────────────────────────────────────

  Widget _buildCrisisCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emergency_outlined, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Emergency & crisis lines',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '• Call or text 988 (US/Canada) for immediate mental health support.\n'
              '• International Association for Suicide Prevention: www.iasp.info\n'
              '• Postpartum Support International: 1-800-944-4773\n'
              '• If you or your baby are in immediate danger, call your local emergency number now.',
              style: TextStyle(fontSize: 13, height: 1.55, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Learning button ─────────────────────────────────────────────────────────

  Widget _buildLearningButton() {
    return FilledButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LearningCenterScreen(patientId: widget.patientId)),
      ),
      icon: const Icon(Icons.menu_book_outlined),
      label: const Text('Explore learning center'),
      style: FilledButton.styleFrom(
        backgroundColor: _pink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ─── Helper: section container ───────────────────────────────────────────────

  Widget _sectionContainer({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
