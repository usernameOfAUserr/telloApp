import 'package:flutter/services.dart';

class TelloVideoBridge {
  static const _channel = MethodChannel('de.example.telloapp/video');

  Future<void> start() => _channel.invokeMethod<void>('start');

  Future<void> stop() => _channel.invokeMethod<void>('stop');

  Future<String?> capturePhoto() =>
      _channel.invokeMethod<String>('capturePhoto');

  Future<String?> startRecording() =>
      _channel.invokeMethod<String>('startRecording');

  Future<String?> stopRecording() =>
      _channel.invokeMethod<String>('stopRecording');
}
