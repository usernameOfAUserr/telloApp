import 'dart:math' as math;

class RcCommand {
  const RcCommand({
    this.leftRight = 0,
    this.forwardBack = 0,
    this.upDown = 0,
    this.yaw = 0,
  });

  final int leftRight;
  final int forwardBack;
  final int upDown;
  final int yaw;

  static int normalize(double value) => (value * 100).round().clamp(-100, 100);

  RcCommand copyWith({
    int? leftRight,
    int? forwardBack,
    int? upDown,
    int? yaw,
  }) {
    return RcCommand(
      leftRight: leftRight ?? this.leftRight,
      forwardBack: forwardBack ?? this.forwardBack,
      upDown: upDown ?? this.upDown,
      yaw: yaw ?? this.yaw,
    );
  }

  bool get isIdle =>
      leftRight == 0 && forwardBack == 0 && upDown == 0 && yaw == 0;

  String get wireValue => 'rc $leftRight $forwardBack $upDown $yaw';

  @override
  bool operator ==(Object other) =>
      other is RcCommand &&
      leftRight == other.leftRight &&
      forwardBack == other.forwardBack &&
      upDown == other.upDown &&
      yaw == other.yaw;

  @override
  int get hashCode => Object.hash(leftRight, forwardBack, upDown, yaw);

  static double applyDeadZone(double value, [double deadZone = 0.08]) {
    if (value.abs() <= deadZone) return 0;
    final scaled = (value.abs() - deadZone) / (1 - deadZone);
    return math.min(1, scaled) * value.sign;
  }
}
