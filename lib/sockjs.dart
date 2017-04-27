import 'dart:async';
import 'dart:js';
import 'package:logging/logging.dart';
import 'src/sockjs_impl.dart';

export 'src/sockjs_impl.dart' show SockJSOptions;

final Logger _log = new Logger("SockJS");

/// Callback when the SockJS connection is established
typedef void OnOpenCallback(SockJsOpenEvent event);

/// Callback when the SockJS connection got lost
typedef void OnCloseCallback(SockJsCloseEvent event);

/// Callback when received a message through SockJS
typedef void OnMessageCallback(SockJsMessageEvent event);

/// State of the SockJS connection
enum SockJSConnectionState { CONNECTING, OPEN, CLOSING, CLOSED }

/// Typesafe facet [SockJSImpl]
class SockJS {
  SockJSImpl _sockJS;

  SockJS(String url, [SockJSOptions options]) {
    _sockJS = new SockJSImpl(url, null, options);
  }

  /// Starts a new [SockJS] instance.
  /// Returns [Future] which will be called when SockJS becomes ready.
  static Future<SockJS> create(String url, [SockJSOptions options]) {
    Completer<SockJS> out = new Completer();

    SockJS socket = new SockJS(url, options);
    socket.onOpen((SockJsOpenEvent event) {
      _log.finest("Connected to ${url}");
      out.complete(socket);
    });
    return out.future;
  }

  /// Set callback that will be called when SockJS becomes open.
  void onOpen(OnOpenCallback callback) {
    _sockJS.onopen = allowInterop(((SimpleEventImpl event) {
      if ("open" == event.type) {
        callback(SockJsOpenEvent._instance);
      } else {
        _log.warning("Expect open event, but was '${event.type}'");
      }
    }));
  }

  /// Set callback that will be called when a message was received over SockJS.
  void onMessage(OnMessageCallback callback) {
    _sockJS.onmessage = allowInterop((SimpleEventImpl event) {
      if ("message" == event.type) {
        callback(new SockJsMessageEvent._(event.data));
      } else {
        _log.warning("Expect message event, but was '${event.type}'");
      }
    });
  }

  /// Set callback that will be called when SockJS get closed.
  void onClose(OnCloseCallback callback) {
    _sockJS.onclose = allowInterop((SimpleEventImpl event) {
      if ("close" == event.type) {
        callback(SockJsCloseEvent._instance);
      } else {
        _log.warning("Expect close event, but was '${event.type}'");
      }
    });
  }

  /// Send given text over SockJS.
  void sendData(String data) {
    _sockJS.send(data);
  }

  /**
     * @return the current ready state of this socket.
     */
  SockJSConnectionState getReadyState() {
    return SockJSConnectionState.values[_sockJS.readyState];
  }
}

enum EventType { CLOSE, MESSAGE, OPEN }

/// Base for SockJS events.
abstract class _SimpleEvent {
  final EventType type;
  const _SimpleEvent(this.type);
}

/// SockJS open event.
class SockJsOpenEvent extends _SimpleEvent {
  static const SockJsOpenEvent _instance = const SockJsOpenEvent._();
  const SockJsOpenEvent._() : super(EventType.OPEN);
}

/// SockJS close event.
class SockJsCloseEvent extends _SimpleEvent {
  static const SockJsCloseEvent _instance = const SockJsCloseEvent._();
  const SockJsCloseEvent._() : super(EventType.CLOSE);
}

/// SockJS message event.
class SockJsMessageEvent extends _SimpleEvent {
  final String data;
  SockJsMessageEvent._(this.data) : super(EventType.MESSAGE);
}
