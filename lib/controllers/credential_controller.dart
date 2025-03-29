import 'package:get/get.dart';
import '../models/credential.dart';
import '../services/database_helper.dart';
import '../services/encryption_service.dart';
import 'auth_controller.dart';
import 'dart:convert';

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
    if (_authController.currentUser.value != null) {
      loadCredentials();
    }
  }

  Future<void> loadCredentials() async {
    if (_authController.currentUser.value == null) {
      credentials.clear();
      return;
    }

    try {
      isLoading.value = true;
      final userId = _authController.currentUser.value!.id!;
      final loadedCredentials = await _db.getCredentials(userId);
      credentials.value = loadedCredentials;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addCredential(String name, String password, String description) async {
    if (_authController.currentUser.value == null) return false;

    try {
      isLoading.value = true;
      final userId = _authController.currentUser.value!.id!;
      final encryptedPassword = _encryptionService.encryptPassword(
        password,
        _authController.currentUser.value!.masterPassword,
      );

      final credential = Credential(
        userId: userId,
        name: name,
        encryptedPassword: encryptedPassword,
        description: description,
      );

      final id = await _db.insertCredential(credential);
      credentials.add(Credential(
        id: id,
        userId: userId,
        name: name,
        encryptedPassword: encryptedPassword,
        description: description,
      ));
      return true;
    } catch (e) {
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateCredential(
    int id,
    String name,
    String? password,
    String description,
  ) async {
    try {
      isLoading.value = true;
      final credential = credentials.firstWhere((c) => c.id == id);
      
      String encryptedPassword = credential.encryptedPassword;
      if (password != null) {
        encryptedPassword = _encryptionService.encryptPassword(
          password,
          _authController.currentUser.value!.masterPassword,
        );
      }

      final updatedCredential = Credential(
        id: id,
        userId: credential.userId,
        name: name,
        encryptedPassword: encryptedPassword,
        description: description,
      );

      await _db.updateCredential(updatedCredential);
      
      final index = credentials.indexWhere((c) => c.id == id);
      credentials[index] = updatedCredential;
      return true;
    } catch (e) {
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteCredential(int id) async {
    try {
      isLoading.value = true;
      await _db.deleteCredential(id);
      credentials.removeWhere((c) => c.id == id);
      return true;
    } catch (e) {
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String? decryptPassword(String encryptedPassword) {
    try {
      return _encryptionService.decryptPassword(
        encryptedPassword,
        _authController.currentUser.value!.masterPassword,
      );
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> exportCredentials(String masterPassword) async {
    if (!_authController.validateMasterPassword(masterPassword)) {
      throw Exception('Invalid master password');
    }

    print('Export: Starting export of ${credentials.length} credentials');
    
    final credentialsData = credentials.map((c) {
      final map = c.toMap();
      print('Export: Processing credential: ${map['name']}');
      return map;
    }).toList();

    final exportData = _encryptionService.exportCredentials(credentialsData, masterPassword);
    print('Export: Successfully created export data');
    return exportData;
  }

  Future<bool> importCredentials(String encryptedData, String masterPassword) async {
    try {
      print('Import: Starting import process');
      print('Import: Master password length: ${masterPassword.length}');
      print('Import: Master password preview: ${masterPassword.substring(0, 4)}...');

      if (_authController.currentUser.value == null) {
        print('Import error: No user logged in');
        throw Exception('No user logged in');
      }

      print('Import: Current user ID: ${_authController.currentUser.value!.id}');
      print('Import: Current user email: ${_authController.currentUser.value!.email}');

      // Clean the input data and ensure it's valid JSON
      final cleanData = encryptedData.trim();
      print('Import: Cleaned data length: ${cleanData.length}');
      print('Import: Data starts with: ${cleanData.substring(0, 20)}...');
      
      if (!cleanData.startsWith('{') || !cleanData.endsWith('}')) {
        print('Import error: Invalid JSON format - missing braces');
        throw Exception('Invalid JSON format. Make sure to copy the entire exported data.');
      }
      
      // Parse the exported data format
      Map<String, dynamic> exportData;
      try {
        exportData = jsonDecode(cleanData);
        print('Import: Successfully parsed JSON');
        print('Import: JSON keys: ${exportData.keys.join(', ')}');
      } catch (e) {
        print('Import error: JSON parsing failed - $e');
        throw Exception('Invalid JSON format. Please make sure you copied the entire exported data correctly.');
      }

      if (!exportData.containsKey('data')) {
        print('Import error: Missing data field in JSON');
        throw Exception('Invalid export data format. Missing "data" field.');
      }

      print('Import: Found data field, length: ${exportData['data'].toString().length}');
      print('Import: Data field preview: ${exportData['data'].toString().substring(0, 20)}...');

      // Decrypt the credentials data
      print('Import: Attempting to decrypt data with master password');
      final decryptedJson = _encryptionService.decryptPassword(
        exportData['data'],
        masterPassword,
      );

      if (decryptedJson == null) {
        print('Import error: Decryption failed');
        throw Exception('Invalid master password or corrupted data');
      }

      print('Import: Successfully decrypted data');
      print('Import: Decrypted data preview: ${decryptedJson.substring(0, 100)}...');

      // Parse the decrypted JSON
      List<dynamic> data;
      try {
        data = jsonDecode(decryptedJson);
        print('Import: Successfully parsed decrypted JSON');
      } catch (e) {
        print('Import error: Failed to parse decrypted JSON - $e');
        throw Exception('Invalid decrypted data format');
      }

      if (data is! List) {
        print('Import error: Decrypted data is not a list');
        throw Exception('Invalid data format: expected a list of credentials');
      }

      print('Import: Found ${data.length} credentials to import');

      final importedCredentials = data.cast<Map<String, dynamic>>();
      
      for (final credentialData in importedCredentials) {
        print('Import: Processing credential data: $credentialData');
        
        // Check for required fields
        if (!credentialData.containsKey('name')) {
          print('Import error: Missing name field in credential');
          throw Exception('Invalid credential format: missing name field');
        }
        if (!credentialData.containsKey('encrypted_password')) {
          print('Import error: Missing encrypted_password field in credential');
          throw Exception('Invalid credential format: missing encrypted_password field');
        }

        // Create a new credential with the original encrypted password
        final newCredential = Credential(
          userId: _authController.currentUser.value!.id!,
          name: credentialData['name'],
          encryptedPassword: credentialData['encrypted_password'],
          description: credentialData['description'] ?? '',
        );

        await _db.insertCredential(newCredential);
        credentials.add(newCredential);
        print('Import: Successfully imported credential: ${newCredential.name}');
      }
      
      print('Import: Successfully imported all credentials');
      return true;
    } catch (e) {
      print('Import error: $e'); // Debug print
      rethrow; // Rethrow the error to handle it in the UI
    }
  }

  Future<String?> getDecryptedPassword(Credential credential) async {
    try {
      final currentUser = _authController.currentUser.value;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }
      return _encryptionService.decryptPassword(
        credential.encryptedPassword,
        currentUser.masterPassword,
      );
    } catch (e) {
      print('Error decrypting password: $e');
      return null;
    }
  }
} 