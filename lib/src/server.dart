import 'dart:async';
import 'dart:io';

import 'socket.dart' as socket;

typedef VoidCallback = void Function();
typedef ProtocolSelector = dynamic Function(List<String>);
typedef AuthCallback = bool Function(HttpRequest request);
typedef ConnectionHandler = void Function(socket.WebSocket conn);

class WebSocketServer extends Stream<socket.WebSocket> {
  /// The port that this WebSocketServer is bound to.
  int port;

  /// The address that this WebSocketServer is bound to.
  dynamic address;

  /// The [SecurityContext] associated with this WebSocketServer, if it's a
  /// secure server. If null, the server is not secure.
  SecurityContext? securityContext;

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
  final _controller = StreamController<socket.WebSocket>();

  /// A boolean getter for determining whether or not this WebSocketServer is
  /// secure. If [securityContext] is null, this getter returns false.
  bool get isSecure => securityContext != null;

  String get _scheme => isSecure ? 'wss' : 'ws';

  String get url => '$_scheme://$address:$port';

  /// This is a convenience getter for getting the [StreamController]'s stream,
  /// with or without a timeout, based on the presence of [idleTimeout].
  Stream<socket.WebSocket> get _stream => idleTimeout == null
      ? _controller.stream
      : _controller.stream.timeout(idleTimeout!, onTimeout: (s) => s.close());

  /// Constructor for creating a WebSocketServer instance.
  WebSocketServer.bind(
    this.address,
    this.port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
    this.idleTimeout,
    this.pingInterval,
    AuthCallback? authorize,
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
    this.address,
    this.port,
    SecurityContext this.securityContext, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
    this.idleTimeout,
    this.pingInterval,
    AuthCallback? authorize,
    bool requestClientCertificate = false,
    ProtocolSelector? protocolSelector,
    this.compression = CompressionOptions.compressionDefault,
  })  : _authorize = authorize,
        _protocolSelector = protocolSelector,
        _httpServer = HttpServer.bindSecure(
          address,
          port,
          securityContext,
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
      // Skip all requests that are not upgrade requests.
      if (!request.isUpgradeRequest) {
        (request.response..statusCode = HttpStatus.forbidden).close();
        continue;
      }
      // Check if the connection should be accepted.
      // If the authorize function is null, the connection is accepted.
      if (_authorize?.call(request) ?? true) {
        final webSocket = socket.WebSocket(
          await request.upgradeToWebSocket(
            compression: compression,
            pingInterval: pingInterval,
            protocolSelector: _protocolSelector,
          ),
          request,
        );

        _controller.add(webSocket);
      } else {
        (request.response..statusCode = HttpStatus.unauthorized).close();
      }
    }
  }

  // Close method for closing the WebSocketServer.
  Future<void> close({int? code, String? reason}) async {
    (await _httpServer).close(force: true);
    await _controller.close();
  }

  @override
  StreamSubscription<socket.WebSocket> listen(
    ConnectionHandler? onData, {
    Function? onError,
    VoidCallback? onDone,
    bool? cancelOnError,
  }) =>
      _stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
}

extension HttpRequestExtensions on HttpRequest {
  Map<String, String> get queryParameters => uri.queryParameters;

  bool get isUpgradeRequest =>
      connectionInfo != null && WebSocketTransformer.isUpgradeRequest(this);

  Future<WebSocket> upgradeToWebSocket({
    Duration? pingInterval,
    ProtocolSelector? protocolSelector,
    CompressionOptions compression = CompressionOptions.compressionDefault,
  }) async =>
      await WebSocketTransformer.upgrade(
        this,
        compression: compression,
        protocolSelector: protocolSelector,
      )
        ..pingInterval = pingInterval;
}
