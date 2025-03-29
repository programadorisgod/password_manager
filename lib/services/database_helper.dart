import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/credential.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get the system's local share directory
    final dbPath = Platform.environment['HOME']! + '/.local/share/password_manager';
    
    // Create the directory if it doesn't exist
    await Directory(dbPath).create(recursive: true);
    
    // Set the database path
    final dbFile = path.join(dbPath, 'password_manager.db');
    
    return await databaseFactoryFfi.openDatabase(
      dbFile,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        master_password TEXT NOT NULL,
        masterKey TEXT,
        last_login INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE credentials(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        encrypted_password TEXT NOT NULL,
        description TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  // User operations
  Future<int> insertUser(User user) async {
    final Database db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final Map<String, dynamic> userData = user.toMap();
    userData['last_login'] = now;
    
    return await db.insert('users', userData);
  }

  Future<User?> getUser(String email) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  // Credential operations
  Future<int> insertCredential(Credential credential) async {
    final Database db = await database;
    return await db.insert('credentials', credential.toMap());
  }

  Future<List<Credential>> getCredentials(int userId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'credentials',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    return List.generate(maps.length, (i) => Credential.fromMap(maps[i]));
  }

  Future<int> updateCredential(Credential credential) async {
    final Database db = await database;
    return await db.update(
      'credentials',
      credential.toMap(),
      where: 'id = ?',
      whereArgs: [credential.id],
    );
  }

  Future<int> deleteCredential(int id) async {
    final Database db = await database;
    return await db.delete(
      'credentials',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<User?> getLastLoggedInUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      orderBy: 'last_login DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }
} 