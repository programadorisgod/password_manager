import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/database_helper.dart';
import '../services/encryption_service.dart';

class AuthController extends GetxController {
  final _db = DatabaseHelper();
  final _encryptionService = EncryptionService();
  final _storage = FlutterSecureStorage();
  
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkLoggedInUser();
  }

  Future<void> checkLoggedInUser() async {
    final email = await _storage.read(key: 'user_email');
    if (email != null) {
      final user = await _db.getUser(email);
      currentUser.value = user;
    }
  }

  Future<bool> signUp(String email, String masterPassword) async {
    try {
      isLoading.value = true;
      final existingUser = await _db.getUser(email);
      if (existingUser != null) {
        throw Exception('User already exists');
      }

      final hashedPassword = _encryptionService.hashMasterPassword(masterPassword);
      final user = User(email: email, masterPassword: hashedPassword);
      
      final userId = await _db.insertUser(user);
      currentUser.value = User(id: userId, email: email, masterPassword: hashedPassword);
      
      await _storage.write(key: 'user_email', value: email);
      return true;
    } catch (e) {
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

      final hashedPassword = _encryptionService.hashMasterPassword(masterPassword);
      if (hashedPassword != user.masterPassword) {
        throw Exception('Invalid password');
      }

      currentUser.value = user;
      await _storage.write(key: 'user_email', value: email);
      return true;
    } catch (e) {
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    await _storage.delete(key: 'user_email');
    currentUser.value = null;
  }

  bool validateMasterPassword(String masterPassword) {
    if (currentUser.value == null) return false;
    final hashedPassword = _encryptionService.hashMasterPassword(masterPassword);
    return hashedPassword == currentUser.value!.masterPassword;
  }
} 