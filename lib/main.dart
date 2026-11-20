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
  runApp(const HabitTrackerApp());
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
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
  late final PageController _pageCtrl;
  double _pagePos = 0.0;
  List<Habit> _todayHabits = [];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0)
      ..addListener(() {
        if (_pageCtrl.hasClients && _pageCtrl.page != null) {
          setState(() => _pagePos = _pageCtrl.page!);
        }
      });
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.getHabitsForDate(DateTime.now());
    await DatabaseHelper.syncWidget();
    if (mounted) setState(() => _todayHabits = data);
  }

  void _goToPage(int idx) {
    _pageCtrl.animateToPage(
      idx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
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
          blurBackground: true,
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
        backgroundColor: const Color(0xFF141820),
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
    final onTodayTab = _pagePos.round() == 1;

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pageCtrl,
          physics: const BouncingScrollPhysics(),
          children: [
            SummaryTab(todayHabits: _todayHabits, onDataChanged: _load),
            _todayView(done),
            _settingsView(),
          ],
        ),
      ),
      floatingActionButton: onTodayTab
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: ColorOSPillNav(pagePosition: _pagePos, onSelect: _goToPage),
        ),
      ),
    );
  }
  Widget _todayView(int done) => ListView(
        physics: const BouncingScrollPhysics(),
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

  Widget _settingsView() => ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const Text('Settings', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GlassBox(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Offline Backup & Transfer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Export your habits and history to a CSV file or restore from a previous backup.',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6EE7B7), foregroundColor: Colors.black),
                        onPressed: () => DatabaseHelper.exportCsv(),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Export CSV'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final count = await DatabaseHelper.importCsv();
                          if (count >= 0 && mounted) {
                            await _load();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Imported $count completion records')),
                            );
                          }
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Import CSV'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassBox(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('100% Offline & Private', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Saved locally on your OnePlus 15. Long-press any habit in Today to delete it.',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
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
        ],
      );
}
