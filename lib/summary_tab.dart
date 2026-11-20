import 'dart:math';
import 'package:flutter/material.dart';
import 'db.dart';
import 'glass_ui.dart';

class SummaryTab extends StatefulWidget {
  final List<Habit> todayHabits;

  const SummaryTab({super.key, required this.todayHabits});

  @override
  State<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<SummaryTab> {
  static const _quotes = [
    'Small daily improvements over time lead to stunning results.',
    'Discipline is choosing between what you want now and what you want most.',
    'You do not rise to the level of your goals; you fall to the level of your systems.',
    'Consistency beats intensity every single time.',
    'Focus on being 1% better today than you were yesterday.',
  ];
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late final String _quote;
  Map<int, Set<String>> _logsByHabit = {};
  bool _showAllStreaks = false;
  int? _expandedHabitId;

  @override
  void initState() {
    super.initState();
    _quote = _quotes[Random().nextInt(_quotes.length)];
    _loadLogs();
  }

  @override
  void didUpdateWidget(covariant SummaryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final map = await DatabaseHelper.getAllLogsMap();
    if (mounted) setState(() => _logsByHabit = map);
  }

  double _dayRatio(DateTime day) {
    if (widget.todayHabits.isEmpty) return 0.0;
    final key = DatabaseHelper.dateKey(day);
    int done = 0, active = 0;
    for (final h in widget.todayHabits) {
      if (h.createdAt.isEmpty || h.createdAt.compareTo(key) <= 0) active++;
      if ((_logsByHabit[h.id] ?? const <String>{}).contains(key)) done++;
    }
    final denom = active == 0 ? widget.todayHabits.length : active;
    return denom == 0 ? 0.0 : (done / denom).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorOSPalette.of(context);
    final rates = DatabaseHelper.computeRates(widget.todayHabits, _logsByHabit);
    final sorted = [...widget.todayHabits]..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
    final visible = _showAllStreaks ? sorted : sorted.take(6).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
      children: [
        Text('Summary', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: p.text)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Streaks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.text)),
            if (sorted.length > 6)
              GestureDetector(
                onTap: () => setState(() => _showAllStreaks = !_showAllStreaks),
                child: Text(
                  _showAllStreaks ? 'Show less' : 'Show all (${sorted.length})',
                  style: TextStyle(color: p.mint, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (sorted.isEmpty)
          GlassBox(
            padding: const EdgeInsets.all(18),
            child: Text('Add habits in the Habits tab to start building streaks.', style: TextStyle(color: p.textSecondary)),
          ),
        ..._buildStreakRows(visible, p),
        const SizedBox(height: 14),
        Text('Achievement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.text)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _rateTile('Daily', '${rates.daily}%', p)),
            const SizedBox(width: 10),
            Expanded(child: _rateTile('Weekly', '${rates.weekly}%', p)),
            const SizedBox(width: 10),
            Expanded(child: _rateTile('Monthly', '${rates.monthly}%', p)),
          ],
        ),
        const SizedBox(height: 14),
        _buildSevenDayChart(p),
        const SizedBox(height: 22),
        Text(
          '“$_quote”',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: p.textTertiary),
        ),
      ],
    );
  }
  Widget _rateTile(String label, String value, ColorOSPalette p) {
    return GlassBox(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.mint)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: p.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSevenDayChart(ColorOSPalette p) {
    final today = DatabaseHelper.dayOnly(DateTime.now());
    return GlassBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 Days', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (idx) {
                final d = today.subtract(Duration(days: 6 - idx));
                final ratio = _dayRatio(d);
                final isToday = idx == 6;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${(ratio * 100).round()}%', style: TextStyle(fontSize: 10, color: p.textTertiary)),
                    const SizedBox(height: 4),
                    Container(
                      width: 24,
                      height: 68,
                      alignment: Alignment.bottomCenter,
                      decoration: BoxDecoration(
                        color: p.cardRaised,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: 24,
                        height: (68 * ratio).clamp(ratio > 0 ? 8.0 : 0.0, 68.0),
                        decoration: BoxDecoration(
                          color: isToday ? p.mint : p.mint.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _dayLetters[d.weekday - 1],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isToday ? p.text : p.textSecondary,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStreakRows(List<Habit> list, ColorOSPalette p) {
    final rows = <Widget>[];
    for (int i = 0; i < list.length; i += 2) {
      final left = list[i];
      final right = (i + 1 < list.length) ? list[i + 1] : null;
      final expanded = (_expandedHabitId == left.id)
          ? left
          : (right != null && _expandedHabitId == right.id ? right : null);

      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _streakCard(left, p)),
                const SizedBox(width: 10),
                Expanded(child: right != null ? _streakCard(right, p) : const SizedBox.shrink()),
              ],
            ),
            if (expanded != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _thirtyDayDotsCard(expanded, p),
              ),
          ],
        ),
      ));
    }
    return rows;
  }

  Widget _streakCard(Habit h, ColorOSPalette p) {
    final isOpen = _expandedHabitId == h.id;
    return GlassTap(
      radius: 22,
      onTap: () => setState(() => _expandedHabitId = isOpen ? null : h.id),
      child: GlassBox(
        radius: 22,
        glow: isOpen,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.local_fire_department, size: 16, color: p.mint),
                const SizedBox(width: 3),
                Text('${h.currentStreak}d', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(width: 10),
                Icon(Icons.emoji_events_outlined, size: 15, color: p.textSecondary),
                const SizedBox(width: 3),
                Text('${h.bestStreak}d', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thirtyDayDotsCard(Habit h, ColorOSPalette p) {
    final today = DatabaseHelper.dayOnly(DateTime.now());
    final doneDates = _logsByHabit[h.id] ?? const <String>{};
    return GlassBox(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${h.title} · Last 30 days', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(30, (idx) {
              final d = today.subtract(Duration(days: 29 - idx));
              final hit = doneDates.contains(DatabaseHelper.dateKey(d));
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hit ? p.mint : p.cardRaised,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
