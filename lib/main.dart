import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';
import 'glass_ui.dart';
import 'summary_tab.dart';
import 'habits_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('theme_mode') ?? 'system';
  runApp(HabitTrackerApp(initialMode: _parseMode(saved)));
}

ThemeMode _parseMode(String v) =>
    v == 'light' ? ThemeMode.light : (v == 'dark' ? ThemeMode.dark : ThemeMode.system);

class HabitTrackerApp extends StatefulWidget {
  final ThemeMode initialMode;
  const HabitTrackerApp({super.key, required this.initialMode});

  @override
  State<HabitTrackerApp> createState() => _HabitTrackerAppState();
}

class _HabitTrackerAppState extends State<HabitTrackerApp> {
  late ThemeMode _mode = widget.initialMode;

  Future<void> _setThemeMode(ThemeMode next) async {
    setState(() => _mode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', next.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF2F3F5),
        colorScheme: const ColorScheme.light(primary: Color(0xFF00A84F)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF6EE7B7)),
      ),
      home: HomeScreen(themeMode: _mode, onThemeChanged: _setThemeMode),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const HomeScreen({super.key, required this.themeMode, required this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageCtrl;
  double _pagePos = 0.0;
  List<Habit> _todayHabits = [];
  int _refreshNonce = 0;

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
    if (mounted) {
      setState(() {
        _todayHabits = data;
        _refreshNonce++;
      });
    }
  }

  void _goToPage(int idx) {
    _pageCtrl.animateToPage(idx, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }
  void _habitSheet({Habit? existing}) {
    final p = ColorOSPalette.of(context);
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: p.text)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: TextStyle(color: p.text),
                decoration: InputDecoration(
                  hintText: 'e.g., Read 15 mins',
                  hintStyle: TextStyle(color: p.textTertiary),
                  filled: true,
                  fillColor: p.cardRaised,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: Colors.white),
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
    final p = ColorOSPalette.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        title: Text('Delete Habit?', style: TextStyle(color: p.text)),
        content: Text('Remove "${h.title}" and its streak history?', style: TextStyle(color: p.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.deleteHabit(h.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: Text('Delete', style: TextStyle(color: p.danger)),
          ),
        ],
      ),
    );
  }

  void _openDataSubpage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DataManagementPage(onChanged: _load)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorOSPalette.of(context);
    final onHabitsTab = _pagePos.round() == 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: p.page,
        body: SafeArea(
          bottom: false,
          child: PageView(
            controller: _pageCtrl,
            physics: const BouncingScrollPhysics(),
            children: [
              SummaryTab(todayHabits: _todayHabits),
              HabitsTab(
                key: ValueKey(_refreshNonce),
                onDataChanged: _load,
                onEditHabit: (h) => _habitSheet(existing: h),
                onDeleteHabit: _confirmDelete,
              ),
              _settingsView(p),
            ],
          ),
        ),
        floatingActionButton: onHabitsTab
            ? GlassTap(
                radius: 999,
                onTap: () => _habitSheet(),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.32), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Habit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              )
            : null,
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: ColorOSPillNav(pagePosition: _pagePos, onSelect: _goToPage),
          ),
        ),
      ),
    );
  }

  Widget _settingsView(ColorOSPalette p) => ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
        children: [
          Text('Settings', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: p.text)),
          const SizedBox(height: 20),
          GlassBox(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 4),
                Text('Follow device theme or lock Light / Dark mode.', style: TextStyle(fontSize: 13.5, color: p.textSecondary)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _themeChip('System', ThemeMode.system, p),
                    const SizedBox(width: 8),
                    _themeChip('Light', ThemeMode.light, p),
                    const SizedBox(width: 8),
                    _themeChip('Dark', ThemeMode.dark, p),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassTap(
            onTap: _openDataSubpage,
            child: GlassBox(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.storage_rounded, color: p.mint),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Backup & Data Management', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: p.text)),
                        const SizedBox(height: 2),
                        Text('CSV export/import, Google Drive sync, reset data', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.textTertiary),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _themeChip(String label, ThemeMode mode, ColorOSPalette p) {
    final active = widget.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onThemeChanged(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? p.mint.withValues(alpha: 0.18) : p.cardRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? p.mint : Colors.transparent, width: 1.0),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? p.mint : p.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DataManagementPage extends StatelessWidget {
  final VoidCallback onChanged;
  const DataManagementPage({super.key, required this.onChanged});

  void _confirmErase(BuildContext context, ColorOSPalette p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        title: Text('Erase All Data?', style: TextStyle(color: p.text)),
        content: Text('This permanently deletes every habit and all streak history on this device.',
            style: TextStyle(color: p.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.clearAll();
              onChanged();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Erase Everything', style: TextStyle(color: p.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorOSPalette.of(context);
    return Scaffold(
      backgroundColor: p.page,
      appBar: AppBar(
        backgroundColor: p.page,
        elevation: 0,
        iconTheme: IconThemeData(color: p.text),
        title: Text('Backup & Data', style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassBox(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offline CSV Backup', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 6),
                Text('Save your habits and logs to a local CSV file or restore from another phone.',
                    style: TextStyle(fontSize: 13.5, color: p.textSecondary)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: Colors.white),
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
                          if (count >= 0 && context.mounted) {
                            onChanged();
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
          const SizedBox(height: 16),
          GlassBox(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Google Drive Cloud Backup (Optional)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 6),
                Text('Keep the app 100% offline, or connect a Google Cloud OAuth Client ID later to sync backups privately to your Drive.',
                    style: TextStyle(fontSize: 13.5, color: p.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GlassBox(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Danger Zone', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.danger)),
                const SizedBox(height: 6),
                Text('Permanently wipe all habits and completion history from local storage.',
                    style: TextStyle(fontSize: 13.5, color: p.textSecondary)),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: BorderSide(color: p.danger)),
                  onPressed: () => _confirmErase(context, p),
                  icon: Icon(Icons.delete_forever, color: p.danger),
                  label: Text('Clear All Local Data', style: TextStyle(color: p.danger)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
