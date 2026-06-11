import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/missed_notifications_store.dart';
import 'services/mom_api_service.dart';

class SleepTimerScreen extends StatefulWidget {
  const SleepTimerScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<SleepTimerScreen> createState() => _SleepTimerScreenState();
}

class _SleepTimerScreenState extends State<SleepTimerScreen> {
  final MomApiService _apiService = MomApiService();

  bool _isLoading = true;
  bool _isGoalSet = false;
  double _goalHours = 8.0;
  double _inputSleepHours = 8.0;

  List<Map<String, dynamic>> _history = [];
  int _daysMet = 0;
  int _daysNotMet = 0;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final history = await _apiService.fetchSleepHistory(widget.patientId);
      int met = 0;
      int notMet = 0;

      for (var session in history) {
        if (session['is_goal_met'] == true) {
          met++;
        } else {
          notMet++;
        }
      }

      if (mounted) {
        setState(() {
          _history = history;
          _daysMet = met;
          _daysNotMet = notMet;
          if (history.isNotEmpty) {
            _isGoalSet = true;
            _goalHours = (history.first['goal_hours'] as num).toDouble();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load history: $e')));
      }
    }
  }

  Future<void> _saveSleepData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.saveSleepSession(
        patientId: widget.patientId,
        sessionDate: DateTime.now(),
        sleepHours: _inputSleepHours,
        goalHours: _goalHours,
      );

      final today = DateTime.now();
      await MissedNotificationsStore.instance.dismiss(
        widget.patientId,
        'sleep_${today.toIso8601String().split('T').first}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep logged successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _fetchHistory();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving sleep data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSetGoalDialog() {
    double tempGoal = _goalHours;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A3C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Set Sleep Goal',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tempGoal.toStringAsFixed(1)} Hours',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent,
                    ),
                  ),
                  Slider(
                    value: tempGoal,
                    min: 4.0,
                    max: 16.0,
                    divisions: 24,
                    activeColor: Colors.purpleAccent,
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      setDialogState(() {
                        tempGoal = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _goalHours = tempGoal;
                      _isGoalSet = true;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                  ),
                  child: const Text(
                    'SAVE GOAL',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF161623);
    const cardColor = Color(0xFF232336);
    const accentColor = Colors.purpleAccent;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Sleep Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        height: 180,
                        color: cardColor,
                        child: Image.asset(
                          'assets/images/sleep_timer.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.nightlight_round,
                                  size: 60,
                                  color: accentColor,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Sleep Tracker',
                                  style: TextStyle(
                                    color: Colors.green.withAlpha(25),
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  '(Add sleep_timer.jpg to assets/images)',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(76),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Goal Section
                    if (!_isGoalSet)
                      _buildSetupGoalCard(cardColor, accentColor)
                    else ...[
                      _buildCurrentGoalHeader(cardColor, accentColor),
                      const SizedBox(height: 20),
                      _buildLogSleepCard(cardColor, accentColor),
                      const SizedBox(height: 25),
                      _buildStatsRow(cardColor),
                      const SizedBox(height: 25),
                      _buildHistoryList(cardColor),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSetupGoalCard(Color cardColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.flag_circle, size: 50, color: accentColor),
          const SizedBox(height: 15),
          const Text(
            'Set Your Sleep Goal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'We will track your progress against this goal. You can change it later if needed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: _showSetGoalDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'SET GOAL NOW',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentGoalHeader(Color cardColor, Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Goal',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${_goalHours.toStringAsFixed(1)} hours',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: _showSetGoalDialog,
          icon: Icon(Icons.edit, size: 16, color: accentColor),
          label: Text('Change Goal', style: TextStyle(color: accentColor)),
        ),
      ],
    );
  }

  Widget _buildLogSleepCard(Color cardColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log Today\'s Sleep',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '${_inputSleepHours.toStringAsFixed(1)} hrs',
              style: TextStyle(
                color: accentColor,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Slider(
            value: _inputSleepHours,
            min: 0.0,
            max: 24.0,
            divisions: 48,
            activeColor: accentColor,
            inactiveColor: Colors.black26,
            onChanged: (val) {
              setState(() {
                _inputSleepHours = val;
              });
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSleepData,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'SAVE SLEEP ENTRY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Color cardColor) {
    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            cardColor,
            'Goal Reached',
            '$_daysMet Days',
            Colors.greenAccent,
            Icons.emoji_events,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildStatBox(
            cardColor,
            'Goal Missed',
            '$_daysNotMet Days',
            Colors.orangeAccent,
            Icons.trending_down,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(
    Color cardColor,
    String title,
    String value,
    Color iconColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(Color cardColor) {
    if (_history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _history.length,
          itemBuilder: (context, index) {
            final session = _history[index];
            final date = DateTime.tryParse(session['session_date'] ?? '');
            final dateStr = date != null
                ? DateFormat('MMM dd, yyyy').format(date)
                : 'Unknown';
            final sleepHrs = session['sleep_hours'] as num;
            final isMet = session['is_goal_met'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMet
                          ? Colors.greenAccent.withValues(alpha: 0.1)
                          : Colors.orangeAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMet ? Icons.check : Icons.close,
                      color: isMet ? Colors.greenAccent : Colors.orangeAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isMet ? 'Goal Achieved' : 'Goal Missed',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${sleepHrs.toStringAsFixed(1)}h',
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
