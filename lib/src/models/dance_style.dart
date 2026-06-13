import 'rc_command.dart';

enum DanceStyle {
  neonSway('Neon Sway', 'Links-rechts im Takt', [
    RcCommand(leftRight: -35, yaw: -15),
    RcCommand(leftRight: 35, yaw: 15),
  ]),
  bassBounce('Bass Bounce', 'Kurze Höhenimpulse', [
    RcCommand(upDown: 30),
    RcCommand(upDown: -20),
  ]),
  cyberTwist('Cyber Twist', 'Drehung und Seitenwechsel', [
    RcCommand(leftRight: -25, yaw: 35),
    RcCommand(leftRight: 25, yaw: -35),
    RcCommand(forwardBack: 20, yaw: 25),
    RcCommand(forwardBack: -20, yaw: -25),
  ]),
  pulseBox('Pulse Box', 'Vier Richtungen zum Beat', [
    RcCommand(forwardBack: 30),
    RcCommand(leftRight: 30),
    RcCommand(forwardBack: -30),
    RcCommand(leftRight: -30),
  ]);

  const DanceStyle(this.label, this.subtitle, this.steps);

  final String label;
  final String subtitle;
  final List<RcCommand> steps;
}
