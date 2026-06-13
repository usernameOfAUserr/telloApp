import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TelloUdpClient {
  TelloUdpClient({
    this.host = '192.168.10.1',
    this.commandPort = 8889,
    this.telemetryPort = 8890,
  });

  final String host;
  final int commandPort;
  final int telemetryPort;

  RawDatagramSocket? _commandSocket;
  RawDatagramSocket? _telemetrySocket;
  StreamController<String>? _telemetryController;
  Completer<String>? _pendingResponse;

  Stream<String> get telemetry {
    final controller = _telemetryController;
    if (controller == null) {
      throw StateError('Call open() before listening to telemetry.');
    }
    return controller.stream;
  }

  Future<void> open() async {
    await close();
    _telemetryController = StreamController<String>.broadcast();
    _commandSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _telemetrySocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      telemetryPort,
    );
    _commandSocket!.listen(_handleCommandEvent);
    _telemetrySocket!.listen(_handleTelemetryEvent);
  }

  Future<String> sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 5),
    bool waitForResponse = true,
  }) async {
    final socket = _commandSocket;
    if (socket == null) throw StateError('UDP client is not open.');

    if (waitForResponse && _pendingResponse != null) {
      throw StateError('Another command is waiting for a response.');
    }

    Completer<String>? response;
    if (waitForResponse) {
      response = Completer<String>();
      _pendingResponse = response;
    }

    socket.send(utf8.encode(command), InternetAddress(host), commandPort);
    if (response == null) return 'sent';

    try {
      return await response.future.timeout(timeout);
    } finally {
      if (identical(_pendingResponse, response)) _pendingResponse = null;
    }
  }

  void _handleCommandEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _commandSocket?.receive();
    if (datagram == null) return;
    final response = utf8.decode(datagram.data).trim();
    final pending = _pendingResponse;
    if (pending != null && !pending.isCompleted) pending.complete(response);
  }

  void _handleTelemetryEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _telemetrySocket?.receive();
    if (datagram == null) return;
    _telemetryController?.add(utf8.decode(datagram.data));
  }

  Future<void> close() async {
    _pendingResponse?.completeError(StateError('UDP client closed.'));
    _pendingResponse = null;
    _commandSocket?.close();
    _telemetrySocket?.close();
    _commandSocket = null;
    _telemetrySocket = null;
    await _telemetryController?.close();
    _telemetryController = null;
  }
}
