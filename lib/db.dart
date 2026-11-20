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
