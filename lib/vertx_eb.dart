import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:js';

import 'package:js/js_util.dart';
import 'package:logging/logging.dart';
import 'package:vertx_dart_sockjs/src/vertx_eb_impl.dart';

/// Exception, mainly used for wrong use of the [EventBus].
class EventBusException implements Exception {
  final String message;

  const EventBusException(this.message);

  @override
  String toString() {
    return 'EventBusException{message: $message}';
  }
}

/// Consumer of incipient events from the Vertx event bus.
typedef void Consumer(VertxMessage messageValue);

/// Consumer of reply events from the Vertx event bus.
typedef void ReplyConsumer(AsyncResult result);

/// Entry point to the connection API with the Vert.x SockJS event bus bidge: http://vertx.io/docs/vertx-web/java/#_sockjs_event_bus_bridge.
/// Based on SockJS version 0.3.4
class EventBus {
  static final Logger _log = new Logger("EventBus");

  final EventBusJS _eb;

  /// When [true] the client tries to convert the body of any received message into a [Map] with [Json.decode]
  final bool autoConvertMessageBodies;

  /// When given all [Consumer] will get executed within this zone. Useful for Angular for example.
  final Zone consumerZone;

  const EventBus._(this._eb, {bool this.autoConvertMessageBodies = false, this.consumerZone});

  /// Starts a new [EventBus] instance.
  /// Returns [Future] which will be called when the event bus becomes ready.
  static Future<EventBus> create(String url, {EventBusJSOptions options, bool autoConvertMessageBodies = false, Zone consumerZone}) {
    Completer<EventBus> out = new Completer();
    EventBusJS impl = new EventBusJS(url, options);
    impl.onopen = allowInterop(() {
      _log.fine("Vertx event bus started");
      out.complete(new EventBus._(impl, autoConvertMessageBodies: autoConvertMessageBodies, consumerZone: consumerZone));
    });

    return out.future;
  }

  /// Applies callback when the event bus connection get closed.
  void onClose(void callback()) {
    _eb.onclose = allowInterop((_) {
      _log.finest("Vertx event bus closed");
      callback();
    });
  }

  /// Close the underlying event bus
  void close() => _eb.close();

  /// Sends an event over the bus to that [address] with this [body] and [headers].
  void send(String address, {Object body, Map<String, String> headers}) {
    _eb.send(address, body, _fromMapToJson(headers), null);
    _log.finest("Vertx event sent to $address");
  }

  /// Sends an event over the bus to that [address] with this [body] and [headers].
  /// A reply will be expected for which the [consumer] get called when was received.
  void sendWithReply(String address, ReplyConsumer consumer, {Object body, Map<String, String> headers}) {
    _eb.send(address, body, _fromMapToJson(headers), allowInterop((MessageFailureJS failure, VertxMessageJS msg) {
      _log.finest("Vertx event received reply on address $address");
      _runReplyWithinZone(
          consumerZone, consumer, new AsyncResult._(failure, new VertxMessage._(msg, autoConvertMessageBodies, consumerZone)));
    }));
    _log.finest("Vertx event sent to $address");
  }

  /// Like [sendWithReply] but with use of async / await instead of a [Consumer]. So the returned [Future] get called when the
  /// reply was received.
  Future<AsyncResult> sendWithReplyAsync(String address, {Object body, Map<String, String> headers}) async {
    Completer<AsyncResult> out = new Completer();

    _eb.send(address, body, _fromMapToJson(headers), allowInterop((MessageFailureJS failure, [VertxMessageJS msg]) {
      _log.finest("Vertx event received reply on address $address");
      _runReplyWithinZone(
          consumerZone, out.complete, new AsyncResult._(failure, new VertxMessage._(msg, autoConvertMessageBodies, consumerZone)));
    }));

    _log.finest("Vertx event sent to $address");
    return out.future;
  }

  /// Like [send] but publishes and no reply possible.
  void publish(String address, {Object body, Map<String, String> headers}) {
    _eb.publish(address, body, _fromMapToJson(headers));
    _log.finest("Vertx event published to $address");
  }

  /// Consumer of messages on a address.
  /// [address] the consumer will receive messages on. [consumer] receive messages.
  ConsumerRegistry consumer(String address, Consumer consumer) {
    _eb.registerHandler(address, allowInterop((VertxMessageJS msg) {
      _runWithinZone(consumerZone, consumer, new VertxMessage._(msg, autoConvertMessageBodies, consumerZone));
    }));
    _log.finest("Vertx consumer registered on $address");
    return new ConsumerRegistry._(consumer, address, _eb);
  }
}

/// Registry of a consumer. Call unregister to remove the consumer for the address
class ConsumerRegistry {
  static final Logger _log = new Logger("ConsumerRegistry");

  final Consumer _consumer;

