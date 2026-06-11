import 'package:flutter/material.dart';
import 'cute_footer.dart';
import 'doctor/doctor_shell_screen.dart';
import 'health_worker_dashboard_screen.dart';
import 'mom_onboarding_screen.dart';
import 'services/mom_api_service.dart';

class NameInputScreen extends StatefulWidget {
  const NameInputScreen({
    super.key,
    required this.role,
    required this.generatedId,
    required this.themeColor,
  });

  final String role;
  final String generatedId;
  final MaterialColor themeColor;

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final MomApiService _momApiService = MomApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAccountAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final fullName = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    try {
      await _momApiService.createAccount(
        role: widget.role,
        userId: widget.generatedId,
        fullName: fullName,
        phone: phone,
        password: password,
      );

      if (!mounted) return;
      _navigateToDashboard(fullName);
    } on MomApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unexpected error while creating account'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToDashboard(String fullName) {
    switch (widget.role.toLowerCase()) {
      case 'doctor':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DoctorShellScreen(doctorId: widget.generatedId),
          ),
        );
        break;
      case 'health worker':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HealthWorkerDashboardScreen(
              workerId: widget.generatedId,
              workerName: fullName,
            ),
          ),
        );
        break;
      case 'mother':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MomOnboardingScreen(
              patientId: widget.generatedId,
              motherName: fullName,
            ),
          ),
        );
        break;
      default:
        Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.themeColor.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: widget.themeColor.shade800),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Role Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.themeColor.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getRoleIcon(),
                          size: 60,
                          color: widget.themeColor.shade600,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Welcome Message
                      Text(
                        'Welcome, ${widget.role}!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: widget.themeColor.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'Your ID: ${widget.generatedId}',
                        style: TextStyle(
                          fontSize: 18,
                          color: widget.themeColor.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Account creation form
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: widget.themeColor.withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create your account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: widget.themeColor.shade700,
                                ),
                              ),
                              const SizedBox(height: 15),

                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  hintText: 'Enter your full name',
                                  prefixIcon: Icon(
                                    Icons.person,
                                    color: widget.themeColor.shade600,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: widget.themeColor.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: widget.themeColor.shade600,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: widget.themeColor.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Name must be at least 2 characters';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.next,
                              ),

                              const SizedBox(height: 15),

                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  hintText: 'Enter your phone number',
                                  prefixIcon: Icon(
                                    Icons.phone,
                                    color: widget.themeColor.shade600,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: widget.themeColor.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: widget.themeColor.shade600,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: widget.themeColor.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.next,
                              ),

                              const SizedBox(height: 15),

                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Create a password',
                                  prefixIcon: Icon(
                                    Icons.lock,
                                    color: widget.themeColor.shade600,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: widget.themeColor.shade600,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: widget.themeColor.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: widget.themeColor.shade600,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: widget.themeColor.shade50,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 4) {
                                    return 'Password must be at least 4 characters';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) =>
                                    _createAccountAndContinue(),
                              ),

                              const SizedBox(height: 25),

                              // Continue Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _createAccountAndContinue,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.themeColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 3,
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        )
                                      : const Text(
                                          'Create Account',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
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
              ),
            ),
            CuteFooter(color: widget.themeColor.shade600),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon() {
    switch (widget.role.toLowerCase()) {
      case 'doctor':
        return Icons.medical_services;
      case 'health worker':
        return Icons.health_and_safety;
      case 'mother':
        return Icons.pregnant_woman;
      default:
        return Icons.person;
    }
  }
}
