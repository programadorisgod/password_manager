import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import '../models/user.dart';
import '../services/database_helper.dart';
import '../services/encryption_service.dart';

class AuthController extends GetxController {
  final _db = DatabaseHelper();
  final _encryptionService = EncryptionService();
  final _storage = FlutterSecureStorage();
  
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isLoading = false.obs;

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  @override
  void onInit() {
    super.onInit();
    checkLoggedInUser();
  }

  Future<void> checkLoggedInUser() async {
    try {
      // En Linux, si hay un error con el keyring, intentamos usar la base de datos directamente
      if (Platform.isLinux) {
        final user = await _db.getLastLoggedInUser();
        if (user != null) {
          currentUser.value = user;
          return;
        }
      }

      final email = await _storage.read(key: 'email');
      final masterKey = await _storage.read(key: 'master_key');
      final masterPassword = await _storage.read(key: 'master_password');
      
      if (email != null && masterKey != null && masterPassword != null) {
        currentUser.value = User(
          email: email,
          masterKey: masterKey,
          masterPassword: masterPassword,
        );
      } else {
        currentUser.value = null;
      }
    } catch (e) {
      print('Error checking logged in user: $e');
      // En Linux, si hay un error con el keyring, intentamos usar la base de datos
      if (Platform.isLinux) {
        try {
          final user = await _db.getLastLoggedInUser();
          if (user != null) {
            currentUser.value = user;
          } else {
            currentUser.value = null;
          }
        } catch (dbError) {
          print('Error accessing database: $dbError');
          currentUser.value = null;
        }
      } else {
        currentUser.value = null;
      }
    }
  }

  Future<bool> signUp(String email, String masterPassword) async {
    try {
      isLoading.value = true;
      final existingUser = await _db.getUser(email);
      if (existingUser != null) {
        throw Exception('User already exists');
      }

      final hashedPassword = _hashPassword(masterPassword);
      final masterKey = base64Encode(List<int>.generate(32, (i) => i % 256));
      
      final user = User(
        email: email,
        masterPassword: hashedPassword,
        masterKey: masterKey,
      );
      
      final userId = await _db.insertUser(user);
      user.id = userId; // Establecer el ID del usuario
      currentUser.value = user;
      
      // En Linux, si hay un error con el keyring, solo guardamos en la base de datos
      if (!Platform.isLinux) {
        await _storage.write(key: 'email', value: email);
        await _storage.write(key: 'master_key', value: masterKey);
        await _storage.write(key: 'master_password', value: hashedPassword);
      }
      
      return true;
    } catch (e) {
      print('Error during signup: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> signIn(String email, String masterPassword) async {
    try {
      isLoading.value = true;
      final user = await _db.getUser(email);
      if (user == null) {
        throw Exception('User not found');
      }

      final hashedPassword = _hashPassword(masterPassword);
      if (hashedPassword != user.masterPassword) {
        throw Exception('Invalid password');
      }

      currentUser.value = user;
      
      // En Linux, si hay un error con el keyring, solo guardamos en la base de datos
      if (!Platform.isLinux) {
        await _storage.write(key: 'email', value: email);
        await _storage.write(key: 'master_key', value: user.masterKey);
        await _storage.write(key: 'master_password', value: hashedPassword);
      }
      
      return true;
    } catch (e) {
      print('Error during signin: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    if (!Platform.isLinux) {
      await _storage.delete(key: 'email');
      await _storage.delete(key: 'master_key');
      await _storage.delete(key: 'master_password');
    }
    currentUser.value = null;
  }

  bool validateMasterPassword(String masterPassword) {
    if (currentUser.value == null) return false;
    final hashedPassword = _hashPassword(masterPassword);
    return hashedPassword == currentUser.value!.masterPassword;
  }
} 