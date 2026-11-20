import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db.dart';
import 'glass_ui.dart';

class HabitsTab extends StatefulWidget {
  final VoidCallback onDataChanged;
  final ValueChanged<Habit> onEditHabit;
  final ValueChanged<Habit> onDeleteHabit;

  const HabitsTab({
    super.key,
    required this.onDataChanged,
    required this.onEditHabit,
    required this.onDeleteHabit,
  });

  @override
  State<HabitsTab> createState() => _HabitsTabState();
}

class _HabitsTabState extends State<HabitsTab> {
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _shortDay = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  DateTime _selectedDate = DatabaseHelper.dayOnly(DateTime.now());
  late DateTime _weekStart;
  List<Habit> _habits = [];
  Map<int, Set<String>> _logsByHabit = {};

  static DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(_selectedDate);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant HabitsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  Future<void> _refresh() async {
    final list = await DatabaseHelper.getHabitsForDate(_selectedDate);
    final logs = await DatabaseHelper.getAllLogsMap();
    if (mounted) {
      setState(() {
        _habits = list;
        _logsByHabit = logs;
      });
    }
  }

  int _completedCountOn(DateTime day) {
    final key = DatabaseHelper.dateKey(day);
    int c = 0;
    for (final h in _habits) {
      if ((_logsByHabit[h.id] ?? const <String>{}).contains(key)) c++;
    }
    return c;
  }

  Future<void> _pickDate() async {
    final now = DatabaseHelper.dayOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DatabaseHelper.dayOnly(picked);
        _weekStart = _mondayOf(_selectedDate);
      });
      _refresh();
    }
  }

  void _shiftWeek(int deltaWeeks) {
    final nextStart = _weekStart.add(Duration(days: deltaWeeks * 7));
    final today = DatabaseHelper.dayOnly(DateTime.now());
    if (nextStart.isAfter(today)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _weekStart = nextStart;
      final candidate = _selectedDate.add(Duration(days: deltaWeeks * 7));
      _selectedDate = candidate.isAfter(today) ? today : candidate;
    });
    _refresh();
  }
  @override
  Widget build(BuildContext context) {
    final p = ColorOSPalette.of(context);
    final today = DatabaseHelper.dayOnly(DateTime.now());
    final isToday = _selectedDate == today;
    final done = _habits.where((h) => h.completedOnDate).length;
    final titleText = isToday
        ? 'Today'
        : '${_shortDay[_selectedDate.weekday - 1]}, ${_months[_selectedDate.month - 1]} ${_selectedDate.day}';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 160),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titleText, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: p.text)),
                  Text(
                    _habits.isEmpty ? 'Tap + Habit to add a goal' : '$done of ${_habits.length} completed',
                    style: TextStyle(color: p.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
            if (!isToday)
              GlassTap(
                radius: 999,
                onTap: () {
                  setState(() {
                    _selectedDate = today;
                    _weekStart = _mondayOf(today);
                  });
                  _refresh();
                },
                child: GlassBox(
                  radius: 999,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text('Today', style: TextStyle(color: p.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -150) _shiftWeek(1);
            if (v > 150) _shiftWeek(-1);
          },
          child: GlassBox(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => _shiftWeek(-1),
                      child: Icon(Icons.chevron_left, size: 20, color: p.textSecondary),
                    ),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Row(
                        children: [
                          Text('${_months[_selectedDate.month - 1]} ${_selectedDate.year}',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: p.text)),
                          const SizedBox(width: 4),
                          Icon(Icons.expand_more, size: 16, color: p.accent),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _shiftWeek(1),
                      child: Icon(Icons.chevron_right, size: 20, color: p.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final day = _weekStart.add(Duration(days: i));
                    final isSel = day == _selectedDate;
                    final isFuture = day.isAfter(today);
                    final tot = _habits.length;
                    final ratio = (tot == 0 || isFuture) ? 0.0 : (_completedCountOn(day) / tot).clamp(0.0, 1.0);
                    return GestureDetector(
                      onTap: isFuture
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedDate = day);
                              _refresh();
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 40,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? p.accent.withValues(alpha: 0.16) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSel ? p.accent : Colors.transparent, width: 1.0),
                        ),
                        child: Column(
                          children: [
                            Text(_weekdays[i],
                                style: TextStyle(fontSize: 11, color: isFuture ? p.textTertiary : p.textSecondary)),
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
                                    backgroundColor: p.hairline,
                                    valueColor: AlwaysStoppedAnimation(p.accent),
                                  ),
                                  Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      color: isFuture ? p.textTertiary : p.text,
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
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ..._habits.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassTap(
                radius: 20,
                onTap: () async {
                  await DatabaseHelper.toggleHabitDate(h.id!, _selectedDate, h.completedOnDate);
                  await _refresh();
                  widget.onDataChanged();
                },
                onLongPress: () => widget.onDeleteHabit(h),
                child: GlassBox(
                  radius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  glow: h.completedOnDate,
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Icon(
                          h.completedOnDate ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: h.completedOnDate ? p.accent : p.textTertiary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  decoration: h.completedOnDate ? TextDecoration.lineThrough : null,
                                  color: h.completedOnDate ? p.textSecondary : p.text,
                                ),
                              ),
                              if (h.reminderTime.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(Icons.notifications_active_outlined, size: 12, color: p.accent),
                                    const SizedBox(width: 4),
                                    Text(h.reminderTime, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 18, color: p.textTertiary),
                          onPressed: () => widget.onEditHabit(h),
                        ),
                        Icon(Icons.local_fire_department, size: 16, color: p.accent),
                        const SizedBox(width: 3),
                        Text('${h.currentStreak}d', style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}
