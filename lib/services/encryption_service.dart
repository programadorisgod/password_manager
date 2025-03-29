import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  Future<String> encrypt(String data, String masterKey) async {
    try {
      print('Encrypting data with master key length: ${masterKey.length}');
      print('Master key preview: ${masterKey.substring(0, 4)}...');
      
      final keyBytes = sha256.convert(utf8.encode(masterKey)).bytes;
      final key = Key.fromBase64(base64Encode(keyBytes));
      final iv = IV.fromSecureRandom(16);
      print('Generated IV: ${iv.base64}');
      
      final encrypter = Encrypter(AES(key));
      final encrypted = encrypter.encrypt(data, iv: iv);
      print('Encrypted password format: ${encrypted.base64.substring(0, 20)}...');
      
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      print('Error during encryption: $e');
      rethrow;
    }
  }

  String decrypt(String encryptedData, String masterKey) {
    try {
      print('Decrypting data with master key length: ${masterKey.length}');
      print('Encrypted data preview: ${encryptedData.substring(0, 20)}...');
      
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        throw Exception('Invalid encrypted data format');
      }
      
      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);
      
      final keyBytes = sha256.convert(utf8.encode(masterKey)).bytes;
      final key = Key.fromBase64(base64Encode(keyBytes));
      final encrypter = Encrypter(AES(key));
      
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      print('Decryption successful');
      
      return decrypted;
    } catch (e) {
      print('Error during decryption: $e');
      rethrow;
    }
  }

  Future<String> exportCredentials(List<Map<String, dynamic>> credentials, String masterKey) async {
    try {
      print('Exporting ${credentials.length} credentials');
      final jsonData = jsonEncode(credentials);
      print('JSON data preview: ${jsonData.substring(0, 100)}...');
      
      final encryptedData = await encrypt(jsonData, masterKey);
      print('Encrypted data length: ${encryptedData.length}');
      
      return encryptedData;
    } catch (e) {
      print('Error during export: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> importCredentials(String encryptedData, String masterKey) async {
    try {
      print('Importing credentials with master key length: ${masterKey.length}');
      print('Encrypted data preview: ${encryptedData.substring(0, 100)}...');
      
      final cleanData = encryptedData.trim();
      final decryptedData = decrypt(cleanData, masterKey);
      print('Decrypted data preview: ${decryptedData.substring(0, 100)}...');
      
      final List<dynamic> jsonData = jsonDecode(decryptedData);
      print('Successfully parsed JSON data, found ${jsonData.length} credentials');
      
      return jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      print('Error during import: $e');
      rethrow;
    }
  }
} 