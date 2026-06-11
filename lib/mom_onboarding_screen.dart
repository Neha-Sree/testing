import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'mom_dashboard_screen.dart';
import 'services/mom_api_service.dart';

class MomOnboardingScreen extends StatefulWidget {
  final String patientId;
  final String? motherName;

  const MomOnboardingScreen({
    super.key,
    required this.patientId,
    this.motherName,
  });

  @override
  State<MomOnboardingScreen> createState() => _MomOnboardingScreenState();
}

class _MomOnboardingScreenState extends State<MomOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _pregnantWeeksController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final MomApiService _momApiService = MomApiService();

  String? _bloodGroup;
  DateTime? _dueDate;
  Uint8List? _pickedProfileBytes;
  String _pickedProfileName = 'profile.jpg';
  bool _isSubmitting = false;
  bool _isLoadingExistingData = true;

  final List<String> _bloodGroups = [
    'O+',
    'O-',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
  ];

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
    _loadSavedData();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _pregnantWeeksController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    try {
      final data = await _momApiService.fetchMotherByPatientId(
        widget.patientId,
      );
      if (!mounted) return;
      setState(() {
        _ageController.text = data['age']?.toString() ?? '';
        _weightController.text = data['weight_kg']?.toString() ?? '';
        _bloodGroup = data['blood_group'] ?? 'O+';
        _pregnantWeeksController.text =
            data['pregnant_weeks']?.toString() ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _emergencyContactController.text = data['emergency_contact'] ?? '';
        _allergiesController.text = data['allergies'] ?? '';
        final allgs = data['allergies']?.toString() ?? '';
        _selectedAllergies = allgs
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        _allergiesController.text = _selectedAllergies.where((a) => !_commonAllergies.contains(a)).join(', ');
        if (data['due_date'] != null) {
          _dueDate = DateTime.parse(data['due_date']);
        }
        _isLoadingExistingData = false;
      });
    } catch (e) {
      debugPrint('Error loading saved data: $e');
      setState(() => _isLoadingExistingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Maternal Care Palette
    const Color primaryPink = Color(0xFFF06292);
    const Color surfacePink = Color(0xFFFFF8F7);
    const Color textDark = Color(0xFF4A148C);
    const Color inputBg = Color(0xFFFDF1F0);

    return Scaffold(
      backgroundColor: surfacePink,
      appBar: AppBar(
        title: const Text(
          'Getting Started',
          style: TextStyle(color: primaryPink, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: primaryPink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryPink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoadingExistingData
            ? const Center(child: CircularProgressIndicator(color: primaryPink))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Let\'s build your profile, Mom!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Patient ID: ${widget.patientId}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryPink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Profile Picture Section
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x20F06292),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 65,
                                  backgroundColor: inputBg,
                                  backgroundImage: _pickedProfileBytes != null
                                      ? MemoryImage(_pickedProfileBytes!)
                                      : null,
                                  child: _pickedProfileBytes == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 65,
                                          color: Color(0x40F06292),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 5,
                                right: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: primaryPink,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x40F06292),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.photo_library,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tap to choose a photo from your gallery',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 32),

                      // Form Fields
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Age'),
                                _buildTextField(
                                  _ageController,
                                  keyboardType: TextInputType.number,
                                  prefixIcon: Icons.calendar_month,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Weight (kg)'),
                                _buildTextField(
                                  _weightController,
                                  keyboardType: TextInputType.number,
                                  prefixIcon: Icons.monitor_weight_outlined,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _buildLabel('Blood Group'),
                      _buildDropdownField(),
                      const SizedBox(height: 20),

                      _buildLabel('Weeks Pregnant'),
                      _buildTextField(
                        _pregnantWeeksController,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.child_care,
                        suffix: const Text(
                          'Weeks',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildLabel('Expected Due Date'),
                      _buildDatePickerField(),
                      const SizedBox(height: 20),

                      _buildLabel('Phone Number'),
                      _buildTextField(
                        _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone,
                      ),
                      const SizedBox(height: 20),

                      _buildLabel('Address'),
                      _buildTextField(
                        _addressController,
                        keyboardType: TextInputType.streetAddress,
                        prefixIcon: Icons.home,
                      ),
                      const SizedBox(height: 20),

                      _buildLabel('Emergency Contact Name/Number *'),
                      _buildTextField(
                        _emergencyContactController,
                        keyboardType: TextInputType.text,
                        prefixIcon: Icons.emergency,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Emergency contact is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildLabel('Allergies'),
                      _buildAllergiesSelection(),
                      _buildTextField(
                        _allergiesController,
                        hint: 'Other Allergies (comma separated)',
                        keyboardType: TextInputType.multiline,
                        prefixIcon: Icons.medical_information,
                      ),
                      const SizedBox(height: 40),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 8,
                          shadowColor: primaryPink.withOpacity(0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSubmitting
                                  ? 'Processing...'
                                  : 'Complete Setup',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Decorative Footer Section
                      const Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.favorite,
                                color: primaryPink,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.face, color: primaryPink, size: 20),
                              SizedBox(width: 12),
                              Icon(
                                Icons.pregnant_woman,
                                color: primaryPink,
                                size: 20,
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Mama Care',
                            style: TextStyle(
                              color: primaryPink,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'We\'re here to hold your hand\nthrough every magical milestone.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'SAFE • SECURE • SUPPORTIVE',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
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

  Widget _buildTextField(
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    Widget? suffix,
    IconData? prefixIcon,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        suffix: suffix,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFFF06292)) : null,
        filled: true,
        fillColor: const Color(0xFFFDF1F0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF1F0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: _bloodGroup,
          decoration: const InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(Icons.bloodtype, color: Color(0xFFF06292)),
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          hint: const Text('Select Blood Group'),
          items: _bloodGroups
              .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
              .toList(),
          onChanged: (val) => setState(() => _bloodGroup = val),
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
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedAllergies.add(allergy);
                } else {
                  _selectedAllergies.remove(allergy);
                }
              });
            },
            selectedColor: const Color(0xFFF06292).withOpacity(0.2),
            checkmarkColor: const Color(0xFFF06292),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 180)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 300)),
        );
        if (date != null) setState(() => _dueDate = date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF1F0),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.event, color: Color(0xFFF06292)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dueDate == null
                    ? 'Select your due date'
                    : '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}',
                style: TextStyle(
                  color: _dueDate == null ? Colors.grey.shade600 : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedProfileBytes = bytes;
        final name = image.name.trim();
        _pickedProfileName = name.isNotEmpty ? name : 'profile.jpg';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message != null && e.message!.isNotEmpty
                ? 'Gallery: ${e.message}'
                : 'Could not open the photo library. Check app permissions in Settings.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final int? age = int.tryParse(_ageController.text.trim());
    final double? weight = double.tryParse(_weightController.text.trim());
    final int? pregnantWeeks = int.tryParse(
      _pregnantWeeksController.text.trim(),
    );

    final finalAllergies = [
      ..._selectedAllergies.where((a) => _commonAllergies.contains(a)),
      ..._allergiesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)
    ].join(',');

    try {
      await _momApiService.submitMomOnboarding(
        patientId: widget.patientId,
        fullName: widget.motherName ?? 'Mother',
        age: age,
        weightKg: weight,
        bloodGroup: _bloodGroup,
        pregnantWeeks: pregnantWeeks,
        dueDate: _dueDate,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        emergencyContact: _emergencyContactController.text.trim(),
        allergies: finalAllergies,
        profileImageBytes: _pickedProfileBytes,
        profileImageFilename: _pickedProfileName,
      );

      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MomDashboardScreen(patientId: widget.patientId),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $error'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
