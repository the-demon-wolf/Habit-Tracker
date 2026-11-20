import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p_path;
import 'db.dart';
import 'glass_ui.dart';
import 'summary_tab.dart';
import 'habits_tab.dart';
import 'notifications.dart';

const _navChannel = MethodChannel('habit_tracker/nav');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await NotificationHelper.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(HabitTrackerApp(prefs: prefs));
}

class HabitTrackerApp extends StatefulWidget {
  final SharedPreferences prefs;
  const HabitTrackerApp({super.key, required this.prefs});

  @override
  State<HabitTrackerApp> createState() => _HabitTrackerAppState();
}

class _HabitTrackerAppState extends State<HabitTrackerApp> {
  late ThemeMode _mode = _parseMode(widget.prefs.getString('theme_mode') ?? 'system');
  late Color _accent = Color(widget.prefs.getInt('accent_color') ?? 0xFF6EE7B7);
  late String _bgType = widget.prefs.getString('bg_type') ?? 'black';
  late Color _bgSolid = Color(widget.prefs.getInt('bg_solid') ?? 0xFF0A0F1A);
  late String _bgImage = widget.prefs.getString('bg_image') ?? '';
  late double _bgBlur = widget.prefs.getDouble('bg_blur') ?? 12.0;
  late double _bgDim = widget.prefs.getDouble('bg_dim') ?? 0.45;

  ThemeMode _parseMode(String v) =>
      v == 'light' ? ThemeMode.light : (v == 'dark' ? ThemeMode.dark : ThemeMode.system);

