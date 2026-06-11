import 'package:flutter/material.dart';
import 'cute_footer.dart';
import 'doctor/doctor_shell_screen.dart';
import 'health_worker_dashboard_screen.dart';
import 'mom_dashboard_screen.dart';
import 'mom_onboarding_screen.dart';

class GeneratedIdScreen extends StatelessWidget {
  final String role;
  final String generatedId;
  final MaterialColor themeColor;

  const GeneratedIdScreen({
    super.key,
    required this.role,
    required this.generatedId,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeColor.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: themeColor.shade800),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.verified_rounded,
                          size: 80,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Welcome, $role!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: themeColor.shade900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your generated Life Nest ID is:',
                        style: TextStyle(
                          fontSize: 16,
                          color: themeColor.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: themeColor.shade200,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: SelectableText(
                          generatedId,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: themeColor.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () {
                          if (role == 'Mother') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MomOnboardingScreen(patientId: generatedId),
                              ),
                            );
                          } else if (role == 'Doctor') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DoctorShellScreen(
                                  doctorId: generatedId,
                                ),
                              ),
                            );
                          } else if (role == 'Health Worker') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    HealthWorkerDashboardScreen(
                                      workerId: generatedId,
                                    ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MomDashboardScreen(patientId: generatedId),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            CuteFooter(color: themeColor.shade300),
          ],
        ),
      ),
    );
  }
}
