import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

class HabitDatabase {
  HabitDatabase._();
  static final HabitDatabase instance = HabitDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'habit_tracker.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE habits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            target_per_day INTEGER NOT NULL DEFAULT 1,
            color_value INTEGER NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            habit_id INTEGER NOT NULL,
            date_key TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 1,
            UNIQUE(habit_id, date_key)
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> exportCsv() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT h.id, h.title, h.target_per_day, h.color_value, h.created_at,
             l.date_key, l.count
      FROM habits h
      LEFT JOIN logs l ON h.id = l.habit_id
      ORDER BY h.id ASC, l.date_key ASC
    ''');

    final buffer = StringBuffer();
    buffer.writeln('habit_id,title,target_per_day,color_value,created_at,date_key,count');
    for (final r in rows) {
      String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
      buffer.writeln([
        esc(r['id']),
        esc(r['title']),
        esc(r['target_per_day']),
        esc(r['color_value']),
        esc(r['created_at']),
        esc(r['date_key']),
        esc(r['count']),
      ].join(','));
    }

    final dir = await getTemporaryDirectory();
    const fileName = 'habit_tracker_backup.csv';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(buffer.toString(), flush: true);

    await Share.shareXFiles([
      XFile(file.path, mimeType: 'text/csv', name: fileName),
    ]);
  }Future<int> importCsv() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.any,
    );
    if (files.isEmpty) return 0;

    final picked = files.first;
    if (picked.path == null) return 0;

    final rawContent = await File(picked.path!).readAsString();
    if (rawContent.trim().isEmpty) return 0;

    final lines = const LineSplitter().convert(rawContent);
    if (lines.length <= 1) return 0;

    final db = await database;
    int importedCount = 0;

    await db.transaction((txn) async {
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cols = _parseCsvRow(line);
        if (cols.length < 2) continue;

        final title = cols[1].trim();
        if (title.isEmpty) continue;

        final target = int.tryParse(cols.length > 2 ? cols[2] : '1') ?? 1;
        final colorVal = int.tryParse(cols.length > 3 ? cols[3] : '0xFF4F7CFF') ?? 0xFF4F7CFF;
        final createdAt = (cols.length > 4 && cols[4].isNotEmpty)
            ? cols[4]
            : DateTime.now().toIso8601String();

        final existing = await txn.query(
          'habits',
          where: 'title = ?',
          whereArgs: [title],
          limit: 1,
        );

        int habitId;
        if (existing.isNotEmpty) {
          habitId = existing.first['id'] as int;
        } else {
          habitId = await txn.insert('habits', {
            'title': title,
            'target_per_day': target < 1 ? 1 : target,
            'color_value': colorVal,
            'created_at': createdAt,
          });
        }

        final dateKey = cols.length > 5 ? cols[5].trim() : '';
        final count = int.tryParse(cols.length > 6 ? cols[6] : '0') ?? 0;
        if (dateKey.isNotEmpty && count > 0) {
          await txn.insert(
            'logs',
            {'habit_id': habitId, 'date_key': dateKey, 'count': count},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        importedCount++;
      }
    });

    return importedCount;
  }

  List<String> _parseCsvRow(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    result.add(sb.toString());
    return result;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('logs');
      await txn.delete('habits');
    });
  }
}
