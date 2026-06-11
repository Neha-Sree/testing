import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'contraction_history_screen.dart';
import 'services/mom_api_service.dart';

class ContractionTimerScreen extends StatefulWidget {
  const ContractionTimerScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<ContractionTimerScreen> createState() => _ContractionTimerScreenState();
}

class ContractionData {
  ContractionData({
    required this.startTime,
    required this.endTime,
    required this.type, // 'contraction' or 'relaxation'
  });

  final DateTime startTime;
  final DateTime endTime;
  final String type;

  int get durationSeconds => endTime.difference(startTime).inSeconds;
}

class _ContractionTimerScreenState extends State<ContractionTimerScreen> {
  late Stopwatch _stopwatch;
  late final MomApiService _apiService;
  late Future<void> _saveStatusFuture;
  late Future<List<Map<String, dynamic>>> _historyFuture;
  bool _timerRunning = false;
  String _currentPhase = 'ready'; // ready, contraction, relaxation
  final List<ContractionData> _contractionHistory = [];

  int _totalContractionSeconds = 0;
  int _totalRelaxationSeconds = 0;
  int _lapCount = 0;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _apiService = MomApiService();
    _saveStatusFuture = Future.value();
    _historyFuture = _apiService.fetchContractionHistory(widget.patientId);
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  void _toggleBabyFeetButton() {
    setState(() {
      if (!_timerRunning) {
        _timerRunning = true;
        if (_currentPhase == 'ready') {
          _currentPhase = 'contraction';
        }
        _stopwatch.start();
      } else {
        _nextPhase();
      }
    });
    _updateLoop();
  }

  void _nextPhase() {
    if (!_timerRunning) return;

    setState(() {
      final now = DateTime.now();
      final startTime = now.subtract(
        Duration(seconds: _stopwatch.elapsed.inSeconds),
      );

      _contractionHistory.add(
        ContractionData(
          startTime: startTime,
          endTime: now,
          type: _currentPhase,
        ),
      );

      if (_currentPhase == 'contraction') {
        _totalContractionSeconds += _stopwatch.elapsed.inSeconds;
        _currentPhase = 'relaxation';
      } else {
        _totalRelaxationSeconds += _stopwatch.elapsed.inSeconds;
        _currentPhase = 'contraction';
      }

      _lapCount++;
      _stopwatch.reset();
      _stopwatch.start();
    });
  }

  void _resetAll() {
    setState(() {
      _stopwatch.reset();
      _timerRunning = false;
      _currentPhase = 'ready';
      _contractionHistory.clear();
      _totalContractionSeconds = 0;
      _totalRelaxationSeconds = 0;
      _lapCount = 0;
    });
  }

