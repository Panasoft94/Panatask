import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class DbHelper{

  static Database? _database;
  //recuperation de la base de données
  static Future<Database>geDatabse() async{
    if(_database != null){
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }
  //initialisation de la base
static Future<Database>_initDatabase() async{
    String path = join(await getDatabasesPath(), 'panatask.db');
    return await openDatabase(
        path, version: 2, // Version incrémentée pour la migration de schéma
        onCreate: (db, version){
          return db.execute(
            'CREATE TABLE taches(id INTEGER PRIMARY KEY AUTOINCREMENT, titre TEXT, description TEXT, date TEXT, heure TEXT, date_fin TEXT, creation TEXT, modification TEXT, status INTEGER)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Logique de migration pour ajouter les nouvelles colonnes
            await db.execute('ALTER TABLE taches ADD COLUMN date_fin TEXT');
            await db.execute('ALTER TABLE taches ADD COLUMN creation TEXT');
            await db.execute('ALTER TABLE taches ADD COLUMN modification TEXT');
          }
        });
}

//insertion des tâches
static Future<int>insert(String titre, String description,String date, String heure, String dateFin) async{
  final db = await geDatabse();
  String now = DateTime.now().toString();
  return await db.insert('taches', {
    'titre': titre,
    'description': description,
    'date': date,
    'heure': heure,
    'date_fin': dateFin,
    'creation': now,
    'modification': now,
    'status': 0
  });
}

//modification des tâches
static Future<int>update(int id, int status) async{
  final db = await geDatabse();
  String now = DateTime.now().toString();
  return await db.update('taches', {'status': status, 'modification': now}, where: 'id = ?', whereArgs: [id]);
}
//modification des informations d'une tâche
  static Future<int>updateTask(int id, String titre, String description, String date, String dateFin) async{
    final db = await geDatabse();
    String now = DateTime.now().toString();
    return await db.update('taches', {
      'titre': titre,
      'description': description,
      'date': date,
      'date_fin': dateFin,
      'modification': now
    }, where: 'id = ?', whereArgs: [id]);
  }
//suppression des tâches
static Future<int>delete(int id) async{
    final db = await geDatabse();
  return await db.delete('taches', where: 'id = ?', whereArgs: [id]);
}

//recuperation des tâches
static Future<List<Map<String, dynamic>>>getTasks() async{
    final db = await geDatabse();
    return await db.rawQuery('''SELECT * FROM taches ORDER BY date ASC''');
}

//reinitialisation de la base
static Future<void>resetDatabase() async{
    final db = await geDatabse();
    await db.execute('DROP TABLE IF EXISTS taches');
    await db.execute('CREATE TABLE taches(id INTEGER PRIMARY KEY AUTOINCREMENT, titre TEXT, description TEXT, date TEXT, heure TEXT, date_fin TEXT, creation TEXT, modification TEXT, status INTEGER)');
}

  // --- Fonctions de Sauvegarde et Restauration mises à jour ---

  //sauvegarde de la base de données
  static Future<String?> backupDatabaseToFile() async {
    // NOTE: This logic now includes its own permission request.
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        print("Storage permission was not granted.");
        return null;
      }
    }
    try {
      final dbPath = await getDatabasesPath();
      final sourceFile = File(join(dbPath, 'panatask.db'));

      if (!await sourceFile.exists()) {
        print("Source DB file not found.");
        return null;
      }
      
      final backupDir = Directory("/storage/emulated/0/Download/PanaTaskBackups");

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      final backupFilePath = join(backupDir.path, "panatask-backup-${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db");

      final backedUpFile = await sourceFile.copy(backupFilePath);
      print("Database backed up to: ${backedUpFile.path}");
      return backedUpFile.path;

    } catch (e) {
      print("Error during backup: $e");
      return null;
    }
  }

  //restauration de la base de données
  static Future<bool> restoreDatabaseFromFile(String backupFilePath) async {
    // NOTE: This logic now includes its own permission request.
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
         print("Storage permission was not granted.");
        return false;
      }
    }
    try{
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'panatask.db'));
      final backupFile = File(backupFilePath);

      if (await backupFile.exists()) {
        if (_database != null && _database!.isOpen) {
            await _database!.close();
        }
        _database = null;
        
        await backupFile.copy(dbFile.path);
        
        await geDatabse(); // Re-initialize the database connection
        
        print("Database restored successfully from: $backupFilePath");
        return true;
      } else {
        print("Source DB file for restore not found: ${backupFile.path}");
        return false;
      }
    }
    catch (e){
      print("Error during restore: $e");
      return false;
    }
  }

  static Future<String?> getDbPath() async {
    String databasesPath = await getDatabasesPath();
    return join(databasesPath, 'panatask.db');
  }
}
