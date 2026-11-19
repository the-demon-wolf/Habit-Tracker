import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;

  const GlassTap({super.key, required this.child, this.onTap, this.onLongPress, this.radius = 22});

  @override
  State<GlassTap> createState() => _GlassTapState();
}

class _GlassTapState extends State<GlassTap> {
  bool _pressed = false;
  Offset? _touchPos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 200.0;
        final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0 ? constraints.maxHeight : 60.0;
        final align = _touchPos == null
            ? Alignment.center
            : Alignment((_touchPos!.dx / w) * 2 - 1, (_touchPos!.dy / h) * 2 - 1);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => setState(() {
            _pressed = true;
            _touchPos = d.localPosition;
          }),
          onPanUpdate: (d) => setState(() => _touchPos = d.localPosition),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onPanEnd: (_) => setState(() => _pressed = false),
          onTap: () {
            if (widget.onTap != null) {
              HapticFeedback.lightImpact();
              widget.onTap!();
            }
          },
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: Duration(milliseconds: _pressed ? 110 : 260),
            curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
            child: Stack(
              children: [
                widget.child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _pressed ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 140),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(widget.radius),
                          gradient: RadialGradient(
                            center: align,
                            radius: 1.15,
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.02),
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
    this.radius = 22,
    this.padding,
    this.margin,
    this.glow = false,
    this.blurBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: glow
              ? [const Color(0xFF6EE7B7).withValues(alpha: 0.14), const Color(0xFF141820).withValues(alpha: 0.92)]
              : [const Color(0xFF1A1E28).withValues(alpha: 0.88), const Color(0xFF12151C).withValues(alpha: 0.92)],
        ),
        border: Border.all(
          width: 1.0,
          color: glow ? const Color(0xFF6EE7B7).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: child,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow
            ? [BoxShadow(color: const Color(0xFF6EE7B7).withValues(alpha: 0.12), blurRadius: 16)]
            : null,
      ),
      child: blurBackground
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: content),
            )
          : content,
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
    final raw = ((localX - segW / 2) / segW).clamp(-0.08, 2.08);
    final nearest = raw.round().clamp(0, 2);
    if (nearest != _lastHapticIdx) {
      _lastHapticIdx = nearest;
      HapticFeedback.selectionClick();
    }
    setState(() => _dragPos = raw);
  }

  @override
  Widget build(BuildContext context) {
    final pos = (_dragPos ?? widget.pagePosition).clamp(-0.08, 2.08);
    final dragging = _dragPos != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: 60,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF16181F).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
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
                        scale: dragging ? 1.05 : 1.0,
                        duration: Duration(milliseconds: dragging ? 100 : 280),
                        curve: dragging ? Curves.easeOutCubic : Curves.easeOutBack,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(34),
                            color: Colors.white.withValues(alpha: dragging ? 0.15 : 0.10),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(3, (i) {
                        final t = (1.0 - (pos - i).abs()).clamp(0.0, 1.0);
                        final iconColor = Color.lerp(Colors.white54, const Color(0xFF6EE7B7), t)!;
                        final textColor = Color.lerp(Colors.white54, Colors.white, t)!;
                        return SizedBox(
                          width: tabW,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_items[i].$1, size: 20, color: iconColor),
                              const SizedBox(height: 2),
                              Text(
                                _items[i].$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w400,
                                  color: textColor,
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
