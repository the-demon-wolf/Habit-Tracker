import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    'Consistency beats intensity every single time.',
    'Focus on being 1% better today than you were yesterday.',
  ];
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _shortDay = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  late final String _quote;
  DateTime _selectedDate = _stripTime(DateTime.now());
  late DateTime _weekStart;
  Map<int, Set<String>> _logsByHabit = {};
  bool _showAllStreaks = false;
  int? _expandedHabitId;

  static DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _mondayOf(DateTime d) => _stripTime(d).subtract(Duration(days: d.weekday - 1));

  @override
  void initState() {
    super.initState();
    _quote = _quotes[Random().nextInt(_quotes.length)];
    _weekStart = _mondayOf(_selectedDate);
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

  int _habitsActiveOn(DateTime day) {
    if (widget.todayHabits.isEmpty) return 0;
    final key = DatabaseHelper.dateKey(day);
    int count = 0;
    for (final h in widget.todayHabits) {
      if (h.createdAt.isEmpty || h.createdAt.compareTo(key) <= 0) count++;
    }
    return count == 0 ? widget.todayHabits.length : count;
  }

  int _completedOn(DateTime day) {
    final key = DatabaseHelper.dateKey(day);
    int done = 0;
    for (final h in widget.todayHabits) {
      if ((_logsByHabit[h.id] ?? const <String>{}).contains(key)) done++;
    }
    return done;
  }
  int _weeklyPercent() {
    if (widget.todayHabits.isEmpty) return 0;
    final today = _stripTime(DateTime.now());
    int done = 0, possible = 0;
    for (int i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      done += _completedOn(d);
      possible += _habitsActiveOn(d);
    }
    return possible == 0 ? 0 : ((done / possible) * 100).round();
  }

  Future<void> _pickDate() async {
    final now = _stripTime(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = _stripTime(picked);
        _weekStart = _mondayOf(_selectedDate);
      });
    }
  }

  void _shiftWeek(int deltaWeeks) {
    final nextStart = _weekStart.add(Duration(days: deltaWeeks * 7));
    final today = _stripTime(DateTime.now());
    if (nextStart.isAfter(today)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _weekStart = nextStart;
      final candidate = _selectedDate.add(Duration(days: deltaWeeks * 7));
      _selectedDate = candidate.isAfter(today) ? today : candidate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedStreaks = [...widget.todayHabits]..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
    final visibleStreaks = _showAllStreaks ? sortedStreaks : sortedStreaks.take(6).toList();
    final selKey = DatabaseHelper.dateKey(_selectedDate);
    final selDone = _completedOn(_selectedDate);
    final selHeader =
        '${_shortDay[_selectedDate.weekday - 1]}, ${_months[_selectedDate.month - 1]} ${_selectedDate.day} · $selDone/${widget.todayHabits.length}';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('Summary', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  'This week: ${_weeklyPercent()}%',
                  style: const TextStyle(color: Color(0xFF6EE7B7), fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _WeekStripDelegate(
            child: Container(
              color: const Color(0xFF000000).withValues(alpha: 0.92),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: GestureDetector(
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -150) _shiftWeek(1);
                  if (v > 150) _shiftWeek(-1);
                },
                child: GlassBox(
                  radius: 20,
                  blurBackground: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => _shiftWeek(-1),
                            child: const Icon(Icons.chevron_left, size: 20, color: Colors.white60),
                          ),
                          GestureDetector(
                            onTap: _pickDate,
                            child: Row(
                              children: [
                                Text(
                                  '${_months[_selectedDate.month - 1]} ${_selectedDate.year}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.expand_more, size: 16, color: Color(0xFF6EE7B7)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _shiftWeek(1),
                            child: const Icon(Icons.chevron_right, size: 20, color: Colors.white60),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildWeekDaysRow(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(selHeader, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
              const SizedBox(height: 8),
              if (widget.todayHabits.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Add habits in Today to start tracking.', style: TextStyle(color: Colors.white54)),
                ),
              ...widget.todayHabits.map((h) {
                final done = (_logsByHabit[h.id] ?? const <String>{}).contains(selKey);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassTap(
                    radius: 16,
                    onTap: () async {
                      await DatabaseHelper.toggleHabitDate(h.id!, _selectedDate, done);
                      await _loadLogs();
                      widget.onDataChanged();
                    },
                    child: GlassBox(
                      radius: 16,
                      glow: done,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: SizedBox(
                        height: 24,
                        child: Row(
                          children: [
                            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 20, color: done ? const Color(0xFF6EE7B7) : Colors.white38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                h.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  decoration: done ? TextDecoration.lineThrough : null,
                                  color: done ? Colors.white54 : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Streaks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (sortedStreaks.length > 6)
                    GestureDetector(
                      onTap: () => setState(() => _showAllStreaks = !_showAllStreaks),
                      child: Text(
                        _showAllStreaks ? 'Show less' : 'Show all (${sortedStreaks.length})',
                        style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ..._buildStreakRows(visibleStreaks),
              const SizedBox(height: 20),
              Text(
                '“$_quote”',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white38),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekDaysRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = _weekStart.add(Duration(days: i));
        final isSel = day == _selectedDate;
        final isFuture = day.isAfter(_stripTime(DateTime.now()));
        final tot = widget.todayHabits.length;
        final ratio = (tot == 0 || isFuture) ? 0.0 : (_completedOn(day) / tot).clamp(0.0, 1.0);
        return GestureDetector(
          onTap: isFuture
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDate = day);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFF6EE7B7).withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSel ? const Color(0xFF6EE7B7) : Colors.transparent, width: 1.0),
            ),
            child: Column(
              children: [
                Text(_weekdays[i], style: TextStyle(fontSize: 11, color: isFuture ? Colors.white24 : Colors.white60)),
                const SizedBox(height: 4),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 2.2,
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF6EE7B7)),
                      ),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isFuture ? Colors.white24 : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
  List<Widget> _buildStreakRows(List<Habit> list) {
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
                Expanded(child: _streakCard(left)),
                const SizedBox(width: 10),
                Expanded(child: right != null ? _streakCard(right) : const SizedBox.shrink()),
              ],
            ),
            if (expanded != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _thirtyDayDotsCard(expanded),
              ),
          ],
        ),
      ));
    }
    return rows;
  }

  Widget _streakCard(Habit h) {
    final isOpen = _expandedHabitId == h.id;
    return GlassTap(
      radius: 18,
      onTap: () => setState(() => _expandedHabitId = isOpen ? null : h.id),
      child: GlassBox(
        radius: 18,
        glow: isOpen,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_fire_department, size: 15, color: Color(0xFF6EE7B7)),
                const SizedBox(width: 3),
                Text('${h.currentStreak}d', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                const Icon(Icons.emoji_events_outlined, size: 15, color: Colors.white54),
                const SizedBox(width: 3),
                Text('${h.bestStreak}d', style: const TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thirtyDayDotsCard(Habit h) {
    final today = _stripTime(DateTime.now());
    final doneDates = _logsByHabit[h.id] ?? const <String>{};
    return GlassBox(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${h.title} · Last 30 days', style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
                  color: hit ? const Color(0xFF6EE7B7) : Colors.white.withValues(alpha: 0.10),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _WeekStripDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _WeekStripDelegate({required this.child});

  @override
  double get minExtent => 104;
  @override
  double get maxExtent => 104;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _WeekStripDelegate oldDelegate) => true;
}
