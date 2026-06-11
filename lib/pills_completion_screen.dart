import 'package:flutter/material.dart';
import 'services/mom_api_service.dart';

class PillsCompletionScreen extends StatefulWidget {
  const PillsCompletionScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<PillsCompletionScreen> createState() => _PillsCompletionScreenState();
}

class _PillsCompletionScreenState extends State<PillsCompletionScreen> {
  final MomApiService _apiService = MomApiService();

  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _todayIntakes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPillsData();
  }

  Future<void> _loadPillsData() async {
    setState(() => _isLoading = true);

    try {
      // Load prescriptions
      final prescriptions = await _apiService.fetchPillPrescriptions(
        widget.patientId,
      );

      // Load today's intakes
      final intakes = await _apiService.fetchPillIntakes(widget.patientId);

      setState(() {
        _prescriptions = prescriptions;
        _todayIntakes = intakes;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load pills data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePillIntake(
    int prescriptionId,
    String mealTime,
    bool currentlyTaken,
  ) async {
    try {
      final today = DateTime.now();

      await _apiService.recordPillIntake(
        patientId: widget.patientId,
        prescriptionId: prescriptionId,
        intakeDate: today,
        mealTime: mealTime,
        taken: !currentlyTaken,
      );

      await _loadPillsData();
    } catch (e) {
      _showErrorSnackBar('Failed to update pill intake: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadPillsData,
        ),
      ),
    );
  }

  bool _isPillTaken(int prescriptionId, String mealTime) {
    return _todayIntakes.any(
      (intake) =>
          intake['prescription_id'] == prescriptionId &&
          intake['meal_time'] == mealTime &&
          intake['taken'] == true,
    );
  }

  int _getTodayCompletionCount() {
    int totalRequired = 0;
    int completedCount = 0;

    for (var prescription in _prescriptions) {
      final frequency = prescription['frequency'] as String;
      int requiredDoses = 0;

      switch (frequency) {
        case 'daily':
          requiredDoses = 1;
          break;
        case 'twice_daily':
          requiredDoses = 2;
          break;
        case 'three_times_daily':
          requiredDoses = 3;
          break;
      }

      totalRequired += requiredDoses;

      // Check completed doses
      final mealTimes = ['breakfast', 'lunch', 'dinner'].take(requiredDoses);
      for (var mealTime in mealTimes) {
        if (_isPillTaken(prescription['id'], mealTime)) {
          completedCount++;
        }
      }
    }

    return totalRequired > 0 ? completedCount : 0;
  }

  int _getTotalRequiredDoses() {
    int totalRequired = 0;

    for (var prescription in _prescriptions) {
      final frequency = prescription['frequency'] as String;

      switch (frequency) {
        case 'daily':
          totalRequired += 1;
          break;
        case 'twice_daily':
          totalRequired += 2;
          break;
        case 'three_times_daily':
          totalRequired += 3;
          break;
      }
    }

    return totalRequired;
  }

  double get _completionPercentage {
    final totalRequired = _getTotalRequiredDoses();
    if (totalRequired == 0) return 0.0;
    return _getTodayCompletionCount() / totalRequired;
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _getTodayCompletionCount();
    final totalRequired = _getTotalRequiredDoses();
    final isAllCompleted = completedCount == totalRequired && totalRequired > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        title: const Text(
          'Pills Completion',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _loadPillsData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCompletionCard(
                    isAllCompleted,
                    completedCount,
                    totalRequired,
                  ),
                  const SizedBox(height: 24),
                  _buildPrescriptionsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCompletionCard(
    bool isAllCompleted,
    int completedCount,
    int totalRequired,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAllCompleted
              ? [const Color(0xFF4CAF50), const Color(0xFF45A049)]
              : [const Color(0xFF2196F3), const Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isAllCompleted ? Icons.celebration : Icons.medication,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAllCompleted
                          ? 'All Pills Taken! 🎉'
                          : 'Today\'s Progress',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$completedCount of $totalRequired doses completed',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: _completionPercentage,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            borderRadius: BorderRadius.circular(10),
            minHeight: 12,
          ),
          const SizedBox(height: 12),
          Text(
            '${(_completionPercentage * 100).toInt()}% Complete',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsList() {
    if (_prescriptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.medication_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No active prescriptions',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _prescriptions.map((prescription) {
        return _buildPrescriptionCard(prescription);
      }).toList(),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescription) {
    final pillName = prescription['pill_name'] as String;
    final dosage = prescription['dosage'] as String;
    final timing = prescription['timing'] as String;
    final frequency = prescription['frequency'] as String;

    // Determine meal times based on frequency
    List<String> mealTimes = [];
    switch (frequency) {
      case 'daily':
        mealTimes = ['breakfast'];
        break;
      case 'twice_daily':
        mealTimes = ['breakfast', 'dinner'];
        break;
      case 'three_times_daily':
        mealTimes = ['breakfast', 'lunch', 'dinner'];
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medication,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pillName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    Text(
                      '$dosage • $timing • $frequency',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...mealTimes.map((mealTime) {
            final isTaken = _isPillTaken(prescription['id'], mealTime);
            return _buildMealTimeCheck(prescription['id'], mealTime, isTaken);
          }),
        ],
      ),
    );
  }

  Widget _buildMealTimeCheck(
    int prescriptionId,
    String mealTime,
    bool isTaken,
  ) {
    final mealTimeDisplay =
        mealTime.charAt(0).toUpperCase() + mealTime.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTaken ? const Color(0xFFE8F5E8) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTaken ? const Color(0xFF4CAF50) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTaken ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isTaken ? const Color(0xFF4CAF50) : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$mealTimeDisplay - ${isTaken ? 'Taken' : 'Not taken'}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: isTaken ? FontWeight.w600 : FontWeight.normal,
                color: isTaken ? const Color(0xFF4CAF50) : Colors.grey.shade700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _togglePillIntake(prescriptionId, mealTime, isTaken),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isTaken ? Colors.grey.shade300 : const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isTaken ? 'Undo' : 'Mark as Taken',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String charAt(int index) => this[index];
}
