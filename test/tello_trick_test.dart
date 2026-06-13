import 'package:flutter_test/flutter_test.dart';
import 'package:tello_app/src/models/tello_trick.dart';

void main() {
  test('maps tricks to supported Tello SDK commands', () {
    expect(TelloTrick.flipForward.command, 'flip f');
    expect(TelloTrick.flipBack.command, 'flip b');
    expect(TelloTrick.flipLeft.command, 'flip l');
    expect(TelloTrick.flipRight.command, 'flip r');
    expect(TelloTrick.spinClockwise.command, 'cw 360');
    expect(TelloTrick.spinCounterClockwise.command, 'ccw 360');
  });
}
