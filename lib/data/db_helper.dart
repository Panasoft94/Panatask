
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:path/path.dart';

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
        path, version: 1,
        onCreate: (db, version){
          return db.execute(
            'CREATE TABLE taches(id INTEGER PRIMARY KEY AUTOINCREMENT, titre TEXT, description TEXT, date TEXT, heure TEXT,status INTEGER)');
        });
}

//insertion des tâches
static Future<int>insert(String titre, String description,String date, String heure) async{
  final db = await geDatabse();
  return await db.insert('taches', {'titre': titre, 'description': description, 'date': date, 'heure': heure, 'status': 0});
}

//modification des tâches
static Future<int>update(int id, int status) async{
  final db = await geDatabse();
  return await db.update('taches', {'status': status}, where: 'id = ?', whereArgs: [id]);
}
//modification des informations d'une tâche
  static Future<int>updateTask(int id, String titre, String description, String date) async{
    final db = await geDatabse();
    return await db.update('taches', {'titre': titre, 'description': description, 'date': date}, where: 'id = ?', whereArgs: [id]);
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
    await db.execute('DROP TABLE taches');
    await db.execute('CREATE TABLE taches(id INTEGER PRIMARY KEY AUTOINCREMENT, titre TEXT, description TEXT, date TEXT, heure TEXT,status INTEGER)');
}

}