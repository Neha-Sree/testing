import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'services/mom_api_base_url.dart';
import 'services/mom_api_service.dart';

class MotherProfileScreen extends StatefulWidget {
  const MotherProfileScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<MotherProfileScreen> createState() => _MotherProfileScreenState();
}

class _MotherProfileScreenState extends State<MotherProfileScreen> {
  final MomApiService _apiService = MomApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicalHistoryController =
      TextEditingController();
  final TextEditingController _doctorIdController = TextEditingController();

  DateTime? _dueDate;
  String _preferredLanguage = 'English';
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String? _profileImagePath;
  Map<String, dynamic>? _profileData;
  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _commonAllergies = [
    'Dairy',
    'Gluten',
    'Nuts',
    'Soy',
    'Fish',
    'Eggs',
    'Shellfish'
  ];
  List<String> _selectedAllergies = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final profileData = await _apiService.fetchMotherByPatientId(
        widget.patientId,
      );
      setState(() {
        _profileData = profileData;
        _populateFields(profileData);
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
    _nameController.text = data['full_name'] ?? data['name'] ?? '';
    _emailController.text = data['email'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _emergencyContactController.text = data['emergency_contact'] ?? '';
    _addressController.text = data['address'] ?? '';
    _bloodGroupController.text = data['blood_group'] ?? '';
    final allgs = data['allergies']?.toString() ?? '';
    _selectedAllergies = allgs
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _allergiesController.text = _selectedAllergies.where((a) => !_commonAllergies.contains(a)).join(', ');

    _medicalHistoryController.text = data['medical_history'] ?? '';
    _preferredLanguage = data['preferred_language'] ?? 'English';
    _doctorIdController.text = data['doctor_id'] ?? 'Not assigned';
    _profileImagePath = data['profile_image_path'] as String?;

    if (data['due_date'] != null) {
      _dueDate = DateTime.parse(data['due_date']);
    }
  }

  /// Convert the backend's on-disk path into a fetchable URL via the
  /// `/uploads` static mount.
  String? get _profileImageUrl {
    final path = _profileImagePath;
    if (path == null || path.isEmpty) return null;
    var clean = path.replaceAll('\\', '/');
    final lower = clean.toLowerCase();
    final idx = lower.indexOf('uploads/');
    if (idx >= 0) clean = clean.substring(idx + 'uploads/'.length);
    return momUploadUrl(clean);
  }

  Future<void> _pickAndUploadProfileImage() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final name = picked.name.trim().isNotEmpty ? picked.name : 'profile.jpg';
      final newPath = await _apiService.uploadMotherProfileImage(
        patientId: widget.patientId,
        imageBytes: bytes,
        imageFilename: name,
      );
      if (!mounted) return;
      setState(() => _profileImagePath = newPath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final finalAllergies = [
        ..._selectedAllergies.where((a) => _commonAllergies.contains(a)),
        ..._allergiesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)
      ].join(',');

      final profileData = {
        'patient_id': widget.patientId,
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'emergency_contact': _emergencyContactController.text.trim(),
        'address': _addressController.text.trim(),
        'blood_group': _bloodGroupController.text.trim(),
        'allergies': finalAllergies,
        'medical_history': _medicalHistoryController.text.trim(),
        'preferred_language': _preferredLanguage,
        'due_date': _dueDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _apiService.updateMotherProfile(widget.patientId, profileData);

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
    final themeColor = const Color(0xFFE91E63); // Deep Pink
    final accentColor = const Color(0xFFFF6090); // Light Pink
    final backgroundColor = const Color(0xFFFFF0F5); // Lavender Blush

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'My Profile'),
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
              child: CircularProgressIndicator(color: Color(0xFFE91E63)),
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

                    // Basic Information Section
                    _buildSectionCard('Basic Information', Icons.person, [
                      _buildTextField(
                        _nameController,
                        'Full Name',
                        Icons.person,
                        enabled: _isEditing,
                        required: true,
                      ),
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
                      _buildTextField(
                        _emergencyContactController,
                        'Emergency Contact',
                        Icons.emergency,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        required: true,
                      ),
                      // Doctor ID field (read-only)
                      _buildTextField(
                        _doctorIdController,
                        'Assigned Doctor ID',
                        Icons.local_hospital,
                        enabled: false,
                      ),
                    ], themeColor),

                    const SizedBox(height: 20),

                    // Medical Information Section
                    _buildSectionCard(
                      'Medical Information',
                      Icons.medical_services,
                      [
                        _buildTextField(
                          _bloodGroupController,
                          'Blood Group',
                          Icons.opacity,
                          enabled: _isEditing,
                        ),
                        _buildDatePicker('Due Date', Icons.calendar_today),
                        _buildLabel('Allergies'),
                        _buildAllergiesSelection(),
                        _buildTextField(
                          _allergiesController,
                          'Other Allergies (comma separated)',
                          Icons.warning,
                          enabled: _isEditing,
                          maxLines: 2,
                        ),
                        _buildTextField(
                          _medicalHistoryController,
                          'Medical History',
                          Icons.history,
                          enabled: _isEditing,
                          maxLines: 3,
                        ),
                      ],
                      themeColor,
                    ),

                    const SizedBox(height: 20),

                    // Additional Information Section
                    _buildSectionCard(
                      'Additional Information',
                      Icons.more_horiz,
                      [
                        _buildTextField(
                          _addressController,
                          'Address',
                          Icons.location_on,
                          enabled: _isEditing,
                          maxLines: 2,
                        ),
                        _buildLanguageDropdown(
                          'Preferred Language',
                          Icons.language,
                        ),
                      ],
                      themeColor,
                    ),

                    const SizedBox(height: 20),

                    // Pregnancy Statistics Section
                    _buildSectionCard('Pregnancy Statistics', Icons.analytics, [
                      _buildStatRow(
                        'Current Week',
                        '${_profileData?['pregnant_weeks'] ?? 'N/A'} weeks',
                      ),
                      _buildStatRow(
                        'Due Date',
                        _profileData?['due_date'] != null
                            ? _formatDate(_profileData!['due_date'])
                            : 'Not set',
                      ),
                      _buildStatRow(
                        'Blood Group',
                        _profileData?['blood_group'] ?? 'Not specified',
                      ),
                      _buildStatRow(
                        'Assigned Doctor',
                        _profileData?['doctor_id'] ?? 'Not assigned',
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
          // Avatar (tap to upload/replace photo)
          GestureDetector(
            onTap: _isUploadingPhoto ? null : _pickAndUploadProfileImage,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    color: Colors.white.withValues(alpha: 0.2),
                    image: _profileImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_profileImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profileImageUrl != null
                      ? null
                      : const Icon(
                          Icons.pregnant_woman,
                          size: 40,
                          color: Colors.white,
                        ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: _isUploadingPhoto
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFE91E63),
                            ),
                          )
                        : const Icon(
                            Icons.photo_library,
                            size: 14,
                            color: Color(0xFFE91E63),
                          ),
                  ),
                ),
              ],
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
                      ? 'Mother Profile'
                      : _nameController.text,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'ID: ${widget.patientId}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                if (_dueDate != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Due Date: ${DateFormat('MMM dd, yyyy').format(_dueDate!)}',
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
    bool required = false,
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
          prefixIcon: Icon(icon, color: const Color(0xFFE91E63)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE91E63)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: enabled ? const Color(0xFFE91E63) : Colors.grey,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE91E63), width: 2),
          ),
          filled: true,
          fillColor: enabled
              ? Colors.white
              : Colors.grey.withValues(alpha: 0.1),
        ),
        validator: (value) {
          if (!required) return null;
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDatePicker(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _isEditing
            ? () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      _dueDate ?? DateTime.now().add(const Duration(days: 280)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _dueDate = date);
                }
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE91E63)),
            borderRadius: BorderRadius.circular(12),
            color: _isEditing
                ? Colors.white
                : Colors.grey.withValues(alpha: 0.1),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFE91E63)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _dueDate != null
                      ? DateFormat('MMMM dd, yyyy').format(_dueDate!)
                      : label,
                  style: TextStyle(
                    color: _dueDate != null ? Colors.black : Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_isEditing)
                const Icon(Icons.calendar_today, color: Color(0xFFE91E63)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: _preferredLanguage,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFFE91E63)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE91E63)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _isEditing ? const Color(0xFFE91E63) : Colors.grey,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE91E63), width: 2),
          ),
          filled: true,
          fillColor: _isEditing
              ? Colors.white
              : Colors.grey.withValues(alpha: 0.1),
        ),
        items: const [
          DropdownMenuItem(value: 'English', child: Text('English')),
          DropdownMenuItem(value: 'Spanish', child: Text('Spanish')),
          DropdownMenuItem(value: 'French', child: Text('French')),
          DropdownMenuItem(value: 'German', child: Text('German')),
          DropdownMenuItem(value: 'Chinese', child: Text('Chinese')),
          DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
        ],
        onChanged: _isEditing
            ? (value) {
                setState(() => _preferredLanguage = value!);
              }
            : null,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF4A4A4A),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildAllergiesSelection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _commonAllergies.map((allergy) {
          final isSelected = _selectedAllergies.contains(allergy);
          return FilterChip(
            label: Text(allergy),
            selected: isSelected,
            onSelected: _isEditing ? (selected) {
              setState(() {
                if (selected) {
                  _selectedAllergies.add(allergy);
                } else {
                  _selectedAllergies.remove(allergy);
                }
              });
            } : null,
            selectedColor: const Color(0xFFE91E63).withOpacity(0.2),
            checkmarkColor: const Color(0xFFE91E63),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE91E63),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
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
              side: const BorderSide(color: Color(0xFFE91E63)),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _addressController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }
}
