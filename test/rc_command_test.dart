import 'package:flutter_test/flutter_test.dart';
import 'package:tello_app/src/models/rc_command.dart';

void main() {
  test('formats values in Tello rc order', () {
    const command = RcCommand(
      leftRight: -30,
      forwardBack: 40,
      upDown: 20,
      yaw: 15,
    );

    expect(command.wireValue, 'rc -30 40 20 15');
  });

  test('normalizes joystick values and clamps the SDK range', () {
    expect(RcCommand.normalize(0.4), 40);
    expect(RcCommand.normalize(-2), -100);
    expect(RcCommand.normalize(2), 100);
    expect(RcCommand.applyDeadZone(0.05), 0);
  });
}
