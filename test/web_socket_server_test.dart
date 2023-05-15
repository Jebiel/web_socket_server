import 'dart:io';

import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_server/src/socket.dart';
import 'package:web_socket_server/web_socket_server.dart';

void main() {
  test(
    'Server can receive message from client',
    () async {
      final (socket, sink) = await testBind('localhost', 8080);
      try {
        sink.add('test');
        final data = await socket.first;
        expect('test', equals(data));
      } finally {
        await sink.close();
        await socket.close();
      }
    },
    timeout: Timeout(Duration(seconds: 5)),
  );
}

Future<(WebSocket, WebSocketSink)> testBind(address, int port) =>
    _testBind(WebSocketServer.bind(address, port));

Future<(WebSocket, WebSocketSink)> testBindSecure(
  address,
  int port,
  SecurityContext securityContext,
) =>
    _testBind(WebSocketServer.bindSecure(address, port, securityContext));

Future<(WebSocket, WebSocketSink)> _testBind(WebSocketServer server) async {
  late final IOWebSocketChannel channel;
  final future = server.first.then((socket) => (socket, channel.sink));
  channel = IOWebSocketChannel.connect(server.url);
  return future;
}
