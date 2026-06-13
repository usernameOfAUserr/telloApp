import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/connection_status.dart';
import '../models/dance_style.dart';
import '../models/rc_command.dart';
import '../models/tello_telemetry.dart';
import '../models/tello_trick.dart';
import '../services/tello_audio_bridge.dart';
import '../services/tello_udp_client.dart';
import '../services/tello_video_bridge.dart';

class TelloController extends ChangeNotifier with WidgetsBindingObserver {
  TelloController({
    TelloUdpClient? client,
    TelloVideoBridge? videoBridge,
    TelloAudioBridge? audioBridge,
  })
      : _client = client ?? TelloUdpClient(),
        _videoBridge = videoBridge ?? TelloVideoBridge(),
        _audioBridge = audioBridge ?? TelloAudioBridge() {
    WidgetsBinding.instance.addObserver(this);
  }

  final TelloUdpClient _client;
  final TelloVideoBridge _videoBridge;
  final TelloAudioBridge _audioBridge;
  TelloConnectionStatus status = TelloConnectionStatus.disconnected;
  TelloTelemetry telemetry = const TelloTelemetry();
  RcCommand rcCommand = const RcCommand();
  String? errorMessage;
  String? lastResponse;
  bool isVideoActive = false;
  bool isVideoBusy = false;
  bool isRecording = false;
  bool isTrickRunning = false;
  String? mediaMessage;
  DanceStyle? activeDanceStyle;
  double lastBeatStrength = 0;

  Timer? _rcTimer;
  Timer? _connectionWatchdog;
  Timer? _danceResetTimer;
  StreamSubscription<String>? _telemetrySubscription;
  StreamSubscription<double>? _beatSubscription;
  DateTime? _lastTelemetryAt;
  DateTime? _lastBeatAt;
  int _danceStep = 0;
  bool _disposed = false;

  bool get isConnected => status == TelloConnectionStatus.connected;

