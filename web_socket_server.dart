import 'dart:async';
import 'dart:io';

import 'web_socket_connection.dart';

typedef WebSocketHandler = void Function(WebSocketConnection);

class WebSocketServer extends Stream<WebSocketConnection> {
  final Duration? pingInterval;

  final CompressionOptions compression;
  final dynamic Function(List<String>)? protocolSelector;

  /// The HttpServer instance that this WebSocketServer is bound to.
  late Future<HttpServer> _httpServer;

  /// StreamController for managing WebSocket connections
  final _controller = StreamController<WebSocketConnection>();

  /// Constructor for binding the WebSocketServer to an address and port
  WebSocketServer.bind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
    this.pingInterval,
    this.protocolSelector,
    this.compression = CompressionOptions.compressionDefault,
  }) : _httpServer = HttpServer.bind(
          address,
          port,
          backlog: backlog,
          v6Only: v6Only,
          shared: shared,
        ) {
    _acceptConnections();
  }

  /// Constructor for creating a secure WebSocketServer (wss)
  WebSocketServer.bindSecure(
    dynamic address,
    int port,
    SecurityContext context, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
    this.pingInterval,
    bool requestClientCertificate = false,
    this.protocolSelector,
    this.compression = CompressionOptions.compressionDefault,
  }) : _httpServer = HttpServer.bindSecure(
          address,
          port,
          context,
          backlog: backlog,
          v6Only: v6Only,
          shared: shared,
          requestClientCertificate: requestClientCertificate,
        ) {
    _acceptConnections();
  }

  /// Method for accepting incoming connections through the [HttpServer] and
  /// upgrading them to WebSocket connections.
  void _acceptConnections() async {
    await for (final request in await _httpServer) {
      final connectionInfo = request.connectionInfo;
      final isUpgradeRequest = WebSocketTransformer.isUpgradeRequest(request);
      if (isUpgradeRequest && connectionInfo != null) {
        final webSocket = await WebSocketTransformer.upgrade(
          request,
          compression: compression,
          protocolSelector: protocolSelector,
        );
        if (pingInterval != null) {
          webSocket.pingInterval = pingInterval!;
        }
        _controller.add(WebSocketConnection(webSocket, connectionInfo));
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.close();
      }
    }
  }

  /// Forward this Stream class' listen method, to the listen method of it's
  /// local StreamController instance [_controller].
  @override
  StreamSubscription<WebSocketConnection> listen(
    void Function(WebSocketConnection conn)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _controller.stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
}
