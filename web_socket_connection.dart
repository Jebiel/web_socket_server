import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'connection_info.dart';
import 'web_socket_state.dart';

class WebSocketConnection {
  WebSocketConnection(
    this.socket,
    HttpRequest request,
  ) : info = WebSocketConnectionInfo(request);

  final WebSocket socket;

  final WebSocketConnectionInfo info;

  WebSocketState get state => WebSocketState.fromInt(socket.readyState);

  void send(String message) => socket.add(message);

  void sendBytes(Uint8List bytes) => socket.add(bytes);

  void close([int? code, String? reason]) => socket.close(code, reason);
}
