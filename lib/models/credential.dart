class Credential {
  final int? id;
  final int userId;
  final String name;
  final String encryptedPassword;
  final String description;

  Credential({
    this.id,
    required this.userId,
    required this.name,
    required this.encryptedPassword,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'encrypted_password': encryptedPassword,
      'description': description,
    };
  }

  factory Credential.fromMap(Map<String, dynamic> map) {
    return Credential(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      encryptedPassword: map['encrypted_password'],
      description: map['description'],
    );
  }
} 