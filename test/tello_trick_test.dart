import 'package:flutter_test/flutter_test.dart';
import 'package:tello_app/src/models/tello_trick.dart';

void main() {
  test('maps tricks to supported Tello SDK commands', () {
    expect(TelloTrick.flipForward.commands, ['flip f']);
    expect(TelloTrick.flipBack.commands, ['flip b']);
    expect(TelloTrick.flipLeft.commands, ['flip l']);
    expect(TelloTrick.flipRight.commands, ['flip r']);
    expect(TelloTrick.spinClockwise.commands, ['cw 360']);
    expect(TelloTrick.spinCounterClockwise.commands, ['ccw 360']);
  });

  test('provides multi-command creative flight routines', () {
    expect(TelloTrick.circle.commands, hasLength(4));
    expect(TelloTrick.spiralUp.commands, hasLength(4));
    expect(TelloTrick.spiralDown.commands, hasLength(4));
    expect(
      TelloTrick.values.expand((trick) => trick.commands),
      everyElement(
        anyOf(
          startsWith('flip '),
          startsWith('cw '),
          startsWith('ccw '),
          startsWith('curve '),
          startsWith('forward '),
          startsWith('right '),
          startsWith('back '),
          startsWith('left '),
        ),
      ),
    );
  });
}
