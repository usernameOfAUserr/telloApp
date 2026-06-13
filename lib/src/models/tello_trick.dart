enum TelloTrick {
  flipForward('Frontflip', 'flip f'),
  flipBack('Backflip', 'flip b'),
  flipLeft('Linker Flip', 'flip l'),
  flipRight('Rechter Flip', 'flip r'),
  spinClockwise('Drehung rechts', 'cw 360'),
  spinCounterClockwise('Drehung links', 'ccw 360');

  const TelloTrick(this.label, this.command);

  final String label;
  final String command;
}
