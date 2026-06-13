import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/connection_status.dart';
import '../models/rc_command.dart';
import '../models/tello_telemetry.dart';
import '../services/tello_udp_client.dart';

class TelloController extends ChangeNotifier with WidgetsBindingObserver {
  TelloController({TelloUdpClient? client})
      : _client = client ?? TelloUdpClient() {
    WidgetsBinding.instance.addObserver(this);
  }

  final TelloUdpClient _client;
  TelloConnectionStatus status = TelloConnectionStatus.disconnected;
  TelloTelemetry telemetry = const TelloTelemetry();
  RcCommand rcCommand = const RcCommand();
  String? errorMessage;
  String? lastResponse;

  Timer? _rcTimer;
  Timer? _connectionWatchdog;
  StreamSubscription<String>? _telemetrySubscription;
  DateTime? _lastTelemetryAt;
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
    _rcTimer = null;
    _connectionWatchdog = null;
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
    _client.close();
    super.dispose();
  }
}
