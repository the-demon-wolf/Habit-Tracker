import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:home_widget/home_widget.dart';

class Habit {
  final int? id;
  final String title;
  final int currentStreak;
  final int bestStreak;
  final bool completedOnDate;

  Habit({
    this.id,
    required this.title,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.completedOnDate = false,
  });
}

class DatabaseHelper {
  static Database? _db;

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'habits_v2.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('CREATE TABLE habits(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT)');
        await db.execute('CREATE TABLE logs(habit_id INTEGER, date TEXT, PRIMARY KEY(habit_id, date))');
      },
    );
    return _db!;
  }

  static Future<List<Habit>> getHabitsForDate(DateTime date) async {
    final db = await database;
    final targetKey = dateKey(date);
    final habitRows = await db.query('habits', orderBy: 'id DESC');
    final logRows = await db.query('logs');

    final logsByHabit = <int, Set<String>>{};
    for (final r in logRows) {
      logsByHabit.putIfAbsent(r['habit_id'] as int, () => <String>{}).add(r['date'] as String);
    }

    return habitRows.map((row) {
      final id = row['id'] as int;
      final dates = logsByHabit[id] ?? <String>{};
      return Habit(
        id: id,
        title: row['title'] as String,
        currentStreak: _calcCurrentStreak(dates),
        bestStreak: _calcBestStreak(dates),
        completedOnDate: dates.contains(targetKey),
      );
    }).toList();
  }

  static int _calcCurrentStreak(Set<String> dates) {
    int streak = 0;
    var check = DateTime.now();
    if (!dates.contains(dateKey(check))) {
      check = check.subtract(const Duration(days: 1));
    }
    while (dates.contains(dateKey(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int _calcBestStreak(Set<String> dates) {
    if (dates.isEmpty) return 0;
    final sorted = dates.map(DateTime.parse).toList()..sort();
    int best = 1, cur = 1;
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        cur++;
        if (cur > best) best = cur;
      } else if (diff > 1) {
        cur = 1;
      }
    }
    return best;
  }

  static Future<void> addHabit(String title) async {
    final db = await database;
    await db.insert('habits', {'title': title});
    await syncWidget();
  }

  static Future<void> renameHabit(int id, String title) async {
    final db = await database;
    await db.update('habits', {'title': title}, where: 'id = ?', whereArgs: [id]);
    await syncWidget();
  }

  static Future<void> toggleHabitDate(int habitId, DateTime date, bool currentlyDone) async {
    final db = await database;
    final key = dateKey(date);
    if (currentlyDone) {
      await db.delete('logs', where: 'habit_id = ? AND date = ?', whereArgs: [habitId, key]);
    } else {
      await db.insert('logs', {'habit_id': habitId, 'date': key}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await syncWidget();
  }

  static Future<void> deleteHabit(int id) async {
    final db = await database;
    await db.delete('logs', where: 'habit_id = ?', whereArgs: [id]);
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
    await syncWidget();
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('logs');
    await db.delete('habits');
    await syncWidget();
  }

  static Future<void> syncWidget() async {
    try {
      final todayList = await getHabitsForDate(DateTime.now());
      final done = todayList.where((h) => h.completedOnDate).length;
      final preview = todayList.take(8).map((h) => '${h.completedOnDate ? "✓" : "○"} ${h.title}').join('\n');
      await HomeWidget.saveWidgetData('widget_count', '$done/${todayList.length}');
      await HomeWidget.saveWidgetData('widget_list', preview);
      await HomeWidget.updateWidget(androidName: 'HabitWidgetProvider');
    } catch (_) {}
  }
}
