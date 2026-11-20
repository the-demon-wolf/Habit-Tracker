import 'package:flutter/material.dart';

class HabitsTab extends StatefulWidget {
  final int externalTick;
  final String userName;
  final String? avatarPath;
  final VoidCallback onDataMutated;

  const HabitsTab({
    super.key,
    required this.externalTick,
    required this.userName,
    required this.avatarPath,
    required this.onDataMutated,
  });

  @override
  State<HabitsTab> createState() => _HabitsTabState();
}

class _HabitsTabState extends State<HabitsTab> {
  late DateTime _selectedDate;
  int _localRefreshCounter = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void didUpdateWidget(covariant HabitsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.externalTick != widget.externalTick) {
      // Preserve _selectedDate when external state ticks (widget/notification/resume).
      setState(() => _localRefreshCounter++);
    }
  }

  String _greetingForNow() {
    final hour = DateTime.now().hour;
    final prefix = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final cleanName = widget.userName.trim();
    return cleanName.isEmpty ? prefix : '$prefix, $cleanName';
  }
  void _shiftDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return ListView(
      key: ValueKey('habits_list_$_localRefreshCounter'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          _greetingForNow(),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => _shiftDate(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            TextButton.icon(
              onPressed: _jumpToToday,
              icon: const Icon(Icons.today, size: 18),
              label: Text(dateLabel),
            ),
            IconButton(
              onPressed: () => _shiftDate(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
