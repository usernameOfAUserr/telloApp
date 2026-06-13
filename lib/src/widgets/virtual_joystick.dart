import 'dart:math' as math;

import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    required this.label,
    required this.horizontalLabels,
    required this.verticalLabels,
    required this.onChanged,
    required this.onReleased,
    super.key,
  });

  final String label;
  final (String, String) horizontalLabels;
  final (String, String) verticalLabels;
  final void Function(double x, double y) onChanged;
  final VoidCallback onReleased;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _position = Offset.zero;

  void _update(Offset localPosition, double size) {
    final center = Offset(size / 2, size / 2);
    var delta = localPosition - center;
    final radius = size / 2;
    if (delta.distance > radius) {
      delta = Offset.fromDirection(delta.direction, radius);
    }
    setState(() => _position = delta);
    widget.onChanged(delta.dx / radius, delta.dy / radius);
  }

  void _release() {
    setState(() => _position = Offset.zero);
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(constraints.maxWidth, 180.0);
            return GestureDetector(
              onPanStart: (details) => _update(details.localPosition, size),
              onPanUpdate: (details) => _update(details.localPosition, size),
              onPanEnd: (_) => _release(),
              onPanCancel: _release,
              child: SizedBox.square(
                dimension: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                    ),
                    _AxisLabels(
                      horizontal: widget.horizontalLabels,
                      vertical: widget.verticalLabels,
                    ),
                    Transform.translate(
                      offset: _position,
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.horizontal, required this.vertical});

  final (String, String) horizontal;
  final (String, String) vertical;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white54, fontSize: 11);
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(left: 8, top: 82, child: Text(horizontal.$1, style: style)),
          Positioned(right: 8, top: 82, child: Text(horizontal.$2, style: style)),
          Positioned(top: 8, left: 0, right: 0, child: Center(child: Text(vertical.$1, style: style))),
          Positioned(bottom: 8, left: 0, right: 0, child: Center(child: Text(vertical.$2, style: style))),
        ],
      ),
    );
  }
}
