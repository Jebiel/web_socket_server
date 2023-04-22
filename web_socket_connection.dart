import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'web_socket_state.dart';

class WebSocketConnection {
  WebSocketConnection(
    this.socket,
    HttpRequest _request,
  )   : cookies = _request.cookies,
        headers = _request.headers,
        queryParameters = _request.uri.queryParameters,
        localPort = _request.connectionInfo!.localPort,
        remotePort = _request.connectionInfo!.remotePort,
        remoteAddress = _request.connectionInfo!.remoteAddress;

  final WebSocket socket;

  final int localPort;
  final int remotePort;
  final InternetAddress remoteAddress;

  final HttpHeaders headers;
  final List<Cookie> cookies;
  final Map<String, String> queryParameters;

  WebSocketState get state => WebSocketState.fromInt(socket.readyState);

  void send(String message) => socket.add(message);

  void sendBytes(Uint8List bytes) => socket.add(bytes);

  void close([int? code, String? reason]) => socket.close(code, reason);
}
