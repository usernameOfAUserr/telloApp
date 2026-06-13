class TelloTelemetry {
  const TelloTelemetry({
    this.pitch,
    this.roll,
    this.yaw,
    this.velocityX,
    this.velocityY,
    this.velocityZ,
    this.temperatureLow,
    this.temperatureHigh,
    this.tof,
    this.height,
    this.battery,
    this.barometer,
    this.flightTime,
    this.accelerationX,
    this.accelerationY,
    this.accelerationZ,
    this.lastUpdated,
  });

  final int? pitch;
  final int? roll;
  final int? yaw;
  final int? velocityX;
  final int? velocityY;
  final int? velocityZ;
  final int? temperatureLow;
  final int? temperatureHigh;
  final int? tof;
  final int? height;
  final int? battery;
  final double? barometer;
  final int? flightTime;
  final double? accelerationX;
  final double? accelerationY;
  final double? accelerationZ;
  final DateTime? lastUpdated;

  double? get averageTemperature {
    if (temperatureLow == null || temperatureHigh == null) return null;
    return (temperatureLow! + temperatureHigh!) / 2;
  }

  factory TelloTelemetry.fromPacket(String packet, {DateTime? receivedAt}) {
    final values = <String, String>{};
    for (final field in packet.trim().split(';')) {
      final separator = field.indexOf(':');
      if (separator <= 0) continue;
      values[field.substring(0, separator)] = field.substring(separator + 1);
    }

    int? integer(String key) => int.tryParse(values[key] ?? '');
    double? decimal(String key) => double.tryParse(values[key] ?? '');

    return TelloTelemetry(
      pitch: integer('pitch'),
      roll: integer('roll'),
      yaw: integer('yaw'),
      velocityX: integer('vgx'),
      velocityY: integer('vgy'),
      velocityZ: integer('vgz'),
      temperatureLow: integer('templ'),
      temperatureHigh: integer('temph'),
      tof: integer('tof'),
      height: integer('h'),
      battery: integer('bat'),
      barometer: decimal('baro'),
      flightTime: integer('time'),
      accelerationX: decimal('agx'),
      accelerationY: decimal('agy'),
      accelerationZ: decimal('agz'),
      lastUpdated: receivedAt ?? DateTime.now(),
    );
  }
}
