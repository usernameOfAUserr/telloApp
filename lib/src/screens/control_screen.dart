import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_status.dart';
import '../providers/tello_provider.dart';
import '../widgets/telemetry_grid.dart';
import '../widgets/virtual_joystick.dart';

class ControlScreen extends ConsumerWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(telloControllerProvider);
    final connected = controller.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tello EDU Controller'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ConnectionBadge(status: controller.status),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: controller.status == TelloConnectionStatus.connecting
                    ? null
                    : connected
                        ? controller.disconnect
                        : controller.connect,
                icon: controller.status == TelloConnectionStatus.connecting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(connected ? Icons.link_off : Icons.wifi),
                label: Text(connected ? 'Verbindung trennen' : 'Mit Tello verbinden'),
              ),
              if (controller.errorMessage case final message?) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(message),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _CommandButton(
                    label: 'Starten',
                    icon: Icons.flight_takeoff,
                    onPressed: connected ? controller.takeOff : null,
                  ),
                  _CommandButton(
                    label: 'Landen',
                    icon: Icons.flight_land,
                    onPressed: connected ? controller.land : null,
                  ),
                  _CommandButton(
                    label: 'Schweben',
                    icon: Icons.pause_circle_outline,
                    onPressed: connected ? controller.stop : null,
                  ),
                  _CommandButton(
                    label: 'NOT-AUS',
                    icon: Icons.warning_amber,
                    danger: true,
                    onPressed: connected
                        ? () => _confirmEmergency(context, controller.emergency)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              IgnorePointer(
                ignoring: !connected,
                child: Opacity(
                  opacity: connected ? 1 : 0.4,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: VirtualJoystick(
                          label: 'Höhe & Drehen',
                          horizontalLabels: const ('Links', 'Rechts'),
                          verticalLabels: const ('Hoch', 'Runter'),
                          onChanged: controller.setLeftJoystick,
                          onReleased: controller.releaseLeftJoystick,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: VirtualJoystick(
                          label: 'Flugrichtung',
                          horizontalLabels: const ('Links', 'Rechts'),
                          verticalLabels: const ('Vor', 'Zurück'),
                          onChanged: controller.setRightJoystick,
                          onReleased: controller.releaseRightJoystick,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Telemetrie', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TelemetryGrid(telemetry: controller.telemetry),
              const SizedBox(height: 12),
              Text(
                'RC: ${controller.rcCommand.wireValue}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmEmergency(
    BuildContext context,
    Future<void> Function() emergency,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not-Aus auslösen?'),
        content: const Text(
          'Die Motoren stoppen sofort. Die Drohne kann unkontrolliert fallen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('NOT-AUS'),
          ),
        ],
      ),
    );
    if (confirmed == true) await emergency();
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
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
    return FilledButton.tonalIcon(
      style: danger
          ? FilledButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            )
          : null,
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
      TelloConnectionStatus.disconnected => (Colors.grey, 'Getrennt'),
      TelloConnectionStatus.connecting => (Colors.orange, 'Verbinden …'),
      TelloConnectionStatus.connected => (Colors.green, 'Verbunden'),
      TelloConnectionStatus.error => (Colors.red, 'Fehler'),
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
