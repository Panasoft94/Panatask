import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

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

// --- Fonctions de Sauvegarde et Restauration mises à jour pour les chemins externes ---

static Future<String?> getDbPath() async {
  String databasesPath = await getDatabasesPath();
  return join(databasesPath, 'panatask.db');
}

static Future<String?> backupDatabaseToFile() async {
  try {
    String? dbPath = await getDbPath();
    if (dbPath == null) return null;

    // Tente d'utiliser le dossier de téléchargement, sinon utilise les documents de l'application
    Directory? externalDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    
    if (externalDir == null) return null;

    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String backupFileName = 'panatask_backup_$timestamp.db';
    String backupFilePath = join(externalDir.path, backupFileName);

    File dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.copy(backupFilePath);
      return backupFilePath; // Retourne le chemin de la sauvegarde
    }
    return null;
  } catch (e) {
    print("Erreur backup: $e");
    return null;
  }
}

static Future<bool> restoreDatabaseFromFile(String backupFilePath) async {
  try {
    String? dbPath = await getDbPath();
    if (dbPath == null) return false;

    File backupFile = File(backupFilePath);
    if (await backupFile.exists()) {
      // 1. Fermer la base actuelle avant de l'écraser
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // 2. Écraser la base de données principale avec le fichier sélectionné
      await backupFile.copy(dbPath);
      
      // 3. Réouvrir la base de données (pour la prochaine lecture)
      await geDatabse(); 

      return true;
    }
    return false;
  } catch (e) {
    print("Erreur restore: $e");
    return false;
  }
}

}