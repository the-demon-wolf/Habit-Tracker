import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class Habit {
  final int? id;
  final String title;
  final String createdAt;
  final String reminderTime;
  final int currentStreak;
  final int bestStreak;
  final bool completedOnDate;

  Habit({
    this.id,
    required this.title,
    this.createdAt = '',
    this.reminderTime = '',
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.completedOnDate = false,
  });
}

class DatabaseHelper {
  static Database? _db;

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static ({int current, int best}) calculateStreaks(Set<String> dates) {
    if (dates.isEmpty) return (current: 0, best: 0);
    int current = 0;
    var check = dayOnly(DateTime.now());
    if (!dates.contains(dateKey(check))) {
      check = check.subtract(const Duration(days: 1));
    }
    while (dates.contains(dateKey(check))) {
      current++;
      check = check.subtract(const Duration(days: 1));
    }

    final sorted = dates.map(DateTime.parse).toList()..sort();
    int best = 1, run = 1;
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        run++;
        if (run > best) best = run;
      } else if (diff > 1) {
        run = 1;
      }
    }
    return (current: current, best: best < current ? current : best);
  }

  static DateTime? earliestDate(List<Habit> habits, Map<int, Set<String>> logs) {
    DateTime? minD;
    for (final h in habits) {
      if (h.createdAt.isNotEmpty) {
        final d = DateTime.tryParse(h.createdAt);
        if (d != null && (minD == null || d.isBefore(minD))) minD = dayOnly(d);
      }
    }
    for (final s in logs.values) {
      for (final k in s) {
        final d = DateTime.tryParse(k);
        if (d != null && (minD == null || d.isBefore(minD))) minD = dayOnly(d);
      }
    }
    return minD;
  }

  static ({int daily, int weekly, int monthly}) computeRates(
    List<Habit> habits,
    Map<int, Set<String>> logs,
  ) {
    if (habits.isEmpty) return (daily: 0, weekly: 0, monthly: 0);
    final today = dayOnly(DateTime.now());
    final first = earliestDate(habits, logs) ?? today;
    final elapsedTotal = today.difference(first).inDays + 1;

    int rateOver(int maxDays) {
      final span = elapsedTotal < maxDays ? elapsedTotal : maxDays;
      if (span <= 0) return 0;
      int done = 0, possible = 0;
      for (int i = 0; i < span; i++) {
        final d = today.subtract(Duration(days: i));
        final key = dateKey(d);
        int active = 0;
        for (final h in habits) {
          final hFirst = _habitStart(h, logs[h.id] ?? const <String>{});
          if (!d.isBefore(hFirst)) {
            active++;
            if ((logs[h.id] ?? const <String>{}).contains(key)) done++;
          }
        }
        possible += active;
      }
      return possible == 0 ? 0 : ((done / possible) * 100).round();
    }

    return (daily: rateOver(1), weekly: rateOver(7), monthly: rateOver(30));
  }

  static DateTime _habitStart(Habit h, Set<String> dates) {
    DateTime? start = h.createdAt.isNotEmpty ? DateTime.tryParse(h.createdAt) : null;
    for (final k in dates) {
      final d = DateTime.tryParse(k);
      if (d != null && (start == null || d.isBefore(start))) start = d;
    }
    return dayOnly(start ?? DateTime.now());
  }
  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'habits_v2.db'),
      version: 3,
      onCreate: (db, v) async {
        await db.execute(
            'CREATE TABLE habits(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, created_at TEXT, reminder_time TEXT)');
        await db.execute('CREATE TABLE logs(habit_id INTEGER, date TEXT, PRIMARY KEY(habit_id, date))');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await db.execute('ALTER TABLE habits ADD COLUMN created_at TEXT');
        if (oldV < 3) await db.execute('ALTER TABLE habits ADD COLUMN reminder_time TEXT');
      },
    );
    return _db!;
  }

  static Future<Map<int, Set<String>>> getAllLogsMap() async {
    final db = await database;
    final logRows = await db.query('logs');
    final map = <int, Set<String>>{};
    for (final r in logRows) {
      map.putIfAbsent(r['habit_id'] as int, () => <String>{}).add(r['date'] as String);
    }
    return map;
  }

  static Future<List<Habit>> getHabitsForDate(DateTime date) async {
    final db = await database;
    final targetKey = dateKey(date);
    final habitRows = await db.query('habits', orderBy: 'id DESC');
    final logsByHabit = await getAllLogsMap();

    return habitRows.map((row) {
      final id = row['id'] as int;
      final dates = logsByHabit[id] ?? <String>{};
      final streaks = calculateStreaks(dates);
      return Habit(
        id: id,
        title: row['title'] as String,
        createdAt: (row['created_at'] as String?) ?? '',
        reminderTime: (row['reminder_time'] as String?) ?? '',
        currentStreak: streaks.current,
        bestStreak: streaks.best,
        completedOnDate: dates.contains(targetKey),
      );
    }).toList();
  }

  static Future<int> addHabit(String title, {String reminderTime = ''}) async {
    final db = await database;
    final id = await db.insert('habits', {
      'title': title,
      'created_at': dateKey(DateTime.now()),
      'reminder_time': reminderTime,
    });
    await syncWidget();
    return id;
  }

  static Future<void> updateHabit(int id, String title, {String reminderTime = ''}) async {
    final db = await database;
    await db.update('habits', {'title': title, 'reminder_time': reminderTime}, where: 'id = ?', whereArgs: [id]);
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

  static Future<void> exportCsv() async {
    final db = await database;
    final habits = await db.query('habits');
    final logs = await db.query('logs');
    final titleById = {for (final h in habits) h['id'] as int: h['title'] as String};
    final buf = StringBuffer('habit_title,created_at,completed_date\n');
    for (final h in habits) {
      final t = (h['title'] as String).replaceAll('"', '""');
      final c = (h['created_at'] as String?) ?? '';
      buf.writeln('"$t","$c",""');
    }
    for (final l in logs) {
      final t = (titleById[l['habit_id'] as int] ?? '').replaceAll('"', '""');
      if (t.isNotEmpty) buf.writeln('"$t","","${l['date']}"');
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'habit_tracker_backup_${dateKey(DateTime.now())}.csv'));
    await file.writeAsString(buf.toString());
    await Share.shareXFiles([XFile(file.path)], text: 'Habit Tracker Offline Backup');
  }

  static Future<int> importCsv() async {
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (res.isEmpty || res.single.path == null) return -1;
    final lines = await File(res.single.path!).readAsLines();
    if (lines.length < 2) return 0;

    final db = await database;
    final existing = await db.query('habits');
    final idByTitle = {for (final h in existing) (h['title'] as String).toLowerCase(): h['id'] as int};
    int importedLogs = 0;

    for (int i = 1; i < lines.length; i++) {
      final parts = _parseCsvRow(lines.elementAt(i));
      if (parts.isEmpty || parts.first.trim().isEmpty) continue;
      final title = parts.first.trim();
      final created = parts.length > 1 ? parts.elementAt(1).trim() : '';
      final logDate = parts.length > 2 ? parts.elementAt(2).trim() : '';

      int? habitId = idByTitle[title.toLowerCase()];
      if (habitId == null) {
        habitId = await db.insert('habits', {
          'title': title,
          'created_at': created.isNotEmpty ? created : dateKey(DateTime.now()),
          'reminder_time': '',
        });
        idByTitle[title.toLowerCase()] = habitId;
      }
      if (logDate.isNotEmpty) {
        await db.insert('logs', {'habit_id': habitId, 'date': logDate}, conflictAlgorithm: ConflictAlgorithm.ignore);
        importedLogs++;
      }
    }
    await syncWidget();
    return importedLogs;
  }

  static List<String> _parseCsvRow(String row) {
    final out = <String>[];
    final cur = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < row.length; i++) {
      final ch = row.substring(i, i + 1);
      if (ch == '"') {
        if (inQuotes && i + 1 < row.length && row.substring(i + 1, i + 2) == '"') {
          cur.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        out.add(cur.toString());
        cur.clear();
      } else {
        cur.write(ch);
      }
    }
    out.add(cur.toString());
    return out;
  }

  static Future<void> syncWidget() async {
    try {
      final todayList = await getHabitsForDate(DateTime.now());
      final logs = await getAllLogsMap();
      final done = todayList.where((h) => h.completedOnDate).length;
      final rates = computeRates(todayList, logs);
      final encoded = todayList.take(5).map((h) => '${h.id}|${h.completedOnDate ? 1 : 0}|${h.title}').join('\n');
      await HomeWidget.saveWidgetData('widget_done', done);
      await HomeWidget.saveWidgetData('widget_total', todayList.length);
      await HomeWidget.saveWidgetData('widget_daily', '${rates.daily}%');
      await HomeWidget.saveWidgetData('widget_items', encoded);
      await HomeWidget.updateWidget(
        name: 'HabitWidgetProvider',
        qualifiedAndroidName: 'com.example.habit_tracker.HabitWidgetProvider',
      );
    } catch (_) {}
  }
}