  final String _address;

  final EventBusJS _eb;

  const ConsumerRegistry._(this._consumer, this._address, this._eb);

  void unregister() {
    _log.finest("Vertx consumer unregistered on $address");
    _eb.unregisterHandler(_address);
  }

  String get address => _address;

  Consumer get consumer => _consumer;
}

/// Possible failure types on event replies
enum FailureType { NO_HANDLERS, RECIPIENT_FAILURE, TIMEOUT }

final Map<String, FailureType> _failureTypes = {
  "NO_HANDLERS": FailureType.NO_HANDLERS,
  "RECIPIENT_FAILURE": FailureType.RECIPIENT_FAILURE,
  "TIMEOUT": FailureType.TIMEOUT
};

/// Result of a an event with reply. In fact the state of returned state of the consumer on server side.
class AsyncResult {
  final VertxMessage message;

  final MessageFailureJS _failure;

  const AsyncResult._(this._failure, this.message);

  /// Return [true] if the event has failed. Only useful on replies.
  bool get failed => _failure != null;

  bool get success => !failed;

  FailureType get failureType => failed ? _failureTypes[_failure.failureType] : null;

  String get failureMessage => failed ? _failure.message : null;

  int get failureCode => failed ? _failure.failureCode : null;
}

/// Message that get delivered to [Consumer]
class VertxMessage {
  static final Logger _log = new Logger("VertxMessage");

  final VertxMessageJS _impl;

  final bool _decode;

  final Zone _consumerZone;

  VertxMessage._(this._impl, this._decode, this._consumerZone);

  /// Sends a reply on this message with that [body] and [headers]. When the [replyConsumer] if present,
  /// then a further reply will be expected.
  void reply({Object body, Map<String, String> headers, ReplyConsumer replyConsumer}) {
    if (expectReply) {
      if (replyConsumer != null) {
        _impl.reply(body, _fromMapToJson(headers), allowInterop((MessageFailureJS failure, VertxMessageJS msg) {
          _runReplyWithinZone(_consumerZone, replyConsumer, new AsyncResult._(failure, new VertxMessage._(msg, _decode, _consumerZone)));
          _log.finest("Vertx reply answer event received for initial on address: $address");
        }));
        _log.finest("Vertx reply event sent as answer on address: $address");
      } else {
        _impl.reply(body, _fromMapToJson(headers), null);
        _log.finest("Vertx reply event sent as answer on address: $address");
      }
    } else {
      throw new EventBusException("Sender of the message on address $address doesn't expect a reply message");
    }
  }

  /// Replies on this message and expect a further reply.
  Future<VertxMessage> replyAsync({Object body, Map<String, String> headers}) {
    if (expectReply) {
      Completer<VertxMessage> completer = new Completer();

      _impl.reply(body, _fromMapToJson(headers), allowInterop((MessageFailureJS failure, VertxMessageJS msg) {
        _runReplyWithinZone(_consumerZone, completer.complete, new AsyncResult._(failure, new VertxMessage._(msg, _decode, _consumerZone)));
        _log.finest("Vertx reply answer event received for initial on address: $address");
      }));

      _log.finest("Vertx reply event sent as answer on address: $address");

      return completer.future;
    } else {
      throw new EventBusException("Sender of the message on address $address doesn't expect a reply message");
    }
  }

  Object get body {
    if (_decode) {
      if (_impl.body != null) {
        try {
          return JSON.decode(_impl.body);
        } catch (e) {
          return _impl.body;
        }
      } else {
        return null;
      }
    } else {
      return _impl.body;
    }
  }

  /// Returns the address of the event
  String get address => _impl.address;

  /// Returns the type of the event
  String get type => _impl.type;

  String getHeader(String key) => getProperty(_impl.headers, key);

  List<String> get headerKeys => getKeys(_impl.headers);

  /// Returns [true] when the event contains a address to reply on. Otherwise [false]
  bool get expectReply => _impl.replyAddress != null && _impl.replyAddress.isNotEmpty;
}

/// Converts a Dart [Map] to javascript object
dynamic _fromMapToJson(Map<String, String> map) {
  if (map != null) {
    return parse(JSON.encode(map));
  } else {
    return null;
  }
}

/// When [zone] is defined, consumer will get guarded executed within that.
void _runReplyWithinZone(Zone zone, ReplyConsumer consumer, AsyncResult result) {
  if (zone != null) {
    zone.runGuarded(() {
      consumer(result);
    });
  } else {
    consumer(result);
  }
}

/// When [zone] is defined, consumer will get guarded executed within that.
void _runWithinZone(Zone zone, Consumer consumer, VertxMessage msg) {
  if (zone != null) {
    zone.runGuarded(() {
      consumer(msg);
    });
  } else {
    consumer(msg);
  }
}