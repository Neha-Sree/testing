import 'package:flutter/material.dart';
import 'contraction_history_screen.dart';
import 'doctor_pills_screen.dart';
import 'doctor_patient_management_screen.dart';
import 'doctor_profile_screen.dart';
import 'chat_list_screen.dart';
import 'services/mom_api_service.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  final MomApiService _apiService = MomApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _patientData;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    super.dispose();
  }

  Future<void> _searchPatient() async {
    if (_patientIdController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _patientData = null;
    });

    try {
      final patientData = await _apiService.fetchMotherByPatientId(
        _patientIdController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _patientData = patientData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Patient not found: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1976D2);
    const Color backgroundBlue = Color(0xFFF0F7FF);
    const Color surfaceWhite = Colors.white;

    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text(
          'Doctor Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: surfaceWhite,
        foregroundColor: primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      DoctorProfileScreen(doctorId: widget.doctorId),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hello, Doctor!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${widget.doctorId}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Search Section
              _buildSectionTitle('Search Patient'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _patientIdController,
                      decoration: InputDecoration(
                        hintText: 'Enter Patient ID',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: primaryBlue,
                        ),
                        filled: true,
                        fillColor: surfaceWhite,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _searchPatient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(18),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Quick Actions
              _buildSectionTitle('Management'),
              const SizedBox(height: 16),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DoctorPatientManagementScreen(
                            doctorId: widget.doctorId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.people_alt_rounded),
                    label: const Text(
                      'Manage My Patients',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: surfaceWhite,
                      foregroundColor: primaryBlue,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChatListScreen(
                            currentUserId: widget.doctorId,
                            currentUserType: 'doctor',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text(
                      'Patient Chats',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Patient Details Result
              if (_patientData != null) ...[
                _buildSectionTitle('Patient Details'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.person_outline,
                        'Name',
                        _patientData!['full_name'],
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        Icons.fingerprint,
                        'ID',
                        _patientData!['patient_id'],
                      ),
                      _buildDivider(),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow(
                              Icons.cake_outlined,
                              'Age',
                              '${_patientData!['age']} yrs',
                            ),
                          ),
                          Expanded(
                            child: _buildInfoRow(
                              Icons.monitor_weight_outlined,
                              'Weight',
                              '${_patientData!['weight_kg']} kg',
                            ),
                          ),
                        ],
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        Icons.bloodtype_outlined,
                        'Blood Group',
                        _patientData!['blood_group'],
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        Icons.event_note,
                        'Weeks',
                        '${_patientData!['pregnant_weeks']} Weeks Pregnant',
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              'History',
                              Icons.history_rounded,
                              const Color(0xFF9C27B0),
                              () {
                                if (_patientData != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ContractionHistoryScreen(
                                            patientId:
                                                _patientData!['patient_id'] ??
                                                '',
                                          ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              'Prescribe',
                              Icons.medication_rounded,
                              const Color(0xFF4CAF50),
                              () {
                                if (_patientData != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => DoctorPillsScreen(
                                        doctorId: widget.doctorId,
                                        patientId:
                                            _patientData!['patient_id'] ?? '',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Patient Tools Data
                if (_patientData != null) ...[
                  _buildSectionTitle('Patient Tools Data'),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _apiService.fetchPatientDashboardData(
                      _patientData!['patient_id'] ?? '',
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            'Error loading tools data: ${snapshot.error}',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        );
                      }

                      final data = snapshot.data;
                      if (data == null) {
                        return const Text('No tools data available');
                      }

                      return Column(
                        children: [
                          // Hydration Data
                          _buildToolsDataCard(
                            'Hydration',
                            Icons.water_drop,
                            Colors.blue,
                            data['hydration_logs'] ?? [],
                            'water_ml',
                            'goal_ml',
                            'ml',
                            showDailyGoal: false,
                          ),
                          const SizedBox(height: 16),

                          // Diet Data
                          _buildDietDataCard(data['diet_logs'] ?? []),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF37474F),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(height: 24, thickness: 0.5);

  Widget _buildToolsDataCard(
    String title,
    IconData icon,
    Color color,
    List<dynamic> logs,
    String valueField,
    String goalField,
    String unit, {
    bool showDailyGoal = true,
  }) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              'No $title data available',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final latestLog = logs.first as Map<String, dynamic>;
    final value = (latestLog[valueField] ?? 0).toDouble();
    final goal = (latestLog[goalField] ?? 0).toDouble();
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${value.toInt()}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                showDailyGoal
                    ? ' / ${goal.toInt()}$unit'
                    : ' $unit (latest log)',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          if (showDailyGoal) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDietDataCard(List<dynamic> logs) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.restaurant, color: Colors.green, size: 20),
            SizedBox(width: 12),
            Text('No diet data available'),
          ],
        ),
      );
    }

    final today = DateTime.now();
    final todayLogs = logs.where((log) {
      final logDate = DateTime.parse(log['log_date']);
      return logDate.day == today.day &&
          logDate.month == today.month &&
          logDate.year == today.year;
    }).toList();

    int totalCalories = 0;
    for (var log in todayLogs) {
      totalCalories += (log['calories'] ?? 0) as int;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.restaurant, color: Colors.green, size: 20),
              SizedBox(width: 12),
              Text(
                'Diet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Today\'s Calories: $totalCalories kcal',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${todayLogs.length} meals logged today',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
    );
  }
}
