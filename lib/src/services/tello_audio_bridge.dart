import 'package:flutter/services.dart';

class TelloAudioBridge {
  static const _methods = MethodChannel('de.example.telloapp/audio');
  static const _beats = EventChannel('de.example.telloapp/beats');

  Stream<double> get beats =>
      _beats.receiveBroadcastStream().map((value) => (value as num).toDouble());

  Future<void> start() => _methods.invokeMethod<void>('start');

  Future<void> stop() => _methods.invokeMethod<void>('stop');
}
