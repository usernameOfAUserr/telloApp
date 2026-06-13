enum TelloTrick {
  flipForward('Frontflip', 'VERTICAL IMPULSE', ['flip f']),
  flipBack('Backflip', 'REVERSE IMPULSE', ['flip b']),
  flipLeft('Linker Flip', 'LATERAL ROLL −', ['flip l']),
  flipRight('Rechter Flip', 'LATERAL ROLL +', ['flip r']),
  spinClockwise('Drehung rechts', 'YAW 360° +', ['cw 360']),
  spinCounterClockwise('Drehung links', 'YAW 360° −', ['ccw 360']),
  square(
    'Cyber-Quadrat',
    '4-PUNKT FLUGROUTE',
    ['forward 100', 'right 100', 'back 100', 'left 100'],
  ),
  circle(
    'Kreisflug',
    'GESCHLOSSENER ORBIT',
    [
      'curve 50 50 0 100 0 0 40',
      'curve 50 -50 0 0 -100 0 40',
      'curve -50 -50 0 -100 0 0 40',
      'curve -50 50 0 0 100 0 40',
    ],
  ),
  spiralUp(
    'Spirale hoch',
    'ORBIT MIT HÖHENGEWINN',
    [
      'curve 50 50 30 100 0 60 35',
      'curve 50 -50 30 0 -100 60 35',
      'curve -50 -50 30 -100 0 60 35',
      'curve -50 50 30 0 100 60 35',
    ],
  ),
  spiralDown(
    'Spirale runter',
    'ORBIT MIT HÖHENVERLUST',
    [
      'curve 50 50 -30 100 0 -60 35',
      'curve 50 -50 -30 0 -100 -60 35',
      'curve -50 -50 -30 -100 0 -60 35',
      'curve -50 50 -30 0 100 -60 35',
    ],
  ),
  zigzag(
    'Neon-Zickzack',
    'SCHNELLE VECTOR-WECHSEL',
    [
      'curve 50 50 0 100 0 0 50',
      'curve 50 -50 0 100 0 0 50',
      'curve 50 50 0 100 0 0 50',
    ],
  );

  const TelloTrick(this.label, this.subtitle, this.commands);

  final String label;
  final String subtitle;
  final List<String> commands;
}
