import 'package:get/get.dart';
import '../models/credential.dart';
import '../services/database_helper.dart';
import '../services/encryption_service.dart';
import 'auth_controller.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class CredentialController extends GetxController {
  final _db = DatabaseHelper();
  final _encryptionService = EncryptionService();
  final _authController = Get.find<AuthController>();

  final RxList<Credential> credentials = <Credential>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    ever(_authController.currentUser, (_) => loadCredentials());
  }

  Future<void> loadCredentials() async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value;
      if (user == null) {
        credentials.clear();
        return;
      }

      final loadedCredentials = await _db.getCredentials(user.id!);
      credentials.assignAll(loadedCredentials);
    } catch (e) {
      print('Error loading credentials: $e');
      credentials.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addCredential(String name, String password, String description) async {
    try {
      print('Adding new credential: $name');
      final user = _authController.currentUser.value;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final encryptedPassword = await _encryptionService.encrypt(password, user.masterKey);
      print('Password encrypted successfully');

      final credential = Credential(
        userId: user.id!,
        name: name,
        encryptedPassword: encryptedPassword,
        description: description,
      );

      await _db.insertCredential(credential);
      await loadCredentials();
      print('Credential added successfully');
    } catch (e) {
      print('Error adding credential: $e');
      rethrow;
    }
  }

  Future<void> updateCredential(Credential credential, String newPassword) async {
    try {
      print('Updating credential: ${credential.name}');
      final user = _authController.currentUser.value;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final encryptedPassword = await _encryptionService.encrypt(newPassword, user.masterKey);
      print('New password encrypted successfully');

      credential.encryptedPassword = encryptedPassword;
      await _db.updateCredential(credential);
      await loadCredentials();
      print('Credential updated successfully');
    } catch (e) {
      print('Error updating credential: $e');
      rethrow;
    }
  }

  Future<void> deleteCredential(int id) async {
    try {
      await _db.deleteCredential(id);
      await loadCredentials();
    } catch (e) {
      print('Error deleting credential: $e');
      rethrow;
    }
  }

  String? decryptPassword(String encryptedPassword) {
    try {
      final user = _authController.currentUser.value;
      if (user == null) {
        throw Exception('No user logged in');
      }
      return _encryptionService.decrypt(encryptedPassword, user.masterKey);
    } catch (e) {
      print('Error decrypting password: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> exportCredentials(String masterPassword) async {
    try {
      if (!_authController.validateMasterPassword(masterPassword)) {
        throw Exception('Invalid master password');
      }

      print('Export: Starting export of ${credentials.length} credentials');
      final credentialsData = credentials.map((c) => c.toMap()).toList();
      
      // Convert credentials to JSON string and encrypt it
      final jsonString = jsonEncode(credentialsData);
      final encryptedData = await _encryptionService.encrypt(jsonString, masterPassword);
      
      // Return the encrypted data directly
      return {
        'data': encryptedData,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error during export: $e');
      rethrow;
    }
  }

  Future<bool> importCredentials(String encryptedData, String masterPassword) async {
    try {
      print('Import: Starting import process');
      
      final user = _authController.currentUser.value;
      if (user == null) {
        print('Import error: No user logged in');
        throw Exception('No user logged in');
      }

      print('Import: Parsing outer structure');
      // Parse the outer structure first
      final Map<String, dynamic> importData = jsonDecode(encryptedData);
      if (!importData.containsKey('data')) {
        print('Import error: Missing data field in import structure');
        throw Exception('Invalid import data format: missing data field');
      }

      print('Import: Decrypting data field');
      // Decrypt the actual credentials data
      final decryptedData = await _encryptionService.decrypt(importData['data'], masterPassword);
      print('Import: Decrypted data length: ${decryptedData.length}');
      
      print('Import: Parsing credentials list');
      final List<dynamic> credentialsList = jsonDecode(decryptedData);
      print('Import: Found ${credentialsList.length} credentials to import');
      
      int importedCount = 0;
      List<String> duplicateNames = [];
      
      for (final item in credentialsList) {
        print('Import: Processing credential: ${item['name']}');
        try {
          // Create a new map without the id field
          final Map<String, dynamic> credentialData = Map<String, dynamic>.from(item);
          credentialData.remove('id'); // Remove the original ID
          final credential = Credential.fromMap(credentialData);
          credential.userId = user.id!; // Ensure the credential is associated with the current user
          await _db.insertCredential(credential);
          credentials.add(credential);
          importedCount++;
        } catch (e) {
          if (e.toString().contains('UNIQUE constraint failed')) {
            duplicateNames.add(item['name']);
          } else {
            rethrow;
          }
        }
      }
      
      if (duplicateNames.isNotEmpty) {
        final message = '${duplicateNames.length} credencial(es) no se importaron porque ya existen:\n${duplicateNames.join(", ")}';
        Get.snackbar(
          'Importación parcial',
          message,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
      
      if (importedCount > 0) {
        Get.snackbar(
          'Importación exitosa',
          'Se importaron $importedCount credencial(es)',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
      
      print('Import: Successfully imported $importedCount credentials');
      return true;
    } catch (e, stackTrace) {
      print('Error during import: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<String?> getDecryptedPassword(Credential credential) async {
    try {
      final user = _authController.currentUser.value;
      if (user == null) {
        throw Exception('No user logged in');
      }
      return _encryptionService.decrypt(credential.encryptedPassword, user.masterKey);
    } catch (e) {
      print('Error decrypting password: $e');
      return null;
    }
  }
} 