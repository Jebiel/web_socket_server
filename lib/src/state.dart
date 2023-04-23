import 'dart:io';

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
