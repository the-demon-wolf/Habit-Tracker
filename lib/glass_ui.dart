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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        if (widget.onTap != null) {
          HapticFeedback.lightImpact();
          widget.onTap!();
        }
      },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            color: _pressed ? Colors.white.withValues(alpha: 0.07) : Colors.transparent,
          ),
          child: widget.child,
        ),
      ),
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
    final raw = ((localX - segW / 2) / segW).clamp(0.0, 2.0);
    final nearest = raw.round();
    if (nearest != _lastHapticIdx) {
      _lastHapticIdx = nearest;
      HapticFeedback.selectionClick();
    }
    setState(() => _dragPos = raw);
  }

  @override
  Widget build(BuildContext context) {
    final pos = (_dragPos ?? widget.pagePosition).clamp(0.0, 2.0);
    final dragging = _dragPos != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 62,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF181B22).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.0),
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
                      left: pos * tabW,
                      top: 0,
                      bottom: 0,
                      width: tabW,
                      child: AnimatedScale(
                        scale: dragging ? 1.06 : 1.0,
                        duration: const Duration(milliseconds: 140),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(34),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: dragging ? 0.24 : 0.16),
                                Colors.white.withValues(alpha: dragging ? 0.12 : 0.08),
                              ],
                            ),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8),
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
                              Icon(
                                _items[i].$1,
                                size: 20,
                                color: active ? const Color(0xFF6EE7B7) : Colors.white60,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _items[i].$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                  color: active ? Colors.white : Colors.white60,
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