  Future<void> _updateAppearance({
    ThemeMode? mode,
    Color? accent,
    String? bgType,
    Color? bgSolid,
    String? bgImage,
    double? bgBlur,
    double? bgDim,
  }) async {
    setState(() {
      if (mode != null) _mode = mode;
      if (accent != null) _accent = accent;
      if (bgType != null) _bgType = bgType;
      if (bgSolid != null) _bgSolid = bgSolid;
      if (bgImage != null) _bgImage = bgImage;
      if (bgBlur != null) _bgBlur = bgBlur;
      if (bgDim != null) _bgDim = bgDim;
    });
    if (mode != null) await widget.prefs.setString('theme_mode', mode.name);
    if (accent != null) await widget.prefs.setInt('accent_color', accent.toARGB32());
    if (bgType != null) await widget.prefs.setString('bg_type', bgType);
    if (bgSolid != null) await widget.prefs.setInt('bg_solid', bgSolid.toARGB32());
    if (bgImage != null) await widget.prefs.setString('bg_image', bgImage);
    if (bgBlur != null) await widget.prefs.setDouble('bg_blur', bgBlur);
    if (bgDim != null) await widget.prefs.setDouble('bg_dim', bgDim);
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomBg = _bgType != 'black';
    return MaterialApp(
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: hasCustomBg ? Colors.transparent : const Color(0xFFF2F3F5),
        colorScheme: ColorScheme.light(primary: _accent),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: hasCustomBg ? Colors.transparent : const Color(0xFF000000),
        colorScheme: ColorScheme.dark(primary: _accent),
      ),
      home: HomeScreen(
        themeMode: _mode,
        accent: _accent,
        bgType: _bgType,
        bgSolid: _bgSolid,
        bgImage: _bgImage,
        bgBlur: _bgBlur,
        bgDim: _bgDim,
        onUpdateAppearance: _updateAppearance,
      ),
    );
  }
}
class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final Color accent;
  final String bgType;
  final Color bgSolid;
  final String bgImage;
  final double bgBlur;
  final double bgDim;
  final Future<void> Function({
    ThemeMode? mode,
    Color? accent,
    String? bgType,
    Color? bgSolid,
    String? bgImage,
    double? bgBlur,
    double? bgDim,
  }) onUpdateAppearance;

  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.accent,
    required this.bgType,
    required this.bgSolid,
    required this.bgImage,
    required this.bgBlur,
    required this.bgDim,
    required this.onUpdateAppearance,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final PageController _pageCtrl;
  double _pagePos = 0.0;
  List<Habit> _todayHabits = [];
  int _refreshNonce = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageCtrl = PageController(initialPage: 0)
      ..addListener(() {
        if (_pageCtrl.hasClients && _pageCtrl.page != null) {
          setState(() => _pagePos = _pageCtrl.page!);
        }
      });
    _navChannel.setMethodCallHandler((call) async {
      if (call.method == 'openToday') _goToPage(1);
    });
    _checkLaunchIntent();
    _load();
  }

  Future<void> _checkLaunchIntent() async {
    try {
      final openToday = await _navChannel.invokeMethod<bool>('checkOpenToday') ?? false;
      if (openToday && mounted) _goToPage(1);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (!_pageCtrl.hasClients) return;
    _pageCtrl.animateToPage(idx, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  void _habitSheet({Habit? existing}) {
    final p = ColorOSPalette.of(context);
    final ctrl = TextEditingController(text: existing?.title ?? '');
    String rem = existing?.reminderTime ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final initial = rem.contains(':')
                        ? TimeOfDay(
                            hour: int.parse(rem.split(':').first),
                            minute: int.parse(rem.split(':').elementAt(1)),
                          )
                        : const TimeOfDay(hour: 9, minute: 0);
                    final picked = await showTimePicker(context: ctx, initialTime: initial);
                    if (picked != null) {
                      final formatted =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      setSheetState(() => rem = formatted);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: p.cardRaised, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_outlined, size: 18, color: p.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rem.isEmpty ? 'Add daily reminder (optional)' : 'Reminder at $rem',
                            style: TextStyle(color: p.text, fontSize: 14),
                          ),
                        ),
                        if (rem.isNotEmpty)
                          GestureDetector(
                            onTap: () => setSheetState(() => rem = ''),
                            child: Icon(Icons.close, size: 18, color: p.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent),
                  onPressed: () async {
                    final text = ctrl.text.trim();
                    if (text.isNotEmpty) {
                      int id;
                      if (existing == null) {
                        id = await DatabaseHelper.addHabit(text, reminderTime: rem);
                      } else {
                        id = existing.id!;
                        await DatabaseHelper.updateHabit(id, text, reminderTime: rem);
                      }
                      if (rem.isNotEmpty) {
                        await NotificationHelper.scheduleHabit(id, text, rem);
                      } else {
                        await NotificationHelper.cancelHabit(id);
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
              await NotificationHelper.cancelHabit(h.id!);
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

  Widget _buildBackground(ColorOSPalette p) {
    if (widget.bgType == 'solid') {
      return Container(color: widget.bgSolid);
    }
    if (widget.bgType == 'image' && widget.bgImage.isNotEmpty && File(widget.bgImage).existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(widget.bgImage), fit: BoxFit.cover),
          if (widget.bgBlur > 0.1)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: widget.bgBlur, sigmaY: widget.bgBlur),
              child: Container(color: Colors.transparent),
            ),
          Container(color: Colors.black.withValues(alpha: widget.bgDim)),
        ],
      );
    }
    return Container(color: p.page);
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorOSPalette.of(context);
    final onTodayTab = _pagePos.round() == 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _buildBackground(p)),
          Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
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
            floatingActionButton: onTodayTab
                ? GlassTap(
                    radius: 999,
                    onTap: () => _habitSheet(),
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(color: p.accent.withValues(alpha: 0.32), blurRadius: 16, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: p.onAccent),
                          const SizedBox(width: 6),
                          Text('Habit', style: TextStyle(color: p.onAccent, fontWeight: FontWeight.bold, fontSize: 16)),
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
        ],
      ),
    );
  }

  Widget _settingsView(ColorOSPalette p) {
    const swatches = [Color(0xFF6EE7B7), Color(0xFF5390F5), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFFA78BFA)];
    const bgSwatches = [Color(0xFF0A0F1A), Color(0xFF141118), Color(0xFF0E1713), Color(0xFF1A1410)];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        Text('Settings', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: p.text)),
        const SizedBox(height: 16),
        GlassBox(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Theme & Accent Color', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _segChip('System', widget.themeMode == ThemeMode.system,
                      () => widget.onUpdateAppearance(mode: ThemeMode.system), p),
                  const SizedBox(width: 8),
                  _segChip('Light', widget.themeMode == ThemeMode.light,
                      () => widget.onUpdateAppearance(mode: ThemeMode.light), p),
                  const SizedBox(width: 8),
                  _segChip('Dark', widget.themeMode == ThemeMode.dark,
                      () => widget.onUpdateAppearance(mode: ThemeMode.dark), p),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: HsvColorWheel(
                  selected: widget.accent,
                  onChanged: (c) => widget.onUpdateAppearance(accent: c),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: swatches
                    .map((c) => GestureDetector(
                          onTap: () => widget.onUpdateAppearance(accent: c),
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.accent.toARGB32() == c.toARGB32() ? p.text : Colors.transparent,
                                width: 2.2,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
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
              Text('Background & Wallpaper', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _segChip('Pitch Black', widget.bgType == 'black',
                      () => widget.onUpdateAppearance(bgType: 'black'), p),
                  const SizedBox(width: 8),
                  _segChip('Solid Color', widget.bgType == 'solid',
                      () => widget.onUpdateAppearance(bgType: 'solid'), p),
                  const SizedBox(width: 8),
                  _segChip('Gallery', widget.bgType == 'image', () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (img != null) {
                      final dir = await getApplicationDocumentsDirectory();
                      final dest = p_path.join(dir.path, 'wallpaper${p_path.extension(img.path)}');
                      await File(img.path).copy(dest);
                      await widget.onUpdateAppearance(bgType: 'image', bgImage: dest);
                    }
                  }, p),
                ],
              ),
              if (widget.bgType == 'solid') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: bgSwatches
                      .map((c) => GestureDetector(
                            onTap: () => widget.onUpdateAppearance(bgSolid: c),
                            child: Container(
                              width: 34,
                              height: 34,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: p.accent, width: widget.bgSolid == c ? 2 : 0.5),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
              if (widget.bgType == 'image') ...[
                const SizedBox(height: 12),
                Text('Wallpaper Blur: ${widget.bgBlur.round()}', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                Slider(
                  value: widget.bgBlur,
                  min: 0,
                  max: 30,                  activeColor: p.accent,
                  onChanged: (v) => widget.onUpdateAppearance(bgBlur: v),
                ),
                Text('Wallpaper Dim: ${(widget.bgDim * 100).round()}%',
                    style: TextStyle(fontSize: 13, color: p.textSecondary)),
                Slider(
                  value: widget.bgDim,
                  min: 0.0,
                  max: 0.85,
                  activeColor: p.accent,
                  onChanged: (v) => widget.onUpdateAppearance(bgDim: v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassBox(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Backup & Data', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent),
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
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Imported $count completion records')));
                        }
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Import CSV'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'ColorOS Reminder Tip: For reliable background notifications on OnePlus/OPPO, open App Info > Battery usage and enable "Allow background activity" / "No restrictions" plus Auto-launch.',
                style: TextStyle(fontSize: 12.5, color: p.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _segChip(String label, bool active, VoidCallback onTap, ColorOSPalette p) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? p.accent.withValues(alpha: 0.18) : p.cardRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? p.accent : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? p.accent : p.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

