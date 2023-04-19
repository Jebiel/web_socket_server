import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show Uint8List;

typedef WebSocketHandler = void Function(WebSocketConnection);

enum WebSocketState {
  open,
  closed,
  closing,
  unknown;

  static WebSocketState fromInt(int state) {
    switch (state) {
      case WebSocket.open:
        return WebSocketState.open;
      case WebSocket.closed:
        return WebSocketState.closed;
      case WebSocket.closing:
        return WebSocketState.closing;
      default:
        return WebSocketState.unknown;
    }
  }
}

class WebSocketConnection {
  WebSocketConnection(this.socket, HttpConnectionInfo _connectionInfo)
      : localPort = _connectionInfo.localPort,
        remotePort = _connectionInfo.remotePort,
        remoteAddress = _connectionInfo.remoteAddress,
        state = WebSocketState.fromInt(socket.readyState);

  final WebSocket socket;
  final WebSocketState state;

  final int localPort;
  final int remotePort;
  final InternetAddress remoteAddress;

  void send(String message) => socket.add(message);

  void sendBytes(Uint8List bytes) => socket.add(bytes);

  void close() => socket.close();
}

class WebSocketServer extends Stream<WebSocketConnection> {
  /// The HttpServer instance that this WebSocketServer is bound to.
  late Future<HttpServer> _httpServer;

  /// StreamController for managing WebSocket connections
  final _controller = StreamController<WebSocketConnection>();

  /// Returns a random integer in the range 49152 to 65535, which is the
  /// ephemeral port range suggested by IANA and RFC 6335.
  static int get _randomPort => Random().nextInt(65535 - 49152 + 1) + 49152;

  /// Constructor for binding the WebSocketServer to an address and port
  WebSocketServer.bind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
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
    bool requestClientCertificate = false,
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
        final webSocket = await WebSocketTransformer.upgrade(request);
        _controller.add(WebSocketConnection(webSocket, connectionInfo));
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.reasonPhrase = "Only WebSocket connections allowed";
        request.response.close();
      }
    }
  }

  /// Static method for serving a WebSocketHandler on a specified address and
  /// port. [serve] both binds and listens, and returns the resulting
  /// [StreamSubscription].
  ///
  /// [port] defaults to random port within the range 49152 to 65535.
  /// [address] defaults to [InternetAddress.anyIPv6], which covers IPv4 aswell.
  static StreamSubscription<WebSocketConnection> serve(
    WebSocketHandler handler, {
    int? port,
    InternetAddress? address,
  }) {
    final bindPort = port ?? _randomPort;
    final bindAddress = address ?? InternetAddress.anyIPv6;
    return WebSocketServer.bind(bindAddress, bindPort).listen(handler);
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
