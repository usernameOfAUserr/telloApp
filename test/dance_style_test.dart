import 'package:flutter_test/flutter_test.dart';
import 'package:tello_app/src/models/dance_style.dart';

void main() {
  test('dance styles contain bounded non-neutral RC steps', () {
    for (final style in DanceStyle.values) {
      expect(style.steps, isNotEmpty);
      for (final step in style.steps) {
        expect(step.isIdle, isFalse);
        expect(step.leftRight.abs(), lessThanOrEqualTo(100));
        expect(step.forwardBack.abs(), lessThanOrEqualTo(100));
        expect(step.upDown.abs(), lessThanOrEqualTo(100));
        expect(step.yaw.abs(), lessThanOrEqualTo(100));
      }
    }
  });
}
