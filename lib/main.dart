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
