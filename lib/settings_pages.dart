import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db.dart';

class AppearanceSettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final Color accentColor;
  final String wallpaperMode;
  final String? wallpaperPath;
  final double wallpaperBlur;
  final double wallpaperDim;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Color> onAccentColorChanged;
  final void Function({
    String? mode,
    String? path,
    double? blur,
    double? dim,
  }) onWallpaperChanged;

  const AppearanceSettingsPage({
    super.key,
    required this.themeMode,
    required this.accentColor,
    required this.wallpaperMode,
    required this.wallpaperPath,
    required this.wallpaperBlur,
    required this.wallpaperDim,
    required this.onThemeModeChanged,
    required this.onAccentColorChanged,
    required this.onWallpaperChanged,
  });

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.accentColor);
  }

  Future<void> _pickWallpaperImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final appDir = await getApplicationDocumentsDirectory();
    final savedFile = await File(picked.path).copy(
      p.join(appDir.path, 'custom_wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg'),
    );
    widget.onWallpaperChanged(mode: 'gallery', path: savedFile.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme & Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {widget.themeMode},
            onSelectionChanged: (s) => widget.onThemeModeChanged(s.first),
          ),
          const SizedBox(height: 20),
          const Text('Accent Hue (Drag freely — PageView locked here)'),
          Slider(
            min: 0,
            max: 360,
            value: _hsv.hue,
            onChanged: (h) {
              setState(() => _hsv = _hsv.withHue(h));
              widget.onAccentColorChanged(_hsv.toColor());
            },
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pitch_black', label: Text('Pitch Black')),
              ButtonSegment(value: 'solid', label: Text('Solid')),
              ButtonSegment(value: 'gallery', label: Text('Gallery')),
            ],
            selected: {widget.wallpaperMode},
            onSelectionChanged: (s) {
              if (s.first == 'gallery') {
                _pickWallpaperImage();
              } else {
                widget.onWallpaperChanged(mode: s.first);
              }
            },
          ),
          const SizedBox(height: 12),
          Text('Wallpaper Blur: ${widget.wallpaperBlur.toStringAsFixed(1)}'),
          Slider(
            min: 0,
            max: 24,
            value: widget.wallpaperBlur,
            onChanged: (v) => widget.onWallpaperChanged(blur: v),
          ),
          Text('Wallpaper Dim: ${(widget.wallpaperDim * 100).round()}%'),
          Slider(
            min: 0,
            max: 0.85,
            value: widget.wallpaperDim,
            onChanged: (v) => widget.onWallpaperChanged(dim: v),
          ),
        ],
      ),
    );
  }
}
class DataManagementPage extends StatelessWidget {
  final VoidCallback onDataChanged;

  const DataManagementPage({super.key, required this.onDataChanged});

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This permanently deletes all habits and completion history on this device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete All')),
        ],
      ),
    );
    if (confirmed == true) {
      await HabitDatabase.instance.clearAllData();
      onDataChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All habit data cleared.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Export CSV Backup'),
            subtitle: const Text('Shares habit_tracker_backup.csv as text/csv'),
            onTap: () => HabitDatabase.instance.exportCsv(),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Import CSV Backup'),
            subtitle: const Text('Imports habits and logs from a CSV file'),
            onTap: () async {
              final count = await HabitDatabase.instance.importCsv();
              onDataChanged();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Imported $count habit entries.')),
                );
              }
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.battery_saver_outlined),
            title: Text('ColorOS Battery & Autostart Tip'),
            subtitle: Text(
              'Allow exact alarms and disable aggressive background sleep if reminders delay.',
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('Danger Zone: Clear All Data', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmClearAll(context),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsPage extends StatefulWidget {
  final String initialName;
  final String? initialAvatarPath;
  final void Function(String name, String? avatarPath) onSaved;

  const ProfileSettingsPage({
    super.key,
    required this.initialName,
    required this.initialAvatarPath,
    required this.onSaved,
  });

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  late final TextEditingController _nameController;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _avatarPath = widget.initialAvatarPath;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final saved = await File(picked.path).copy(
      p.join(dir.path, 'profile_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg'),
    );
    setState(() => _avatarPath = saved.path);
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = _nameController.text.trim();
    await prefs.setString('profile_name', name);
    if (_avatarPath != null) {
      await prefs.setString('profile_avatar_path', _avatarPath!);
    } else {
      await prefs.remove('profile_avatar_path');
    }
    widget.onSaved(name, _avatarPath);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 44,
                backgroundImage: _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
                child: _avatarPath == null ? const Icon(Icons.person_add, size: 32) : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Display Name (Optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saveProfile, child: const Text('Save Profile')),
        ],
      ),
    );
  }
}
