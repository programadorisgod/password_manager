import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;

  EncryptionService._internal();

  String encryptPassword(String password, String masterKey) {
    try {
      print('Encrypting password with master key length: ${masterKey.length}');
      print('Master key preview: ${masterKey.substring(0, 4)}...');
      
      final keyBytes = sha256.convert(utf8.encode(masterKey)).bytes;
      final key = Key.fromBase64(base64Encode(keyBytes));
      final iv = IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(key));

      print('Generated IV: ${iv.base64}');
      final encrypted = encrypter.encrypt(password, iv: iv);
      final result = '${iv.base64}:${encrypted.base64}';
      print('Encryption successful, result length: ${result.length}');
      return result;
    } catch (e) {
      print('Encryption error: $e');
      rethrow;
    }
  }

  String decryptPassword(String encryptedPassword, String masterKey) {
    try {
      print('Decrypting password with master key length: ${masterKey.length}');
      print('Master key preview: ${masterKey.substring(0, 4)}...');
      print('Encrypted password format: ${encryptedPassword.substring(0, 20)}...');
      
      final parts = encryptedPassword.split(':');
      if (parts.length != 2) {
        print('Invalid encrypted password format: ${parts.length} parts');
        throw Exception('Invalid encrypted password format');
      }

      final iv = IV.fromBase64(parts[0]);
      print('Using IV: ${iv.base64}');
      
      final keyBytes = sha256.convert(utf8.encode(masterKey)).bytes;
      final key = Key.fromBase64(base64Encode(keyBytes));
      final encrypter = Encrypter(AES(key));

      print('Attempting to decrypt with IV: ${iv.base64}');
      print('Encrypted part length: ${parts[1].length}');
      
      try {
        final decrypted = encrypter.decrypt64(parts[1], iv: iv);
        print('Decryption successful');
        return decrypted;
      } catch (e) {
        print('Decryption failed with error: $e');
        throw Exception('Invalid master key or corrupted data');
      }
    } catch (e) {
      print('Decryption error: $e');
      throw Exception('Invalid master key or corrupted data');
    }
  }

  String hashMasterPassword(String masterPassword) {
    return sha256.convert(utf8.encode(masterPassword)).toString();
  }

  Map<String, dynamic> exportCredentials(List<Map<String, dynamic>> credentials, String masterKey) {
    try {
      print('Exporting ${credentials.length} credentials');
      print('Using master key length: ${masterKey.length}');
      print('Master key preview: ${masterKey.substring(0, 4)}...');
      
      // Create a clean list of credentials without re-encrypting
      final processedCredentials = credentials.map((cred) {
        return {
          'id': cred['id'],
          'user_id': cred['user_id'],
          'name': cred['name'],
          'encrypted_password': cred['encrypted_password'],
          'description': cred['description'],
        };
      }).toList();
      
      final jsonData = jsonEncode(processedCredentials);
      print('JSON data length: ${jsonData.length}');
      print('JSON data preview: ${jsonData.substring(0, 100)}...');
      
      final encryptedData = encryptPassword(jsonData, masterKey);
      print('Encrypted data length: ${encryptedData.length}');
      
      final result = {
        'data': encryptedData,
        'timestamp': DateTime.now().toIso8601String(),
      };
      print('Export successful');
      return result;
    } catch (e) {
      print('Export error: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> importCredentials(String encryptedData, String masterKey) {
    try {
      print('Importing credentials with master key length: ${masterKey.length}');
      print('Master key preview: ${masterKey.substring(0, 4)}...');
      print('Encrypted data format: ${encryptedData.substring(0, 20)}...');
      
      final decryptedJson = decryptPassword(encryptedData, masterKey);
      if (decryptedJson == null) {
        print('Decryption failed');
        throw Exception('Invalid master key or corrupted data');
      }
      
      print('Decrypted JSON length: ${decryptedJson.length}');
      print('Decrypted JSON preview: ${decryptedJson.substring(0, 100)}...');
      
      final List<dynamic> data = jsonDecode(decryptedJson);
      print('Successfully parsed ${data.length} credentials');
      
      // Validate the structure of each credential
      for (final cred in data) {
        if (!cred.containsKey('name') || !cred.containsKey('encrypted_password')) {
          print('Invalid credential format: missing required fields');
          throw Exception('Invalid credential format');
        }
      }
      
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Import error: $e');
      throw Exception('Failed to import credentials: Invalid master key or corrupted data');
    }
  }
} 