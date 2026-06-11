import 'package:flutter/material.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({
    super.key,
    required this.doctorId,
    this.doctorName,
  });

  final String doctorId;
  final String? doctorName;

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
    _licenseController.dispose();
    _hospitalController.dispose();
    _addressController.dispose();
    _qualificationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      // For now, we'll use the doctor name from the widget
      // In a real implementation, you'd fetch this from a doctor profile API
      setState(() {
        _profileData = {
          'name': widget.doctorName ?? 'Dr. Unknown',
          'email': '',
          'phone': '',
          'specialization': 'General Practitioner',
          'experience': '0',
          'license_number': '',
          'hospital': 'Life Nest Medical Center',
          'address': '',
          'qualification': 'MBBS',
        };
        _populateFields(_profileData!);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? '';
    _emailController.text = data['email'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _specializationController.text = data['specialization'] ?? '';
    _experienceController.text = data['experience'] ?? '';
    _licenseController.text = data['license_number'] ?? '';
    _hospitalController.text = data['hospital'] ?? '';
    _addressController.text = data['address'] ?? '';
    _qualificationController.text = data['qualification'] ?? '';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // In a real implementation, you'd save this to a doctor profile API
      // For now, we'll just show a success message
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF2196F3); // Professional Blue
    final accentColor = const Color(0xFF64B5F6); // Light Blue
    final backgroundColor = const Color(0xFFE3F2FD); // Very Light Blue

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'Doctor Profile'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isLoading
                ? null
                : () {
                    if (_isEditing) {
                      _saveProfile();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2196F3)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Header with Avatar
                    _buildProfileHeader(themeColor, accentColor),
                    const SizedBox(height: 30),

                    // Professional Information Section
                    _buildSectionCard(
                      'Professional Information',
                      Icons.medical_services,
                      [
                        _buildTextField(
                          _nameController,
                          'Full Name',
                          Icons.person,
                          enabled: _isEditing,
                        ),
                        _buildTextField(
                          _specializationController,
                          'Specialization',
                          Icons.local_hospital,
                          enabled: _isEditing,
                        ),
                        _buildTextField(
                          _experienceController,
                          'Years of Experience',
                          Icons.timeline,
                          enabled: _isEditing,
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(
                          _qualificationController,
                          'Qualification',
                          Icons.school,
                          enabled: _isEditing,
                        ),
                        _buildTextField(
                          _licenseController,
                          'License Number',
                          Icons.verified,
                          enabled: _isEditing,
                        ),
                      ],
                      themeColor,
                    ),

                    const SizedBox(height: 20),

                    // Contact Information Section
                    _buildSectionCard(
                      'Contact Information',
                      Icons.contact_phone,
                      [
                        _buildTextField(
                          _emailController,
                          'Email',
                          Icons.email,
                          enabled: _isEditing,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _buildTextField(
                          _phoneController,
                          'Phone Number',
                          Icons.phone,
                          enabled: _isEditing,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                      themeColor,
                    ),

                    const SizedBox(height: 20),

                    // Practice Information Section
                    _buildSectionCard('Practice Information', Icons.business, [
                      _buildTextField(
                        _hospitalController,
                        'Hospital/Clinic',
                        Icons.local_hospital,
                        enabled: _isEditing,
                      ),
                      _buildTextField(
                        _addressController,
                        'Address',
                        Icons.location_on,
                        enabled: _isEditing,
                        maxLines: 3,
                      ),
                    ], themeColor),

                    const SizedBox(height: 30),

                    // Save/Cancel Buttons
                    if (_isEditing) _buildActionButtons(themeColor),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader(Color themeColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor, accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.medical_services,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),

          // Profile Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.isEmpty
                      ? 'Doctor Profile'
                      : _nameController.text,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Doctor ID: ${widget.doctorId}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                if (_specializationController.text.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _specializationController.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    List<Widget> children,
    Color themeColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: themeColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ],
            ),
          ),

          // Section Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool enabled = true,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF2196F3)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2196F3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: enabled ? const Color(0xFF2196F3) : Colors.grey,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
          ),
          filled: true,
          fillColor: enabled
              ? Colors.white
              : Colors.grey.withValues(alpha: 0.1),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildActionButtons(Color themeColor) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save Profile', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() => _isEditing = false);
                    _loadProfileData(); // Reload original data
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: themeColor,
              side: const BorderSide(color: Color(0xFF2196F3)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
