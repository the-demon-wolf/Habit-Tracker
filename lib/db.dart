  static Future<int> importCsv() async {
    final res = await FilePicker.pickFiles(type: FileType.any);
    if (res.isEmpty || res.single.path == null) return -1;
    final content = await File(res.single.path!).readAsString();
    final lines = content.split(RegExp(r'\r?\n'));
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
