import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'habits_tab.dart';
import 'settings_pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HabitAppShell());
}

class HabitAppShell extends StatefulWidget {
  const HabitAppShell({super.key});

  @override
  State<HabitAppShell> createState() => _HabitAppShellState();
}

class _HabitAppShellState extends State<HabitAppShell> {
  final PageController _pageController = PageController();
  int _tabIndex = 0;
  int _externalTick = 0;

  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = const Color(0xFF4F7CFF);
  String _wallpaperMode = 'pitch_black';
  String? _wallpaperPath;
  double _wallpaperBlur = 6.0;
  double _wallpaperDim = 0.25;

  String _userName = '';
  String? _avatarPath;
  bool _showWelcomeSplash = true;
  double _splashOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPrefsAndStartSplash();
  }

  Future<void> _loadPrefsAndStartSplash() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('profile_name') ?? '';
      _avatarPath = prefs.getString('profile_avatar_path');
      final accentInt = prefs.getInt('accent_color');
      if (accentInt != null) _accentColor = Color(accentInt);
      _wallpaperMode = prefs.getString('wallpaper_mode') ?? 'pitch_black';
      _wallpaperPath = prefs.getString('wallpaper_path');
      _wallpaperBlur = prefs.getDouble('wallpaper_blur') ?? 6.0;
      _wallpaperDim = prefs.getDouble('wallpaper_dim') ?? 0.25;
    });

    Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() => _splashOpacity = 0.0);
      Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _showWelcomeSplash = false);
      });
    });
  }

  void _bumpExternalTick() {
    setState(() => _externalTick++);
  }

  @override
  Widget build(BuildContext context) {
    final welcomeLabel = _userName.trim().isEmpty
        ? 'Welcome back'
        : 'Welcome back, ${_userName.trim()}';

    return MaterialApp(
      themeMode: _themeMode,
      theme: ThemeData(colorSchemeSeed: _accentColor, useMaterial3: true),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: _accentColor,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _tabIndex = idx),
              children: [
                HabitsTab(
                  externalTick: _externalTick,
                  userName: _userName,
                  avatarPath: _avatarPath,
                  onDataMutated: _bumpExternalTick,
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Offline Profile'),
                      subtitle: Text(_userName.isEmpty ? 'Set name & avatar' : _userName),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileSettingsPage(
                            initialName: _userName,
                            initialAvatarPath: _avatarPath,
                            onSaved: (name, path) {
                              setState(() {
                                _userName = name;
                                _avatarPath = path;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('Theme & Appearance'),
                      subtitle: const Text('Mode, HSV color wheel & wallpaper'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppearanceSettingsPage(
                            themeMode: _themeMode,
                            accentColor: _accentColor,
                            wallpaperMode: _wallpaperMode,
                            wallpaperPath: _wallpaperPath,
                            wallpaperBlur: _wallpaperBlur,
                            wallpaperDim: _wallpaperDim,
                            onThemeModeChanged: (m) => setState(() => _themeMode = m),
                            onAccentColorChanged: (c) => setState(() => _accentColor = c),
                            onWallpaperChanged: ({mode, path, blur, dim}) {
                              setState(() {
                                if (mode != null) _wallpaperMode = mode;
                                if (path != null) _wallpaperPath = path;
                                if (blur != null) _wallpaperBlur = blur;
                                if (dim != null) _wallpaperDim = dim;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('Backup & Data'),
                      subtitle: const Text('Export/Import CSV, ColorOS tip & reset'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DataManagementPage(onDataChanged: _bumpExternalTick),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_showWelcomeSplash)
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _splashOpacity,
                  duration: const Duration(milliseconds: 350),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_avatarPath != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CircleAvatar(
                                radius: 36,
                                backgroundImage: FileImage(File(_avatarPath!)),
                              ),
                            ),
                          Text(
                            welcomeLabel,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (idx) {
            setState(() => _tabIndex = idx);
            _pageController.animateToPage(
              idx,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Habits'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
