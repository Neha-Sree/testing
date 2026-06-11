import 'package:flutter/material.dart';

import 'doctor/doctor_shell_screen.dart';
import 'health_worker_dashboard_screen.dart';
import 'mom_dashboard_screen.dart';
import 'mom_onboarding_screen.dart';
import 'role_selection_screen.dart';
import 'services/mom_api_service.dart';
import 'theme/maternal_theme.dart';
import 'theme/web_buttons.dart';
import 'theme/web_layout.dart';

class EntryChoiceScreen extends StatefulWidget {
  const EntryChoiceScreen({super.key});

  @override
  State<EntryChoiceScreen> createState() => _EntryChoiceScreenState();
}

class _EntryChoiceScreenState extends State<EntryChoiceScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final MomApiService _momApiService = MomApiService();
  bool _isCheckingId = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = WebBreakpoints.isCompact(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        title: const Text('Life Nest'),
        backgroundColor: Colors.white,
        foregroundColor: MaternalTheme.primaryPink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 32, vertical: 24),
            child: WebLayout(
              maxWidth: 480,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(compact ? 22 : 28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF06292), MaternalTheme.primaryPink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: MaternalTheme.primaryPink.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in with your patient or worker ID',
                          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _idController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Patient / Worker ID',
                            hintText: 'e.g. MUM12345',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your ID';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: compact ? 22 : 18),
                        WebPrimaryButton(
                          label: 'Continue',
                          icon: Icons.login_rounded,
                          isLoading: _isCheckingId,
                          onPressed: _isCheckingId ? null : _continueWithExistingId,
                        ),
                        const SizedBox(height: 12),
                        WebOutlineButton(
                          label: 'Create new account',
                          icon: Icons.person_add_outlined,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueWithExistingId() async {
    if (!_formKey.currentState!.validate()) return;
    final patientId = _idController.text.trim().toUpperCase();
    final password = _passwordController.text;
    if (!mounted) return;

    setState(() => _isCheckingId = true);

    try {
      await _momApiService.login(userId: patientId, password: password);
      if (!mounted) return;

      if (patientId.startsWith('MUM')) {
        try {
          await _momApiService.fetchMotherByPatientId(patientId);
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MomDashboardScreen(patientId: patientId)),
          );
        } on MomApiException catch (error) {
          if (!mounted) return;
          if (error.statusCode == 404) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MomOnboardingScreen(patientId: patientId)),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message), backgroundColor: Colors.red.shade600),
          );
        }
        return;
      }

      if (patientId.startsWith('DOC')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DoctorShellScreen(doctorId: patientId)),
        );
        return;
      }

      if (patientId.startsWith('HWN')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HealthWorkerDashboardScreen(workerId: patientId)),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid ID prefix. Use MUM, DOC, or HWN')),
      );
    } on MomApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red.shade600),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error while logging in')),
      );
    } finally {
      if (mounted) setState(() => _isCheckingId = false);
    }
  }
}
