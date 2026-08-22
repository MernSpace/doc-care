import 'package:my_app/core/database/tables/medicines_schedules_table.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import './user_model.dart';
import './medicines_model.dart';
import './dose_log_table.dart';

class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');
    print(join(dbPath, "app.db"));
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            phone TEXT NOT NULL
          )
        ''');
        await db.execute('''
         CREATE TABLE medicines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          doseUnit TEXT NOT NULL,
          form TEXT NOT NULL,
          note TEXT,
          imagePath TEXT,
          startedAt TEXT NOT NULL,
          endAt TEXT,
          isActive INTEGER NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');
        // inside DBHelper._onCreate (or a migration if the table already shipped)
        await db.execute('''
  CREATE TABLE medicine_schedules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    medicineId INTEGER NOT NULL,
    times TEXT NOT NULL,
    days TEXT NOT NULL,
    startDate TEXT NOT NULL,
    endDate TEXT,
    isActive INTEGER NOT NULL DEFAULT 1,
    reminderEnabled INTEGER NOT NULL DEFAULT 1,
    createdAt TEXT NOT NULL,
    updatedAt TEXT NOT NULL,
    FOREIGN KEY (medicineId) REFERENCES medicines (id) ON DELETE CASCADE
  )
''');
        await db.execute('''
  CREATE TABLE dose_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    medicineId INTEGER NOT NULL,
    scheduleId INTEGER,
    scheduledTime TEXT NOT NULL,
    taken INTEGER NOT NULL DEFAULT 0,
    takenAt TEXT,
    createdAt TEXT NOT NULL,
    updatedAt TEXT NOT NULL,
    FOREIGN KEY (medicineId) REFERENCES medicines (id) ON DELETE CASCADE,
    FOREIGN KEY (scheduleId) REFERENCES medicine_schedules (id) ON DELETE SET NULL
  )
''');
      },
    );
  }

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UserModel>> getUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'id DESC');
    return rows.map((row) => UserModel.fromMap(row)).toList();
  }

  Future<UserModel?> getLatestUser() async {
    final users = await getUsers();
    return users.isNotEmpty ? users.first : null;
  }

  Future<int> insertMedicine(MedicineModel medicine) async {
    final db = await database;
    return db.insert('medicines', medicine.toMap());
  }

  Future<List<MedicineModel>> getMedicines() async {
    final db = await database;
    final rows = await db.query('medicines', orderBy: 'createdAt DESC');
    return rows.map((row) => MedicineModel.fromMap(row)).toList();
  }

  Future<int> updateMedicine(MedicineModel medicine) async {
    final db = await database;
    return db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMedicine(int id) async {
    final db = await database;
    return db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD methods for MedicineScheduleModel

  Future<int> insertSchedule(MedicineScheduleModel schedule) async {
    final db = await database;
    return db.insert('medicine_schedules', schedule.toMap());
  }

  Future<int> updateSchedule(MedicineScheduleModel schedule) async {
    final db = await database;
    return db.update(
      'medicine_schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<int> deleteSchedule(int id) async {
    final db = await database;
    return db.delete('medicine_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MedicineScheduleModel>> getSchedulesForMedicine(
    int medicineId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'medicine_schedules',
      where: 'medicineId = ?',
      whereArgs: [medicineId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => MedicineScheduleModel.fromMap(r)).toList();
  }

  Future<List<MedicineScheduleModel>> getAllActiveSchedules() async {
    final db = await database;
    final rows = await db.query(
      'medicine_schedules',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'startDate ASC',
    );
    return rows.map((r) => MedicineScheduleModel.fromMap(r)).toList();
  }

  Future<int> insertDoseLog(DoseLogModel dose) async {
    final db = await database;
    return db.insert('dose_logs', dose.toMap());
  }

  Future<int> updateDoseLog(DoseLogModel dose) async {
    final db = await database;
    return db.update(
      'dose_logs',
      dose.toMap(),
      where: 'id = ?',
      whereArgs: [dose.id],
    );
  }

  Future<int> markDoseTaken(int id, {DateTime? takenAt}) async {
    final db = await database;
    final now = DateTime.now();
    return db.update(
      'dose_logs',
      {
        'taken': 1,
        'takenAt': (takenAt ?? now).toIso8601String(),
        'updatedAt': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDoseLog(int id) async {
    final db = await database;
    return db.delete('dose_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DoseLogModel>> getDoseLogsForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.query(
      'dose_logs',
      where: 'scheduledTime >= ? AND scheduledTime < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'scheduledTime ASC',
    );
    return rows.map((r) => DoseLogModel.fromMap(r)).toList();
  }
}
