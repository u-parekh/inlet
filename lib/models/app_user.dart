class AppUser {
  final String authId; //  auth user id
  final String fullName;
  final String email;
  final String? phone;
  final String? block;
  final String? flat;
  final String role;

  AppUser({
    required this.authId,
    required this.fullName,
    required this.email,
    this.phone,
    this.block,
    this.flat,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> m) {
    return AppUser(
      authId: m['auth_id'] as String,
      fullName: m['full_name'] ?? '',
      email: m['email'] ?? '',
      phone: m['phone'],
      block: m['block'],
      flat: m['flat'],
      role: m['role'] ?? 'Resident',
    );
  }

  Map<String, dynamic> toMap() => {
    'auth_id': authId,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'block': block,
    'flat': flat,
    'role': role,
  };
}
