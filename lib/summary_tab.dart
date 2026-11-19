import 'dart:math';
import 'package:flutter/material.dart';
import 'db.dart';
import 'glass_ui.dart';

class SummaryTab extends StatefulWidget {
  final List<Habit> todayHabits;
  final VoidCallback onDataChanged;

  const SummaryTab({super.key, required this.todayHabits, required this.onDataChanged});

  @override
  State<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<SummaryTab> {
  static const _quotes = [
    'Small daily improvements over time lead to stunning results.',
    'Discipline is choosing between what you want now and what you want most.',
    'You do not rise to the level of your goals; you fall to the level of your systems.',
    'Success is the sum of small efforts, repeated day in and day out.',
    'Consistency beats intensity every single time.',
    'Focus on being 1% better today than you were yesterday.',
  ];

  late final String _quote;
  DateTime _selectedDate = DateTime.now();
  List<Habit> _dateHabits = [];

  @override
  void initState() {
    super.initState();
    _quote = _quotes[Random().nextInt(_quotes.length)];
    _loadSelectedDate();
  }

  @override
  void didUpdateWidget(covariant SummaryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadSelectedDate();
  }

  Future<void> _loadSelectedDate() async {
    final list = await DatabaseHelper.getHabitsForDate(_selectedDate);
    if (mounted) setState(() => _dateHabits = list);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSelectedDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        const Text('Summary', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        GlassBox(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF6EE7B7), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text('“$_quote”',
                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70, height: 1.4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Habit Streaks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (widget.todayHabits.isEmpty)
          const Text('Add habits in the Today tab to see streaks.', style: TextStyle(color: Colors.white54)),
        ...widget.todayHabits.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassBox(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(child: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
                    Text('🔥 ${h.currentStreak}d', style: const TextStyle(color: Color(0xFF6EE7B7), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Text('🏆 ${h.bestStreak}d', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('History & Past Days', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GlassTap(
              radius: 14,
              onTap: _pickDate,
              child: GlassBox(
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 15, color: Color(0xFF6EE7B7)),
                    const SizedBox(width: 6),
                    Text(DatabaseHelper.dateKey(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._dateHabits.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassTap(
                onTap: () async {
                  await DatabaseHelper.toggleHabitDate(h.id!, _selectedDate, h.completedOnDate);
                  await _loadSelectedDate();
                  widget.onDataChanged();
                },
                child: GlassBox(
                  padding: const EdgeInsets.all(16),
                  glow: h.completedOnDate,
                  child: Row(
                    children: [
                      Icon(h.completedOnDate ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: h.completedOnDate ? const Color(0xFF6EE7B7) : Colors.white38),
                      const SizedBox(width: 12),
                      Expanded(child: Text(h.title)),
                      Text(h.completedOnDate ? 'Done' : 'Missed',
                          style: TextStyle(fontSize: 12, color: h.completedOnDate ? const Color(0xFF6EE7B7) : Colors.white38)),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }
}
