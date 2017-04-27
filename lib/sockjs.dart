library ch.sourcemotion.sockjs;

import 'dart:async';
import 'dart:js';

import 'package:logging/logging.dart';

import 'src/sockjs_impl.dart';

final Logger _logger = new Logger("SockJS");

/**
 * Callback when the SockJS connection is established
 */
typedef void OnOpenCallback(SockJsOpenEvent event);

/**
 * Callback when the SockJS connection got lost
 */
typedef void OnCloseCallback(SockJsCloseEvent event);

/**
 * Callback when received a message through SockJS
 */
typedef void OnMessageCallback(SockJsMessageEvent event);

/**
 * State of the SockJS connection
 */
enum SockJSConnectionState { CONNECTING, OPEN, CLOSING, CLOSED }

/**
 * Please use this class instead of [SockJSImpl]
 */
class SockJS {
  SockJSImpl _sockJS;

  SockJS(String url) {
    _sockJS = new SockJSImpl(url);
  }

  /**
     * Starts a new [SockJS] instance.
     *
     * @return [Future] which will be called when the socket becomes ready.
     */
  static Future<SockJS> create(String url) {
    Completer<SockJS> out = new Completer();

    SockJS socket = new SockJS(url);
    socket.onOpen((SockJsOpenEvent event) {
      out.complete(socket);
    });
    return out.future;
  }

  /**
     * Set callback that will be called when the socket becomes open.
     */
  void onOpen(OnOpenCallback callback) {
    _sockJS.onopen = new JsFunction.withThis(new _OnOpenCallbackCaller(callback));
  }

  /**
     * Set callback that will be called when a message was received on the socket.
     */
  void onMessage(OnMessageCallback callback) {
    _sockJS.onmessage = new JsFunction.withThis(new _OnMessageCallbackCaller(callback));
  }

  /**
     * Set callback that will be called when the socket get closed.
     */
  void onClose(OnCloseCallback callback) {
    _sockJS.onclose = new JsFunction.withThis(new _OnCloseCallbackCaller(callback));
  }

  /**
     * Send given text over the socket.
     */
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

class _OnMessageCallbackCaller {
  final OnMessageCallback realDartMethod;

  _OnMessageCallbackCaller(this.realDartMethod);

  void call(JsObject obj, JsObject obj2) {
    _logger.finest("message received");
    realDartMethod(new SockJsMessageEvent._(obj2));
  }
}

class _OnOpenCallbackCaller {
  final OnOpenCallback realDartMethod;

  _OnOpenCallbackCaller(this.realDartMethod);

  void call(JsObject obj, JsObject obj2) {
    _logger.finest("SockJS connection established");
    realDartMethod(new SockJsOpenEvent._());
  }
}

class _OnCloseCallbackCaller {
  final OnCloseCallback realDartMethod;

  _OnCloseCallbackCaller(this.realDartMethod);

  void call(JsObject obj, JsObject obj2) {
    _logger.finest("SockJS connection closed");
    realDartMethod(new SockJsCloseEvent._());
  }
}

enum EventType { CLOSE, MESSAGE, OPEN }

abstract class _SimpleEvent {
  EventType _type;

  _SimpleEvent(this._type);

  EventType get type => _type;
}

/**
 * Message wrapper for received messages.
 */
class SockJsMessageEvent extends _SimpleEvent {
  String _data;

  SockJsMessageEvent._(JsObject fromWire) : super(EventType.MESSAGE) {
    _data = fromWire['data'];
  }

  String get data => _data;
}

class SockJsOpenEvent extends _SimpleEvent {
  SockJsOpenEvent._() : super(EventType.OPEN);
}

class SockJsCloseEvent extends _SimpleEvent {
  SockJsCloseEvent._() : super(EventType.CLOSE);
}