  Future<void> _saveToBackend() async {
    try {
      debugPrint('Starting contraction session save...');
      debugPrint('Patient ID: ${widget.patientId}');
      debugPrint('Contraction seconds: $_totalContractionSeconds');
      debugPrint('Relaxation seconds: $_totalRelaxationSeconds');
      debugPrint('Lap count: $_lapCount');

      // Convert timeline data to JSON
      final timelineData = _contractionHistory
          .map(
            (data) => {
              'startTime': data.startTime.toIso8601String(),
              'endTime': data.endTime.toIso8601String(),
              'type': data.type,
              'durationSeconds': data.durationSeconds,
            },
          )
          .toList();

      debugPrint('Timeline data: ${jsonEncode(timelineData)}');

      _saveStatusFuture = _apiService.saveContractionSession(
        patientId: widget.patientId,
        sessionDate: DateTime.now(),
        contractionSeconds: _totalContractionSeconds,
        relaxationSeconds: _totalRelaxationSeconds,
        lapCount: _lapCount,
        timelineData: jsonEncode(timelineData),
      );
      await _saveStatusFuture;

      debugPrint('Contraction session saved successfully!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session saved successfully!')),
        );
        _resetAll();
      }
    } catch (e) {
      debugPrint('Error saving contraction session: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving session: $e')));
      }
    }
  }

  void _updateLoop() {
    if (!_timerRunning) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _timerRunning) {
        setState(() {});
        _updateLoop();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildSessionStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  double _calculateMaxY() {
    double maxValue = 60.0; // Default minimum

    // Check completed phases
    for (final data in _contractionHistory) {
      if (data.durationSeconds > maxValue) {
        maxValue = data.durationSeconds.toDouble();
      }
    }

    // Check current running phase
    if (_timerRunning && _currentPhase != 'ready') {
      final currentDuration = _stopwatch.elapsed.inSeconds.toDouble();
      if (currentDuration > maxValue) {
        maxValue = currentDuration;
      }
    }

    // Add 20% padding and round to nearest 10
    return ((maxValue * 1.2).ceilToDouble() / 10).ceilToDouble() * 10;
  }

  List<BarChartGroupData> _getBarChartData() {
    final groups = <BarChartGroupData>[];

    // Add completed phases
    for (int i = 0; i < _contractionHistory.length; i++) {
      final data = _contractionHistory[i];
      final isContraction = data.type == 'contraction';

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data.durationSeconds.toDouble(),
              color: isContraction ? Colors.red : Colors.blue,
              width: 16,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    // Add current running phase as live bar with animation
    if (_timerRunning && _currentPhase != 'ready') {
      final currentDuration = _stopwatch.elapsed.inSeconds.toDouble();
      groups.add(
        BarChartGroupData(
          x: _contractionHistory.length,
          barRods: [
            BarChartRodData(
              toY: currentDuration,
              color: _currentPhase == 'contraction' ? Colors.red : Colors.blue,
              width: 18,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              // Add gradient effect for live bar
              gradient: _currentPhase == 'contraction'
                  ? LinearGradient(
                      colors: [Colors.red.shade300, Colors.red.shade600],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    )
                  : LinearGradient(
                      colors: [Colors.blue.shade300, Colors.blue.shade600],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
            ),
          ],
        ),
      );
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFFE91E63); // Deep Pink
    final backgroundColor = const Color(0xFFFFF0F5); // Lavender Blush
    final elapsedSeconds = _stopwatch.elapsed.inSeconds;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Contraction Timer'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ContractionHistoryScreen(patientId: widget.patientId),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Baby Feet Graphics with Lighting Effect
                    GestureDetector(
                      onTap: _toggleBabyFeetButton,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 120,
                        decoration: BoxDecoration(
                          color: _currentPhase == 'contraction'
                              ? const Color(0xFFFFF0F5) // Lavender Blush
                              : _currentPhase == 'relaxation'
                              ? const Color(0xFFF3E5F5) // Light Purple
                              : const Color(0xFFF5F5F5), // Light Grey
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _currentPhase == 'contraction'
                                ? const Color(0xFFE91E63) // Deep Pink
                                : _currentPhase == 'relaxation'
                                ? const Color(0xFF9C27B0) // Purple
                                : const Color(0xFFE0E0E0), // Grey
                            width: 2,
                          ),
                          boxShadow: _timerRunning
                              ? [
                                  BoxShadow(
                                    color: _currentPhase == 'contraction'
                                        ? const Color(
                                            0xFFE91E63,
                                          ).withValues(alpha: 0.4)
                                        : _currentPhase == 'relaxation'
                                        ? const Color(
                                            0xFF9C27B0,
                                          ).withValues(alpha: 0.4)
                                        : Colors.grey.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale:
                                  _timerRunning &&
                                      _currentPhase == 'contraction'
                                  ? 1.1
                                  : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.child_friendly,
                                size: 60,
                                color: _currentPhase == 'contraction'
                                    ? Colors.red
                                    : _currentPhase == 'relaxation'
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 20),
                            AnimatedScale(
                              scale:
                                  _timerRunning &&
                                      _currentPhase == 'contraction'
                                  ? 1.1
                                  : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.child_friendly,
                                size: 60,
                                color: _currentPhase == 'contraction'
                                    ? Colors.red
                                    : _currentPhase == 'relaxation'
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Phase Status
                    Text(
                      _currentPhase == 'ready'
                          ? 'Ready to Start'
                          : _currentPhase == 'contraction'
                          ? 'CONTRACTION'
                          : 'RELAXATION',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _currentPhase == 'contraction'
                            ? Colors.red
                            : _currentPhase == 'relaxation'
                            ? Colors.blue
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Timer Display
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        _formatTime(elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Statistics
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Contractions',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                              Text(
                                _formatTime(_totalContractionSeconds),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Relaxation',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                              Text(
                                _formatTime(_totalRelaxationSeconds),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Cycles',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$_lapCount',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Bar Graph
                    if (_contractionHistory.isNotEmpty || _timerRunning)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Timeline (Live)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: 250,
                            child: BarChart(
                              BarChartData(
                                barGroups: _getBarChartData(),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${value.toInt()}',
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${value.toInt()}s',
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: true),
                                gridData: const FlGridData(show: true),
                                maxY: _calculateMaxY(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Contraction',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 24),
                                Container(
                                  width: 20,
                                  height: 20,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Relaxation',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 30),

                    // Save Button
                    if (_lapCount > 0)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveToBackend,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('SAVE TO HISTORY'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 30),

                    // History Section
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _historyFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Failed to load history: ${snapshot.error}',
                                    style: TextStyle(
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final history = snapshot.data ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Previous Sessions',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (history.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ContractionHistoryScreen(
                                                patientId: widget.patientId,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.history, size: 16),
                                    label: const Text('View All'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: themeColor,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            if (history.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No previous sessions found. Start timing to build your history!',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              // Show last 3 sessions
                              ...history.take(3).map((session) {
                                final sessionDate = DateTime.parse(
                                  session['session_date'],
                                );
                                final contractionSeconds =
                                    session['contraction_seconds'] ?? 0;
                                final relaxationSeconds =
                                    session['relaxation_seconds'] ?? 0;
                                final lapCount = session['lap_count'] ?? 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: themeColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.timer,
                                          color: themeColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${sessionDate.day}/${sessionDate.month}/${sessionDate.year} ${sessionDate.hour.toString().padLeft(2, '0')}:${sessionDate.minute.toString().padLeft(2, '0')}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                _buildSessionStat(
                                                  'Contraction',
                                                  _formatTime(
                                                    contractionSeconds,
                                                  ),
                                                  Colors.red,
                                                ),
                                                const SizedBox(width: 12),
                                                _buildSessionStat(
                                                  'Relaxation',
                                                  _formatTime(
                                                    relaxationSeconds,
                                                  ),
                                                  Colors.blue,
                                                ),
                                                const SizedBox(width: 12),
                                                _buildSessionStat(
                                                  'Cycles',
                                                  '$lapCount',
                                                  Colors.grey,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Fixed Control Buttons at Bottom
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, -5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Circular Start Button - Main Timer Control
                    Center(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: ElevatedButton(
                          onPressed: _toggleBabyFeetButton,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentPhase == 'contraction'
                                ? const Color(0xFFE91E63) // Deep Pink
                                : _currentPhase == 'relaxation'
                                ? const Color(0xFF9C27B0) // Purple
                                : const Color(0xFFFF6090), // Light Pink
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                            elevation: 8,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _currentPhase == 'ready'
                                    ? Icons.flash_on
                                    : _currentPhase == 'contraction'
                                    ? Icons.stop
                                    : Icons.pause,
                                size: 40,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentPhase == 'ready'
                                    ? 'START'
                                    : _currentPhase == 'contraction'
                                    ? 'STOP'
                                    : 'PAUSE',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
