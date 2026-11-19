import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db.dart';
import 'glass_ui.dart';
import 'summary_tab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(const GlassHabitApp());
}

class GlassHabitApp extends StatelessWidget {
  const GlassHabitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glass Habits',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07090E),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF6EE7B7)),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  List<Habit> _todayHabits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.getHabitsForDate(DateTime.now());
    await DatabaseHelper.syncWidget();
    if (mounted) setState(() => _todayHabits = data);
  }

  void _habitSheet({Habit? existing}) {
    final ctrl = TextEditingController(text: existing?.title ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: GlassBox(
          radius: 26,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'New Habit' : 'Edit Habit',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g., Read 15 mins',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6EE7B7), foregroundColor: Colors.black),
                onPressed: () async {
                  final text = ctrl.text.trim();
                  if (text.isNotEmpty) {
                    if (existing == null) {
                      await DatabaseHelper.addHabit(text);
                    } else {
                      await DatabaseHelper.renameHabit(existing.id!, text);
                    }
                    HapticFeedback.mediumImpact();
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  }
                },
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Habit h) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121722),
        title: const Text('Delete Habit?'),
        content: Text('Remove "${h.title}" and its streak history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.deleteHabit(h.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _todayHabits.where((h) => h.completedOnDate).length;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned(top: -80, left: -60, child: _orb(const Color(0xFF3B82F6), 0.22)),
          Positioned(bottom: 100, right: -80, child: _orb(const Color(0xFF10B981), 0.18)),
          SafeArea(
            bottom: false,
            child: _tab == 0
                ? SummaryTab(todayHabits: _todayHabits, onDataChanged: _load)
                : (_tab == 1 ? _todayView(done) : _settingsView()),
          ),
        ],
      ),
      floatingActionButton: _tab == 1
          ? GlassTap(
              radius: 28,
              onTap: () => _habitSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(color: const Color(0xFF6EE7B7), borderRadius: BorderRadius.circular(28)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.black),
                    SizedBox(width: 6),
                    Text('Habit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          : null,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: GlassBox(
            radius: 40,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _nav(Icons.insights, 'Summary', 0),
                _nav(Icons.check_circle_outline, 'Today', 1),
                _nav(Icons.tune, 'Settings', 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _orb(Color c, double a) => Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: a)),
      );

  Widget _nav(IconData icon, String label, int idx) {
    final on = _tab == idx;
    return GlassTap(
      radius: 30,
      onTap: () => setState(() => _tab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: on ? const Color(0xFF6EE7B7) : Colors.white60),
            if (on) ...[const SizedBox(width: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))],
          ],
        ),
      ),
    );
  }

  Widget _todayView(int done) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const Text('Today', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text(_todayHabits.isEmpty ? 'Tap + Habit to add a goal' : '$done of ${_todayHabits.length} completed',
              style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 20),
          ..._todayHabits.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassTap(
                  onTap: () async {
                    await DatabaseHelper.toggleHabitDate(h.id!, DateTime.now(), h.completedOnDate);
                    _load();
                  },
                  onLongPress: () => _confirmDelete(h),
                  child: GlassBox(
                    padding: const EdgeInsets.all(16),
                    glow: h.completedOnDate,
                    child: Row(
                      children: [
                        Icon(h.completedOnDate ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: h.completedOnDate ? const Color(0xFF6EE7B7) : Colors.white38),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(h.title,
                              style: TextStyle(
                                  fontSize: 16,
                                  decoration: h.completedOnDate ? TextDecoration.lineThrough : null,
                                  color: h.completedOnDate ? Colors.white54 : Colors.white)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white38),
                          onPressed: () => _habitSheet(existing: h),
                        ),
                        Text('🔥 ${h.currentStreak}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      );

  Widget _settingsView() => Padding(
        padding: const EdgeInsets.all(20),
        child: GlassBox(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('100% Offline & Private', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Saved locally on your OnePlus 15. Long-press any habit in Today to delete it.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await DatabaseHelper.clearAll();
                  _load();
                },
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: const Text('Clear All Data', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      );
}
