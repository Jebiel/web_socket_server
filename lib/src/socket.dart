import 'dart:async';
import 'dart:io' as io;

import 'package:web_socket_server/src/state.dart';

class WebSocket extends Stream<dynamic> with StreamSink<dynamic> {
  WebSocket(
    io.WebSocket socket,
    io.HttpRequest request,
  )   : _socket = socket,
        _request = request;

  final io.WebSocket _socket;
  final io.HttpRequest _request;

  late final uri = _request.uri;
  late final headers = _request.headers;
  late final cookies = _request.cookies;
  late final sessionId = _request.session.id;
  late final certificate = _request.certificate;
  late final queryParameters = _request.uri.queryParameters;
  late final localPort = _request.connectionInfo!.localPort;
  late final remotePort = _request.connectionInfo!.remotePort;
  late final remoteAddress = _request.connectionInfo!.remoteAddress;

  WebSocketState get state => WebSocketState.fromInt(_socket.readyState);

  @override
  void add(event) => _socket.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);

  @override
  Future addStream(Stream stream) => _socket.addStream(stream);

  @override
  Future get done => _socket.done;

  @override
  Future close() => _socket.close();

  @override
  StreamSubscription listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _socket.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
}
