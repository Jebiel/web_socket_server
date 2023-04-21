import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'web_socket_state.dart';

class WebSocketConnection {
  WebSocketConnection(this.socket, HttpConnectionInfo _connectionInfo)
      : localPort = _connectionInfo.localPort,
        remotePort = _connectionInfo.remotePort,
        remoteAddress = _connectionInfo.remoteAddress;

  final WebSocket socket;

  final int localPort;
  final int remotePort;
  final InternetAddress remoteAddress;

  WebSocketState get state => WebSocketState.fromInt(socket.readyState);

  void send(String message) => socket.add(message);

  void sendBytes(Uint8List bytes) => socket.add(bytes);

  void close() => socket.close();
}
