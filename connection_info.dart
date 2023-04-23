import 'dart:io';

class WebSocketConnectionInfo {
  WebSocketConnectionInfo(this._request);

  HttpRequest _request;

  late final uri = _request.uri;
  late final headers = _request.headers;
  late final cookies = _request.cookies;
  late final sessionId = _request.session.id;
  late final certificate = _request.certificate;
  late final queryParameters = _request.uri.queryParameters;
  late final localPort = _request.connectionInfo!.localPort;
  late final remotePort = _request.connectionInfo!.remotePort;
  late final remoteAddress = _request.connectionInfo!.remoteAddress;
}
