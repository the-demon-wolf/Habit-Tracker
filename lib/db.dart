import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class Habit {
  final int? id;
  final String title;
  final int streak;
  final String lastCompletedDate;

  Habit({
    this.id,
    required this.title,
    this.streak = 0,
    this.lastCompletedDate = '',
  });

  bool get isCompletedToday => lastCompletedDate == todayString();

  static String todayString() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'streak': streak,
        'lastCompletedDate': lastCompletedDate,
      };
}

class DatabaseHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'habits.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE habits(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, streak INTEGER, lastCompletedDate TEXT)',
        );
      },
    );
    return _db!;
  }

  static Future<List<Habit>> getHabits() async {
    final db = await database;
    final maps = await db.query('habits', orderBy: 'id DESC');
    return maps
        .map((m) => Habit(
              id: m['id'] as int,
              title: m['title'] as String,
              streak: m['streak'] as int,
              lastCompletedDate: m['lastCompletedDate'] as String,
            ))
        .toList();
  }

  static Future<void> insertHabit(String title) async {
    final db = await database;
    await db.insert('habits', Habit(title: title).toMap());
  }

  static Future<void> toggleHabit(Habit habit) async {
    final db = await database;
    final done = habit.isCompletedToday;
    final nextStreak = done ? (habit.streak > 0 ? habit.streak - 1 : 0) : habit.streak + 1;
    await db.update(
      'habits',
      {'streak': nextStreak, 'lastCompletedDate': done ? '' : Habit.todayString()},
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  static Future<void> deleteHabit(int id) async {
    final db = await database;
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('habits');
  }
}