  Future<void> connect() async {
    if (status == TelloConnectionStatus.connecting || isConnected) return;
    _setStatus(TelloConnectionStatus.connecting);
    errorMessage = null;

    try {
      await _client.open();
      _telemetrySubscription = _client.telemetry.listen(
        _handleTelemetry,
        onError: _handleError,
      );
      final response = await _client.sendCommand('command');
      if (response.toLowerCase() != 'ok') {
        throw StateError('Tello rejected SDK mode: $response');
      }
      lastResponse = response;
      _setStatus(TelloConnectionStatus.connected);
      _rcTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _sendRcCommand(),
      );
      _connectionWatchdog = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _checkConnection(),
      );
    } catch (error) {
      await _failAndClose('Verbindung fehlgeschlagen: $error');
    }
  }

  Future<void> disconnect() async {
    await stopDance();
    await stopVideo();
    if (isConnected) await _sendNeutralRc();
    _cancelRuntime();
    await _telemetrySubscription?.cancel();
    _telemetrySubscription = null;
    await _client.close();
    rcCommand = const RcCommand();
    _setStatus(TelloConnectionStatus.disconnected);
  }

  Future<void> takeOff() => _runFlightCommand('takeoff');
  Future<void> land() => _runFlightCommand('land');
  Future<void> stop() => _runFlightCommand('stop');
  Future<void> performTrick(TelloTrick trick, {int repetitions = 1}) async {
    if (!isConnected || isTrickRunning) return;
    await stopDance();
    isTrickRunning = true;
    errorMessage = null;
    notifyListeners();
    try {
      for (var repetition = 0; repetition < repetitions; repetition++) {
        for (final command in trick.commands) {
          await _runFlightCommand(command);
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
    } finally {
      isTrickRunning = false;
      notifyListeners();
    }
  }

  Future<void> startDance(DanceStyle style) async {
    if (!isConnected || isTrickRunning) return;
    await stopDance();
    try {
      activeDanceStyle = style;
      _danceStep = 0;
      _beatSubscription = _audioBridge.beats.listen(
        _handleBeat,
        onError: _handleError,
      );
      await _audioBridge.start();
      notifyListeners();
    } catch (error) {
      await _beatSubscription?.cancel();
      _beatSubscription = null;
      activeDanceStyle = null;
      errorMessage = 'Dance Mode konnte nicht gestartet werden: $error';
      notifyListeners();
    }
  }

  Future<void> stopDance() async {
    _danceResetTimer?.cancel();
    _danceResetTimer = null;
    await _beatSubscription?.cancel();
    _beatSubscription = null;
    if (activeDanceStyle != null) {
      try {
        await _audioBridge.stop();
      } catch (error) {
        errorMessage = 'Dance Mode konnte nicht beendet werden: $error';
      }
    }
    activeDanceStyle = null;
    lastBeatStrength = 0;
    rcCommand = const RcCommand();
    _sendRcCommand();
    notifyListeners();
  }

  void _handleBeat(double strength) {
    final style = activeDanceStyle;
    if (style == null) return;
    final now = DateTime.now();
    final previous = _lastBeatAt;
    if (previous != null &&
        now.difference(previous) < const Duration(milliseconds: 260)) {
      return;
    }
    _lastBeatAt = now;
    lastBeatStrength = strength;
    rcCommand = style.steps[_danceStep % style.steps.length];
    _danceStep++;
    _danceResetTimer?.cancel();
    _danceResetTimer = Timer(const Duration(milliseconds: 220), () {
      rcCommand = const RcCommand();
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> startVideo() async {
    if (!isConnected || isVideoActive || isVideoBusy) return;
    isVideoBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _client.sendCommand('streamon');
      if (response.toLowerCase() != 'ok') {
        throw StateError('Tello rejected video stream: $response');
      }
      await _videoBridge.start();
      isVideoActive = true;
    } catch (error) {
      errorMessage = 'Videostream konnte nicht gestartet werden: $error';
      try {
        await _client.sendCommand('streamoff');
      } catch (_) {
        // Preserve the original video startup error.
      }
    } finally {
      isVideoBusy = false;
      notifyListeners();
    }
  }

  Future<void> stopVideo() async {
    if ((!isVideoActive && !isVideoBusy) || !isConnected) return;
    isVideoBusy = true;
    notifyListeners();
    try {
      if (isRecording) await stopRecording();
      await _videoBridge.stop();
      await _client.sendCommand('streamoff');
    } catch (error) {
      errorMessage = 'Videostream konnte nicht beendet werden: $error';
    } finally {
      isVideoActive = false;
      isVideoBusy = false;
      notifyListeners();
    }
  }

  Future<void> capturePhoto() async {
    if (!isVideoActive) return;
    try {
      final path = await _videoBridge.capturePhoto();
      mediaMessage = path == null ? 'Foto gespeichert' : 'Foto: $path';
      notifyListeners();
    } catch (error) {
      errorMessage = 'Foto konnte nicht gespeichert werden: $error';
      notifyListeners();
    }
  }

  Future<void> toggleRecording() =>
      isRecording ? stopRecording() : startRecording();

  Future<void> startRecording() async {
    if (!isVideoActive || isRecording) return;
    try {
      await _videoBridge.startRecording();
      isRecording = true;
      mediaMessage = 'Videoaufnahme läuft';
      notifyListeners();
    } catch (error) {
      errorMessage = 'Videoaufnahme konnte nicht gestartet werden: $error';
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    if (!isRecording) return;
    try {
      final path = await _videoBridge.stopRecording();
      mediaMessage = path == null ? 'Video gespeichert' : 'Video: $path';
    } catch (error) {
      errorMessage = 'Videoaufnahme konnte nicht gespeichert werden: $error';
    } finally {
      isRecording = false;
      notifyListeners();
    }
  }

  Future<void> emergency() async {
    if (!isConnected) return;
    rcCommand = const RcCommand();
    notifyListeners();
    try {
      lastResponse = await _client.sendCommand('emergency');
      notifyListeners();
    } catch (error) {
      _handleError(error);
    }
  }

  void setLeftJoystick(double x, double y) {
    rcCommand = rcCommand.copyWith(
      yaw: RcCommand.normalize(RcCommand.applyDeadZone(x)),
      upDown: RcCommand.normalize(RcCommand.applyDeadZone(-y)),
    );
    notifyListeners();
  }

  void setRightJoystick(double x, double y) {
    rcCommand = rcCommand.copyWith(
      leftRight: RcCommand.normalize(RcCommand.applyDeadZone(x)),
      forwardBack: RcCommand.normalize(RcCommand.applyDeadZone(-y)),
    );
    notifyListeners();
  }

  void releaseLeftJoystick() {
    rcCommand = rcCommand.copyWith(yaw: 0, upDown: 0);
    _sendRcCommand();
    notifyListeners();
  }

  void releaseRightJoystick() {
    rcCommand = rcCommand.copyWith(leftRight: 0, forwardBack: 0);
    _sendRcCommand();
    notifyListeners();
  }

  Future<void> _runFlightCommand(String command) async {
    if (!isConnected) return;
    try {
      lastResponse = await _client.sendCommand(command);
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _sendRcCommand() async {
    if (!isConnected) return;
    try {
      await _client.sendCommand(rcCommand.wireValue, waitForResponse: false);
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> _sendNeutralRc() async {
    rcCommand = const RcCommand();
    await _sendRcCommand();
  }

  void _handleTelemetry(String packet) {
    telemetry = TelloTelemetry.fromPacket(packet);
    _lastTelemetryAt = telemetry.lastUpdated;
    notifyListeners();
  }

  void _checkConnection() {
    final lastPacket = _lastTelemetryAt;
    if (lastPacket != null &&
        DateTime.now().difference(lastPacket) > const Duration(seconds: 5)) {
      errorMessage = 'Seit 5 Sekunden keine Telemetriedaten empfangen.';
      notifyListeners();
    }
  }

  void _handleError(Object error) {
    errorMessage = error.toString();
    notifyListeners();
  }

  Future<void> _failAndClose(String message) async {
    _cancelRuntime();
    await _telemetrySubscription?.cancel();
    _telemetrySubscription = null;
    await _client.close();
    errorMessage = message;
    _setStatus(TelloConnectionStatus.error);
  }

  void _cancelRuntime() {
    _rcTimer?.cancel();
    _connectionWatchdog?.cancel();
    _danceResetTimer?.cancel();
    _rcTimer = null;
    _connectionWatchdog = null;
    _danceResetTimer = null;
  }

  void _setStatus(TelloConnectionStatus value) {
    status = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      rcCommand = const RcCommand();
      _sendRcCommand();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cancelRuntime();
    _telemetrySubscription?.cancel();
    _beatSubscription?.cancel();
    if (activeDanceStyle != null) _audioBridge.stop();
    if (isVideoActive) _videoBridge.stop();
    _client.close();
    super.dispose();
  }
}
