import 'dart:async';
import 'dart:io';

import 'web_socket_connection.dart';
import 'web_socket_connection_info.dart';

typedef AuthCallback = bool Function(WebSocketConnectionInfo);

class WebSocketServer extends Stream<WebSocketConnection> {
  /// The interval at which ping messages are sent to the client.
  /// If null, no ping messages are sent.
  final Duration? pingInterval;

  /// The compression options to use for the WebSocket connection.
  /// Defaults to [CompressionOptions.compressionDefault].
  final CompressionOptions compression;

  /// The protocol selector function to use for the WebSocket connection.
  /// If null, the first protocol in the client's list of supported protocols
  /// is selected. If the client does not support any of the server's
  /// protocols, the connection is rejected.
  final dynamic Function(List<String>)? protocolSelector;

  /// The HttpServer instance that this WebSocketServer is bound to.
  late Future<HttpServer> _httpServer;

  /// A function that is called when a new connection is established.
  /// If the function returns true, the connection is accepted, otherwise it is
  /// rejected.
  final AuthCallback? authorize;

  /// StreamController for managing WebSocket connections
  final _controller = StreamController<WebSocketConnection>();

  /// Constructor for creating a WebSocketServer instance.
  WebSocketServer.bind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
    this.authorize,
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

  /// Constructor for creating a secure WebSocketServer instance that uses a
  /// [SecurityContext] for handling secure connections.
  WebSocketServer.bindSecure(
    dynamic address,
    int port,
    SecurityContext context, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
    this.authorize,
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
        final connection = WebSocketConnection(webSocket, request);
        if (authorize == null || authorize!(connection.info)) {
          _controller.add(connection);
        } else {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.close();
        }
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.close();
      }
    }
  }

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
