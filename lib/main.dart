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
