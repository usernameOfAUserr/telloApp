import 'package:flutter/material.dart';

import '../models/tello_telemetry.dart';

class TelemetryGrid extends StatelessWidget {
  const TelemetryGrid({required this.telemetry, super.key});

  final TelloTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.battery_5_bar, 'Akku', _value(telemetry.battery, '%')),
      (Icons.height, 'Höhe', _value(telemetry.height, ' cm')),
      (Icons.timer_outlined, 'Flugzeit', _value(telemetry.flightTime, ' s')),
      (Icons.thermostat, 'Temperatur', _decimal(telemetry.averageTemperature, ' °C')),
      (Icons.threed_rotation, 'Pitch / Roll / Yaw', '${_raw(telemetry.pitch)} / ${_raw(telemetry.roll)} / ${_raw(telemetry.yaw)}°'),
      (Icons.speed, 'Geschwindigkeit X/Y/Z', '${_raw(telemetry.velocityX)} / ${_raw(telemetry.velocityY)} / ${_raw(telemetry.velocityZ)} cm/s'),
      (Icons.vibration, 'Beschleunigung X/Y/Z', '${_raw(telemetry.accelerationX)} / ${_raw(telemetry.accelerationY)} / ${_raw(telemetry.accelerationZ)}'),
      (Icons.compress, 'Barometer', _decimal(telemetry.barometer, ' cm')),
      (Icons.straighten, 'Time of Flight', _value(telemetry.tof, ' cm')),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 2.1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(item.$1, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2, style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 3),
                          Text(item.$3, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _raw(Object? value) => value?.toString() ?? '–';
  static String _value(Object? value, String suffix) =>
      value == null ? '–' : '$value$suffix';
  static String _decimal(double? value, String suffix) =>
      value == null ? '–' : '${value.toStringAsFixed(1)}$suffix';
}
