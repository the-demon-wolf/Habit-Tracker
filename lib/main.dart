import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db.dart';

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
  List<Habit> _habits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.getHabits();
    if (mounted) setState(() => _habits = data);
  }

  void _addDialog() {
    final ctrl = TextEditingController();
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
              const Text('New Habit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                  if (ctrl.text.trim().isNotEmpty) {
                    await DatabaseHelper.insertHabit(ctrl.text.trim());
                    HapticFeedback.mediumImpact();
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  }
                },
                child: const Text('Save Habit', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _habits.where((h) => h.isCompletedToday).length;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned(top: -80, left: -60, child: _orb(const Color(0xFF3B82F6), 0.22)),
          Positioned(bottom: 100, right: -80, child: _orb(const Color(0xFF10B981), 0.18)),
          SafeArea(bottom: false, child: _tab == 0 ? _todayList(done) : _settings()),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _addDialog,
              backgroundColor: const Color(0xFF6EE7B7),
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('Habit', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
          child: GlassBox(
            radius: 40,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [_nav(Icons.check_circle_outline, 'Today', 0), _nav(Icons.tune, 'Settings', 1)],
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
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: on ? const Color(0xFF6EE7B7) : Colors.white60),
            if (on) ...[const SizedBox(width: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w600))],
          ],
        ),
      ),
    );
  }

  Widget _todayList(int done) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const Text('Today', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text(_habits.isEmpty ? 'Tap + Habit to add a goal' : '$done of ${_habits.length} completed',
              style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 20),
          ..._habits.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await DatabaseHelper.toggleHabit(h);
                    _load();
                  },
                  onLongPress: () async {
                    HapticFeedback.heavyImpact();
                    await DatabaseHelper.deleteHabit(h.id!);
                    _load();
                  },
                  child: GlassBox(
                    radius: 22,
                    padding: const EdgeInsets.all(18),
                    glow: h.isCompletedToday,
                    child: Row(
                      children: [
                        Icon(h.isCompletedToday ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: h.isCompletedToday ? const Color(0xFF6EE7B7) : Colors.white38),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(h.title,
                              style: TextStyle(
                                  fontSize: 17,
                                  decoration: h.isCompletedToday ? TextDecoration.lineThrough : null,
                                  color: h.isCompletedToday ? Colors.white54 : Colors.white)),
                        ),
                        Text('🔥 ${h.streak}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      );

  Widget _settings() => Padding(
        padding: const EdgeInsets.all(20),
        child: GlassBox(
          radius: 22,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('100% Offline & Private', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Saved locally on your OnePlus 15. No internet, ads, or tracking.',
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

class GlassBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool glow;

  const GlassBox({super.key, required this.child, this.radius = 20, this.padding, this.margin, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow ? [BoxShadow(color: const Color(0xFF6EE7B7).withValues(alpha: 0.18), blurRadius: 18)] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.04)],
              ),
              border: Border.all(
                width: 1.1,color: glow ? const Color(0xFF6EE7B7).withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.16),
),
),
child: child,
),
),
),
);
}
}
                
