import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/tello_controller.dart';
import '../models/connection_status.dart';
import '../models/tello_trick.dart';
import '../providers/tello_provider.dart';
import '../widgets/telemetry_grid.dart';
import '../widgets/tello_video_view.dart';
import '../widgets/virtual_joystick.dart';

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  int _section = 0;

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _toggleVideo() async {
    final controller = ref.read(telloControllerProvider);
    if (controller.isVideoActive) {
      await controller.stopVideo();
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      await controller.startVideo();
      if (controller.isVideoActive) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(telloControllerProvider);
    if (controller.isVideoActive) {
      return _VideoHud(controller: controller, onClose: _toggleVideo);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const _GlitchTitle(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _ConnectionBadge(status: controller.status),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: (value) => setState(() => _section = value),
        backgroundColor: const Color(0xff041009),
        indicatorColor: const Color(0x4439ff88),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.gamepad_outlined),
            selectedIcon: Icon(Icons.gamepad),
            label: 'CONTROL',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'TRICKS',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'DATA',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _GridBackground()),
            IndexedStack(
              index: _section,
              children: [
                _ControlPanel(controller: controller, onVideo: _toggleVideo),
                _TricksPanel(controller: controller),
                _DataPanel(controller: controller),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.controller, required this.onVideo});

  final TelloController controller;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    final connected = controller.isConnected;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HudPanel(
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar, color: Color(0xff39ff88)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        connected
                            ? 'TELLO LINK // ONLINE'
                            : 'TELLO LINK // STANDBY',
                        style: const TextStyle(
                          color: Color(0xff8affb0),
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    Switch(
                      value: connected,
                      onChanged: controller.status ==
                              TelloConnectionStatus.connecting
                          ? null
                          : (_) => connected
                              ? controller.disconnect()
                              : controller.connect(),
                    ),
                  ],
                ),
                if (controller.errorMessage case final String message?) ...[
                  const Divider(),
                  Text(message, style: const TextStyle(color: Colors.orange)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: connected && !controller.isVideoBusy ? onVideo : null,
            icon: controller.isVideoBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.videocam_outlined),
            label: const Text('LIVE FEED INITIALISIEREN'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _HudButton(
                label: 'TAKE OFF',
                icon: Icons.flight_takeoff,
                onPressed: connected ? controller.takeOff : null,
              ),
              _HudButton(
                label: 'LAND',
                icon: Icons.flight_land,
                onPressed: connected ? controller.land : null,
              ),
              _HudButton(
                label: 'HOVER',
                icon: Icons.pause,
                onPressed: connected ? controller.stop : null,
              ),
              _HudButton(
                label: 'EMERGENCY',
                icon: Icons.warning_amber,
                danger: true,
                onPressed: connected ? controller.emergency : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          IgnorePointer(
            ignoring: !connected,
            child: Opacity(
              opacity: connected ? 1 : 0.3,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: VirtualJoystick(
                      label: 'ALT // YAW',
                      horizontalLabels: const ('YAW−', 'YAW+'),
                      verticalLabels: const ('UP', 'DOWN'),
                      onChanged: controller.setLeftJoystick,
                      onReleased: controller.releaseLeftJoystick,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: VirtualJoystick(
                      label: 'VECTOR',
                      horizontalLabels: const ('LEFT', 'RIGHT'),
                      verticalLabels: const ('FWD', 'BACK'),
                      onChanged: controller.setRightJoystick,
                      onReleased: controller.releaseRightJoystick,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '> ${controller.rcCommand.wireValue}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xff39ff88)),
          ),
        ],
      ),
    );
  }
}

class _TricksPanel extends StatelessWidget {
  const _TricksPanel({required this.controller});

  final TelloController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'FLIGHT ROUTINES',
          style: TextStyle(
            color: Color(0xff39ff88),
            fontSize: 20,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 18),
        for (final trick in TelloTrick.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HudPanel(
              child: ListTile(
                leading: const Icon(Icons.blur_circular),
                title: Text(trick.label.toUpperCase()),
                subtitle: Text('CMD > ${trick.command}'),
                trailing: const Icon(Icons.play_arrow),
                onTap: controller.isConnected
                    ? () => controller.performTrick(trick)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({required this.controller});

  final TelloController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SENSOR MATRIX',
            style: TextStyle(
              color: Color(0xff39ff88),
              fontSize: 20,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 14),
          TelemetryGrid(telemetry: controller.telemetry),
        ],
      ),
    );
  }
}

class _VideoHud extends StatelessWidget {
  const _VideoHud({required this.controller, required this.onClose});

  final TelloController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final telemetry = controller.telemetry;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const TelloVideoView(),
          IgnorePointer(
            child: CustomPaint(painter: _CrosshairPainter()),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: _VideoMetric(
              label: 'BAT',
              value: '${telemetry.battery ?? '--'}%',
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: _VideoMetric(
              label: 'ALT',
              value: '${telemetry.height ?? '--'} CM',
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: _VideoMetric(
              label: 'YAW',
              value: '${telemetry.yaw ?? '--'}°',
            ),
          ),
          Positioned(
            right: 16,
            top: 16,
            child: Row(
              children: [
                const Text(
                  '● LIVE',
                  style: TextStyle(color: Color(0xff39ff88)),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_fullscreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xe607150d),
        border: Border.all(color: const Color(0x8839ff88)),
        boxShadow: const [
          BoxShadow(color: Color(0x2239ff88), blurRadius: 14),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? Colors.redAccent : const Color(0xff8affb0),
        side: BorderSide(
          color: danger ? Colors.redAccent : const Color(0x8839ff88),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.status});

  final TelloConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      TelloConnectionStatus.disconnected => (Colors.grey, 'OFFLINE'),
      TelloConnectionStatus.connecting => (Colors.orange, 'LINKING'),
      TelloConnectionStatus.connected => (const Color(0xff39ff88), 'ONLINE'),
      TelloConnectionStatus.error => (Colors.redAccent, 'ERROR'),
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}

class _GlitchTitle extends StatelessWidget {
  const _GlitchTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TELLO//OS',
          style: TextStyle(
            color: Color(0xff39ff88),
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        Text(
          'EDU FLIGHT TERMINAL',
          style: TextStyle(color: Color(0xff68a77c), fontSize: 8),
        ),
      ],
    );
  }
}

class _GridBackground extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1539ff88)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xaa39ff88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 34, paint);
    canvas.drawLine(center - const Offset(60, 0), center - const Offset(15, 0), paint);
    canvas.drawLine(center + const Offset(15, 0), center + const Offset(60, 0), paint);
    canvas.drawLine(center - const Offset(0, 60), center - const Offset(0, 15), paint);
    canvas.drawLine(center + const Offset(0, 15), center + const Offset(0, 60), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VideoMetric extends StatelessWidget {
  const _VideoMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        border: Border.all(color: const Color(0x8839ff88)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          '$label // $value',
          style: const TextStyle(color: Color(0xff8affb0)),
        ),
      ),
    );
  }
}
