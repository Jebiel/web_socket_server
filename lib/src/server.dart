import 'dart:async';
import 'dart:io';

import 'connection.dart';
import 'connection_info.dart';

typedef ProtocolSelector = dynamic Function(List<String>);
typedef AuthCallback = bool Function(WebSocketConnectionInfo);

class WebSocketServer extends Stream<WebSocketConnection> {
  /// The maximum time that may pass without sending or receiving a message on
  /// a WebSocket connection before it is closed due to idleness.
  final Duration? idleTimeout;

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
  final ProtocolSelector? _protocolSelector;

  /// The HttpServer instance that this WebSocketServer is bound to.
  late final Future<HttpServer> _httpServer;

  /// A function that is called when a new connection is established.
  /// If the function returns true, the connection is accepted, otherwise it is
  /// rejected. If the function is null, all connections are accepted.
  final AuthCallback? _authorize;

  /// StreamController for managing WebSocket connections
  final _controller = StreamController<WebSocketConnection>();

  /// Constructor for creating a WebSocketServer instance.
  WebSocketServer.bind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
    AuthCallback? authorize,
    this.idleTimeout,
    this.pingInterval,
    ProtocolSelector? protocolSelector,
    this.compression = CompressionOptions.compressionDefault,
  })  : _authorize = authorize,
        _protocolSelector = protocolSelector,
        _httpServer = HttpServer.bind(
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
    AuthCallback? authorize,
    this.idleTimeout,
    this.pingInterval,
    bool requestClientCertificate = false,
    ProtocolSelector? protocolSelector,
    this.compression = CompressionOptions.compressionDefault,
  })  : _authorize = authorize,
        _protocolSelector = protocolSelector,
        _httpServer = HttpServer.bindSecure(
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
          protocolSelector: _protocolSelector,
        );
        if (pingInterval != null) {
          webSocket.pingInterval = pingInterval!;
        }
        final connection = WebSocketConnection(webSocket, request);
        if (_authorize == null || _authorize!(connection.info)) {
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
