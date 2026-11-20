import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p_path;
import 'db.dart';
import 'glass_ui.dart';

class AppearanceSettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final Color accent;
  final String bgType;
  final Color bgSolid;
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
  }) onUpdate;

  const AppearanceSettingsPage({
    super.key,
    required this.themeMode,
    required this.accent,
    required this.bgType,
    required this.bgSolid,
    required this.bgBlur,
    required this.bgDim,
    required this.onUpdate,
  });

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late ThemeMode _mode = widget.themeMode;
  late Color _accent = widget.accent;
  late String _bgType = widget.bgType;
  late Color _bgSolid = widget.bgSolid;
  late double _bgBlur = widget.bgBlur;
  late double _bgDim = widget.bgDim;

  @override
  Widget build(BuildContext context) {
    final p = ColorOSPalette.of(context);
    const swatches = [Color(0xFF6EE7B7), Color(0xFF5390F5), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFFA78BFA)];
    const bgSwatches = [Color(0xFF0A0F1A), Color(0xFF141118), Color(0xFF0E1713), Color(0xFF1A1410)];

    return Scaffold(
      backgroundColor: p.page,
      appBar: AppBar(
        backgroundColor: p.page,
        elevation: 0,
        iconTheme: IconThemeData(color: p.text),
        title: Text('Theme & Appearance', style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          GlassBox(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme Mode', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _chip('System', _mode == ThemeMode.system, () {
                      setState(() => _mode = ThemeMode.system);
                      widget.onUpdate(mode: ThemeMode.system);
                    }, p),
                    const SizedBox(width: 8),
                    _chip('Light', _mode == ThemeMode.light, () {
                      setState(() => _mode = ThemeMode.light);
                      widget.onUpdate(mode: ThemeMode.light);
                    }, p),
                    const SizedBox(width: 8),
                    _chip('Dark', _mode == ThemeMode.dark, () {
                      setState(() => _mode = ThemeMode.dark);
                      widget.onUpdate(mode: ThemeMode.dark);
                    }, p),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Accent Color (Drag or Tap)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 12),
                Center(
                  child: HsvColorWheel(
                    selected: _accent,
                    onChanged: (c) {
                      setState(() => _accent = c);
                      widget.onUpdate(accent: c);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: swatches
                      .map((c) => GestureDetector(
                            onTap: () {
                              setState(() => _accent = c);
                              widget.onUpdate(accent: c);
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _accent.toARGB32() == c.toARGB32() ? p.text : Colors.transparent,
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
                    _chip('Pitch Black', _bgType == 'black', () {
                      setState(() => _bgType = 'black');
                      widget.onUpdate(bgType: 'black');
                    }, p),
                    const SizedBox(width: 8),
                    _chip('Solid Color', _bgType == 'solid', () {
                      setState(() => _bgType = 'solid');
                      widget.onUpdate(bgType: 'solid');
                    }, p),
                    const SizedBox(width: 8),
                    _chip('Gallery', _bgType == 'image', () async {
                      final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (img != null) {
                        final dir = await getApplicationDocumentsDirectory();
                        final dest = p_path.join(dir.path, 'wallpaper${p_path.extension(img.path)}');
                        await File(img.path).copy(dest);
                        setState(() => _bgType = 'image');
                        await widget.onUpdate(bgType: 'image', bgImage: dest);
                      }
                    }, p),
                  ],
                ),
                if (_bgType == 'solid') ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: bgSwatches
                        .map((c) => GestureDetector(
                              onTap: () {
                                setState(() => _bgSolid = c);
                                widget.onUpdate(bgSolid: c);
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _accent, width: _bgSolid == c ? 2 : 0.5),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
                if (_bgType == 'image') ...[
                  const SizedBox(height: 12),
                  Text('Wallpaper Blur: ${_bgBlur.round()}', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                  Slider(
                    value: _bgBlur,
                    min: 0,
                    max: 30,
                    activeColor: _accent,
                    onChanged: (v) {
                      setState(() => _bgBlur = v);
                      widget.onUpdate(bgBlur: v);
                    },
                  ),
                  Text('Wallpaper Dim: ${(_bgDim * 100).round()}%',
                      style: TextStyle(fontSize: 13, color: p.textSecondary)),
                  Slider(
                    value: _bgDim,
                    min: 0.0,
                    max: 0.85,
                    activeColor: _accent,
                    onChanged: (v) {
                      setState(() => _bgDim = v);
                      widget.onUpdate(bgDim: v);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap, ColorOSPalette p) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _accent.withValues(alpha: 0.18) : p.cardRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? _accent : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? _accent : p.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class ProfileSettingsPage extends StatefulWidget {
  final String initialName;
  final String initialAvatar;
  final Future<void> Function(String name, String avatar) onSave;

  const ProfileSettingsPage({
    super.key,
    required this.initialName,
    required this.initialAvatar,
    required this.onSave,
  });

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialName);
  late String _avatar = widget.initialAvatar;

  @override
  Widget build(BuildContext context) {
    final p = ColorOSPalette.of(context);
    return Scaffold(
      backgroundColor: p.page,
      appBar: AppBar(
        backgroundColor: p.page,
        elevation: 0,
        iconTheme: IconThemeData(color: p.text),
        title: Text('Offline Profile', style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassBox(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (img != null) {
                      final dir = await getApplicationDocumentsDirectory();
                      final dest = p_path.join(dir.path, 'avatar${p_path.extension(img.path)}');
                      await File(img.path).copy(dest);
                      setState(() => _avatar = dest);
                    }
                  },
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: p.cardRaised,
                    backgroundImage: (_avatar.isNotEmpty && File(_avatar).existsSync()) ? FileImage(File(_avatar)) : null,
                    child: (_avatar.isEmpty || !File(_avatar).existsSync())
                        ? Icon(Icons.person_add_alt_1, size: 32, color: p.accent)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tap photo to change', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
                  style: TextStyle(color: p.text),
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    labelStyle: TextStyle(color: p.textSecondary),
                    filled: true,
                    fillColor: p.cardRaised,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent),
                    onPressed: () async {
                      await widget.onSave(_ctrl.text.trim(), _avatar);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                Text('Export your habits and history as a .csv file or restore from another device.',
                    style: TextStyle(fontSize: 13.5, color: p.textSecondary)),
                const SizedBox(height: 14),
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
                          if (count >= 0 && context.mounted) {
                            onChanged();
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
                  'ColorOS Reminder Tip: For reliable background reminders on OnePlus/OPPO, open App Info > Battery usage and allow background activity ("No restrictions") plus Auto-launch.',
                  style: TextStyle(fontSize: 12.5, color: p.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
