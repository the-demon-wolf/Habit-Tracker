import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';
import 'glass_ui.dart';
import 'summary_tab.dart';
import 'habits_tab.dart';
import 'notifications.dart';
import 'settings_pages.dart';

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
  late String _userName = widget.prefs.getString('user_name') ?? '';
  late String _userAvatar = widget.prefs.getString('user_avatar') ?? '';

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

  Future<void> _updateProfile(String name, String avatar) async {
    setState(() {
      _userName = name;
      _userAvatar = avatar;
    });
    await widget.prefs.setString('user_name', name);
    await widget.prefs.setString('user_avatar', avatar);
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
        userName: _userName,
        userAvatar: _userAvatar,
        onUpdateAppearance: _updateAppearance,
        onUpdateProfile: _updateProfile,
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
  final String userName;
  final String userAvatar;
  final Future<void> Function({
    ThemeMode? mode,
    Color? accent,
    String? bgType,
    Color? bgSolid,
    String? bgImage,
    double? bgBlur,
    double? bgDim,
  }) onUpdateAppearance;
  final Future<void> Function(String name, String avatar) onUpdateProfile;

  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.accent,
    required this.bgType,
    required this.bgSolid,
    required this.bgImage,
    required this.bgBlur,
    required this.bgDim,
    required this.userName,
    required this.userAvatar,
    required this.onUpdateAppearance,
    required this.onUpdateProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final PageController _pageCtrl;
  double _pagePos = 0.0;
  List<Habit> _todayHabits = [];
  int _refreshTick = 0;
  bool _showWelcome = true;

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
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showWelcome = false);
    });
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
        _refreshTick++;
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
    if (widget.bgType == 'solid') return Container(color: widget.bgSolid);
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
                    userName: widget.userName,
                    externalTick: _refreshTick,
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
          IgnorePointer(
            ignoring: !_showWelcome,
            child: AnimatedOpacity(
              opacity: _showWelcome ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 420),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  color: p.page.withValues(alpha: 0.72),
                  alignment: Alignment.center,
                  child: GlassBox(
                    radius: 30,
                    blurBackground: true,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.userAvatar.isNotEmpty && File(widget.userAvatar).existsSync())
                          CircleAvatar(radius: 34, backgroundImage: FileImage(File(widget.userAvatar)))
                        else
                          Icon(Icons.check_circle_rounded, size: 48, color: p.accent),
                        const SizedBox(height: 14),
                        Text(
                          widget.userName.isEmpty ? 'Welcome back' : 'Welcome back, ${widget.userName}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsView(ColorOSPalette p) {
    final hasAvatar = widget.userAvatar.isNotEmpty && File(widget.userAvatar).existsSync();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        Text('Settings', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: p.text)),
        const SizedBox(height: 18),
        GlassTap(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => ProfileSettingsPage(
              initialName: widget.userName,
              initialAvatar: widget.userAvatar,
              onSave: widget.onUpdateProfile,
            ),
          )),
          child: GlassBox(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: p.cardRaised,
                  backgroundImage: hasAvatar ? FileImage(File(widget.userAvatar)) : null,
                  child: !hasAvatar ? Icon(Icons.person_outline, color: p.accent) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.userName.isEmpty ? 'Offline Profile' : widget.userName,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
                      Text('Tap to set name & profile photo', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: p.textTertiary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassTap(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => AppearanceSettingsPage(
              themeMode: widget.themeMode,
              accent: widget.accent,
              bgType: widget.bgType,
              bgSolid: widget.bgSolid,
              bgBlur: widget.bgBlur,
              bgDim: widget.bgDim,
              onUpdate: widget.onUpdateAppearance,
            ),
          )),
          child: GlassBox(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.palette_outlined, color: p.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme & Appearance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: p.text)),
                      Text('Dark/Light mode, accent wheel & wallpaper', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: p.textTertiary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassTap(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => DataManagementPage(onChanged: _load),
          )),
          child: GlassBox(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.storage_rounded, color: p.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Backup & Data', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: p.text)),
                      Text('CSV export/import & reset local data', style: TextStyle(fontSize: 13, color: p.textSecondary)),
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
}
}
