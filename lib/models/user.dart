class User {
  final int? id;
  final String email;
  final String masterPassword;

  User({
    this.id,
    required this.email,
    required this.masterPassword,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'master_password': masterPassword,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      masterPassword: map['master_password'],
    );
  }
} 