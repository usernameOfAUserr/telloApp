import 'package:flutter_test/flutter_test.dart';
import 'package:tello_app/src/models/tello_telemetry.dart';

void main() {
  test('parses a complete Tello state packet', () {
    const packet = 'pitch:0;roll:1;yaw:-15;vgx:0;vgy:4;vgz:0;'
        'templ:64;temph:67;tof:82;h:80;bat:71;baro:143.52;'
        'time:94;agx:-3.00;agy:1.00;agz:-999.00;';

    final telemetry = TelloTelemetry.fromPacket(packet);

    expect(telemetry.pitch, 0);
    expect(telemetry.roll, 1);
    expect(telemetry.yaw, -15);
    expect(telemetry.velocityY, 4);
    expect(telemetry.averageTemperature, 65.5);
    expect(telemetry.height, 80);
    expect(telemetry.battery, 71);
    expect(telemetry.barometer, 143.52);
    expect(telemetry.accelerationZ, -999);
  });

  test('ignores malformed and unknown fields', () {
    final telemetry = TelloTelemetry.fromPacket('bat:88;broken;foo:bar;');

    expect(telemetry.battery, 88);
    expect(telemetry.pitch, isNull);
  });
}
