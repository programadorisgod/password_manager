class User {
  int? id;
  final String email;
  final String masterPassword;
  final String masterKey;

  User({
    this.id,
    required this.email,
    required this.masterPassword,
    required this.masterKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'master_password': masterPassword,
      'masterKey': masterKey,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      masterPassword: map['master_password'],
      masterKey: map['masterKey'],
    );
  }
} 