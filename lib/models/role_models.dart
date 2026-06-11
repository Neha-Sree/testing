enum UserRole {
  mother,
  doctor,
  healthWorker,
}

class UserProfile {
  final String id;
  final UserRole role;
  final String name;
  final String email;
  final String phone;
  final String? profileImage;
  final DateTime createdAt;
  final bool isActive;
  final Map<String, dynamic> additionalData;

  UserProfile({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage,
    required this.createdAt,
    this.isActive = true,
    this.additionalData = const {},
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${json['role']}',
        orElse: () => UserRole.mother,
      ),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      profileImage: json['profileImage'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'] ?? true,
      additionalData: json['additionalData'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.toString().split('.').last,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'additionalData': additionalData,
    };
  }

  UserProfile copyWith({
    String? id,
    UserRole? role,
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    DateTime? createdAt,
    bool? isActive,
    Map<String, dynamic>? additionalData,
  }) {
    return UserProfile(
      id: id ?? this.id,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}

class MotherProfile {
  final String id;
  final String userId;
  final String fullName;
  final int age;
  final double weight; // in kg
  final double height; // in cm
  final int pregnancyWeek;
  final DateTime dueDate;
  final DateTime lmpDate; // Last menstrual period
  final List<String> medicalHistory;
  final EmergencyContact emergencyContact;
  final String assignedDoctorId;
  final String assignedHealthWorkerId;
  final List<String> allergies;
  final String bloodGroup;
  final Map<String, dynamic> additionalInfo;

  MotherProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.age,
    required this.weight,
    required this.height,
    required this.pregnancyWeek,
    required this.dueDate,
    required this.lmpDate,
    required this.medicalHistory,
    required this.emergencyContact,
    required this.assignedDoctorId,
    required this.assignedHealthWorkerId,
    this.allergies = const [],
    this.bloodGroup = '',
    this.additionalInfo = const {},
  });

  factory MotherProfile.fromJson(Map<String, dynamic> json) {
    return MotherProfile(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      fullName: json['fullName'] ?? '',
      age: json['age'] ?? 0,
      weight: (json['weight'] ?? 0.0).toDouble(),
      height: (json['height'] ?? 0.0).toDouble(),
      pregnancyWeek: json['pregnancyWeek'] ?? 0,
      dueDate: DateTime.parse(json['dueDate']),
      lmpDate: DateTime.parse(json['lmpDate']),
      medicalHistory: List<String>.from(json['medicalHistory'] ?? []),
      emergencyContact: EmergencyContact.fromJson(json['emergencyContact'] ?? {}),
      assignedDoctorId: json['assignedDoctorId'] ?? '',
      assignedHealthWorkerId: json['assignedHealthWorkerId'] ?? '',
      allergies: List<String>.from(json['allergies'] ?? []),
      bloodGroup: json['bloodGroup'] ?? '',
      additionalInfo: json['additionalInfo'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'age': age,
      'weight': weight,
      'height': height,
      'pregnancyWeek': pregnancyWeek,
      'dueDate': dueDate.toIso8601String(),
      'lmpDate': lmpDate.toIso8601String(),
      'medicalHistory': medicalHistory,
      'emergencyContact': emergencyContact.toJson(),
      'assignedDoctorId': assignedDoctorId,
      'assignedHealthWorkerId': assignedHealthWorkerId,
      'allergies': allergies,
      'bloodGroup': bloodGroup,
      'additionalInfo': additionalInfo,
    };
  }

  String get bmi => (weight / ((height / 100) * (height / 100))).toStringAsFixed(1);
  int get remainingWeeks => ((dueDate.difference(DateTime.now()).inDays) / 7).round();
  String get trimester {
    if (pregnancyWeek <= 12) return 'First';
    if (pregnancyWeek <= 28) return 'Second';
    return 'Third';
  }
}

class EmergencyContact {
  final String name;
  final String relationship;
  final String phone;
  final String? email;

  EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
    this.email,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] ?? '',
      relationship: json['relationship'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'email': email,
    };
  }
}

class DoctorProfile {
  final String id;
  final String userId;
  final String fullName;
  final String specialization;
  final String licenseNumber;
  final String hospital;
  final int yearsOfExperience;
  final List<String> qualifications;
  final List<String> assignedMotherIds;

  DoctorProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.specialization,
    required this.licenseNumber,
    required this.hospital,
    required this.yearsOfExperience,
    required this.qualifications,
    this.assignedMotherIds = const [],
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      fullName: json['fullName'] ?? '',
      specialization: json['specialization'] ?? '',
      licenseNumber: json['licenseNumber'] ?? '',
      hospital: json['hospital'] ?? '',
      yearsOfExperience: json['yearsOfExperience'] ?? 0,
      qualifications: List<String>.from(json['qualifications'] ?? []),
      assignedMotherIds: List<String>.from(json['assignedMotherIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'specialization': specialization,
      'licenseNumber': licenseNumber,
      'hospital': hospital,
      'yearsOfExperience': yearsOfExperience,
      'qualifications': qualifications,
      'assignedMotherIds': assignedMotherIds,
    };
  }
}

class HealthWorkerProfile {
  final String id;
  final String userId;
  final String fullName;
  final String department;
  final String hospital;
  final List<String> assignedMotherIds;
  final List<String> permissions;

  HealthWorkerProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.department,
    required this.hospital,
    this.assignedMotherIds = const [],
    this.permissions = const [],
  });

  factory HealthWorkerProfile.fromJson(Map<String, dynamic> json) {
    return HealthWorkerProfile(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      fullName: json['fullName'] ?? '',
      department: json['department'] ?? '',
      hospital: json['hospital'] ?? '',
      assignedMotherIds: List<String>.from(json['assignedMotherIds'] ?? []),
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'department': department,
      'hospital': hospital,
      'assignedMotherIds': assignedMotherIds,
      'permissions': permissions,
    };
  }
}
