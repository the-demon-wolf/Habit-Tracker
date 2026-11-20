class GlassTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;

  const GlassTap({super.key, required this.child, this.onTap, this.onLongPress, this.radius = 24});

  @override
  State<GlassTap> createState() => _GlassTapState();
}

class _GlassTapState extends State<GlassTap> {
  bool _pressed = false;
  Offset? _touchPos;

  @override
  Widget build(BuildContext context) {
    final p = ColorOSPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 200.0;
        final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0 ? constraints.maxHeight : 60.0;
        final align = _touchPos == null
            ? Alignment.center
            : Alignment(((_touchPos!.dx / w) * 2 - 1).clamp(-1.0, 1.0), ((_touchPos!.dy / h) * 2 - 1).clamp(-1.0, 1.0));

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => setState(() {
            _pressed = true;
            _touchPos = e.localPosition;
          }),
          onPointerMove: (e) {
            if (_pressed) setState(() => _touchPos = e.localPosition);
          },
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.onTap != null) {
                HapticFeedback.lightImpact();
                widget.onTap!();
              }
            },
            onLongPress: widget.onLongPress,
            child: AnimatedScale(
              scale: _pressed ? 0.945 : 1.0,
              duration: Duration(milliseconds: _pressed ? 95 : 320),
              curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
              child: Stack(
                children: [
                  widget.child,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _pressed ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 110),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(widget.radius),
                            border: Border.all(
                              color: p.accent.withValues(alpha: 0.45),
                              width: 1.1,
                            ),
                            gradient: RadialGradient(
                              center: align,
                              radius: 0.95,
                              colors: [
                                p.accent.withValues(alpha: p.isDark ? 0.24 : 0.16),
                                Colors.white.withValues(alpha: p.isDark ? 0.08 : 0.04),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
class GlassBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool glow;
  final bool blurBackground;

  const GlassBox({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
    this.margin,
    this.glow = false,
    this.blurBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorOSPalette.of(context);
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: glow ? p.accent.withValues(alpha: 0.45) : p.hairline,
        width: glow ? 1.1 : 0.8,
      ),
    );

    final fill = blurBackground
        ? p.floatingGlass
        : (glow ? Color.alphaBlend(p.accent.withValues(alpha: p.isDark ? 0.12 : 0.09), p.card) : p.card);

    final body = Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: fill,
        shape: shape,
        shadows: p.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: child,
    );

    return Container(
      margin: margin,
      child: blurBackground
          ? ClipRSuperellipse(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: body),
            )
          : body,
    );
  }
}

class ColorOSPillNav extends StatefulWidget {
  final double pagePosition;
  final ValueChanged<int> onSelect;

  const ColorOSPillNav({super.key, required this.pagePosition, required this.onSelect});

  @override
  State<ColorOSPillNav> createState() => _ColorOSPillNavState();
}

class _ColorOSPillNavState extends State<ColorOSPillNav> {
  double? _dragPos;
  int _lastHapticIdx = 0;

  static const _items = [
    (Icons.insights, 'Summary'),
    (Icons.check_circle_outline, 'Today'),
    (Icons.tune, 'Settings'),
  ];

  void _handleDrag(double localX, double maxW) {
    final segW = maxW / 3;
    final raw = ((localX - segW / 2) / segW).clamp(-0.12, 2.12);
    final nearest = raw.round().clamp(0, 2);
    if (nearest != _lastHapticIdx) {
      _lastHapticIdx = nearest;
      HapticFeedback.selectionClick();
    }
    setState(() => _dragPos = raw);
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorOSPalette.of(context);
    final pos = (_dragPos ?? widget.pagePosition).clamp(-0.12, 2.12);
    final dragging = _dragPos != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 58,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: p.floatingGlass,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.hairline, width: 0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final tabW = w / 3;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => _handleDrag(d.localPosition.dx, w),
                onHorizontalDragUpdate: (d) => _handleDrag(d.localPosition.dx, w),
                onHorizontalDragEnd: (_) {
                  final target = (_dragPos ?? widget.pagePosition).round().clamp(0, 2);
                  setState(() => _dragPos = null);
                  widget.onSelect(target);
                },
                onTapUp: (d) {
                  final target = (d.localPosition.dx / tabW).floor().clamp(0, 2);
                  HapticFeedback.selectionClick();
                  widget.onSelect(target);
                },
                child: Stack(
                  children: [
                    Positioned(
                      left: (pos * tabW).clamp(0.0, w - tabW),
                      top: 0,
                      bottom: 0,
                      width: tabW,
                      child: AnimatedScale(
                        scale: dragging ? 1.07 : 1.0,
                        duration: Duration(milliseconds: dragging ? 105 : 260),
                        curve: dragging ? Curves.easeOutCubic : Curves.easeOutBack,
                        child: Container(
                          decoration: BoxDecoration(
                            color: p.pillActive,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: p.hairline, width: 0.8),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(3, (i) {
                        final active = (pos - i).abs() < 0.5;
                        return SizedBox(
                          width: tabW,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_items[i].$1, size: 20, color: active ? p.accent : p.textSecondary),
                              const SizedBox(height: 2),
                              Text(
                                _items[i].$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                  color: active ? p.text : p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class HsvColorWheel extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;

  const HsvColorWheel({super.key, required this.selected, required this.onChanged});

  void _pick(Offset local, double size) {
    final c = Offset(size / 2, size / 2);
    final dx = local.dx - c.dx;
    final dy = local.dy - c.dy;
    final r = size / 2;
    final dist = math.sqrt(dx * dx + dy * dy).clamp(0.0, r);
    final angle = (math.atan2(dy, dx) * 180 / math.pi + 360) % 360;
    final sat = (dist / r).clamp(0.15, 1.0);
    onChanged(HSVColor.fromAHSV(1.0, angle, sat, 1.0).toColor());
  }

  @override
  Widget build(BuildContext context) {
    const size = 180.0;
    final hsv = HSVColor.fromColor(selected);
    final rad = hsv.hue * math.pi / 180;
    final r = (size / 2) * hsv.saturation;
    final thumb = Offset(size / 2 + math.cos(rad) * r, size / 2 + math.sin(rad) * r);

    return GestureDetector(
      onPanDown: (d) => _pick(d.localPosition, size),
      onPanUpdate: (d) => _pick(d.localPosition, size),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _WheelPainter(thumb, selected),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final Offset thumb;
  final Color selected;
  _WheelPainter(this.thumb, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const sweep = SweepGradient(colors: [
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ]);
    const radial = RadialGradient(colors: [Colors.white, Color(0x00FFFFFF)]);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()..shader = sweep.createShader(rect));
    canvas.drawCircle(center, radius, Paint()..shader = radial.createShader(rect));
    canvas.drawCircle(thumb, 11, Paint()..color = selected);
    canvas.drawCircle(
      thumb,
      11,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.thumb != thumb || old.selected != selected;
}
