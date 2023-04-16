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
  const WebSocketConnection(this._socket, this._connectionInfo);

  final WebSocket _socket;
  final HttpConnectionInfo _connectionInfo;

  WebSocket get socket => _socket;

  int get localPort => _connectionInfo.localPort;
  int get remotePort => _connectionInfo.remotePort;
  String get remoteHost => _connectionInfo.remoteAddress.host;
  String get remoteAddress => _connectionInfo.remoteAddress.address;
  bool get isLinkLocal => _connectionInfo.remoteAddress.isLinkLocal;

  WebSocketState get state => WebSocketState.fromInt(_socket.readyState);

  void send(String message) => _socket.add(message);

  void sendBytes(Uint8List bytes) => _socket.add(bytes);

  void close() => _socket.close();
}

class WebSocketServer extends Stream<WebSocketConnection> {
  late Future<HttpServer> _httpServer;
  final _controller = StreamController<WebSocketConnection>();

  // Returns a random integer in the range 49152 to 65535, which is the
  // ephemeral port range suggested by IANA and RFC 6335.
  static int get _randomPort => Random().nextInt(65535 - 49152 + 1) + 49152;

  WebSocketServer._(address, int port, int backlog, bool v6Only, bool shared) {
    _httpServer = HttpServer.bind(
      address,
      port,
      backlog: backlog,
      v6Only: v6Only,
      shared: shared,
    );
    _acceptConnections();
  }

  factory WebSocketServer.bind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) =>
      WebSocketServer._(address, port, backlog, v6Only, shared);

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

  static StreamSubscription<WebSocketConnection> serve(
    WebSocketHandler handler, {
    int? port,
    InternetAddress? address,
  }) {
    final bindPort = port ?? _randomPort;
    final bindAddress = address ?? InternetAddress.anyIPv6;
    return WebSocketServer.bind(bindAddress, bindPort).listen(handler);
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
