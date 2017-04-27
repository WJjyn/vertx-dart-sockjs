library ch.sourcemotion.vertx;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:logging/logging.dart';
import 'package:vertx_dart_sockjs/src/vertx_eb_impl.dart';

/**
 * General type for all exceptions from the Vert.x Dart abstraction.
 */
class EventBusException implements Exception {
  final String message;

  const EventBusException(this.message);

  @override
  String toString() {
    return 'EventBusException{message: $message}';
  }
}

/**
 * T usually [JsObject] or [String]
 */
typedef void Consumer<VALUE, REPLY>(VertxEventBusMessage<VALUE, REPLY> messageValue);

/**
 * Entry point to the connection API with the Vert.x SockJS event bus bidge: http://vertx.io/docs/vertx-web/java/#_sockjs_event_bus_bridge.
 *
 * Based on SockJS version 0.3.4
 */
class EventBus {
  static final Logger _logger = new Logger("EventBus");

  final EventBusImpl _eb;

  const EventBus._(this._eb);

  /**
     * Starts a new [EventBus] instance.
     *
     * @return [Future] which will be called when the event bus becomes ready.
     */
  static Future<EventBus> create(String url) {
    Completer<EventBus> out = new Completer();
    EventBusImpl impl = new EventBusImpl(url, null);
    impl.onopen = new JsFunction.withThis(new EventbusStateCallback(() {
      out.complete(new EventBus._(impl));
    }));

    return out.future;
  }

  /**
     * Applies callback when the event bus connection get closed.
     */
  void onClose(void callback()) {
    _eb.onclose = new JsFunction.withThis(callback);
  }

  /**
     * Send one way message.
     *
     * @param address The address to message to
     * @param message Main content of the message
     * @param headers Optional headers of the message
     */
  void send(String address, Object message, [Map<String, String> headers]) {
    _eb.send(address, message, _fromMapToObject(headers), null);
  }

  /**
     * Send message with expect reply.
     *
     * @param address The address to message to
     * @param message Main content of the message
     * @param headers Optional headers of the message
     * @param consumer Consumer witch will be receive the reply
     */
  void sendWithReply(String address, Object message, Consumer consumer, [Map<String, String> headers]) {
    _eb.send(address, message, _fromMapToObject(headers), new JsFunction.withThis(new _ReplyConsumerCaller(consumer)));
  }

  /**
     * Same as [sendWithReply] with the possibility to use async / await.
     *
     * @param address The address to message to
     * @param message Main content of the message
     * @param headers Optional headers of the message
     */
  Future<VertxEventBusMessage> sendWithReplyAsync(String address, Object message, [Map<String, String> headers]) async {
    Completer<VertxEventBusMessage> out = new Completer();

    _eb.send(address, message, _fromMapToObject(headers), new JsFunction.withThis(new _ReplyConsumerCaller((VertxEventBusMessage msg) {
      out.complete(msg);
    })));

    return out.future;
  }

  /**
     * Publish message.
     *
     * @param address The address to message to
     * @param message Main content of the message
     * @param headers Optional headers of the message
     */
  void publish(String address, Object message, [Map<String, String> headers]) {
    _eb.publish(address, message, _fromMapToObject(headers));
  }

  /**
     * Consumer of messages on a address.
     *
     * @param address Address the consumer will receive messages on.
     * @param consumer Will receive messages.
     */
  ConsumerRegistry consumer(String address, Consumer consumer) {
    _eb.registerHandler(address, new JsFunction.withThis(new _CommonConsumerCaller(consumer)));
    return new ConsumerRegistry._(consumer, address, _eb);
  }
}

/**
 * Callback when the event bus ready state changes.
 */
class EventbusStateCallback {
  final dynamic realCallback;

  const EventbusStateCallback(this.realCallback);

  void call(JsObject obj) {
    realCallback();
  }
}

/**
 * Registry of a consumer. Call unregister to remove the consumer for the address
 */
class ConsumerRegistry {
  static final Logger _logger = new Logger("ConsumerRegistry");

  final Consumer _consumer;

  final String _address;

  final EventBusImpl _eb;

  const ConsumerRegistry._(this._consumer, this._address, this._eb);

  void unregister() {
    _logger.finest("unregister consumer for address: $address");

    _eb.unregisterHandler(_address);
  }

  String get address => _address;

  Consumer get consumer => _consumer;
}

/**
 * Caller for a consumer of reply messages by javascript.
 */
class _CommonConsumerCaller {
  static final Logger _logger = new Logger("_CommonConsumerCaller");

  final Consumer consumer;

  const _CommonConsumerCaller(this.consumer);

  void call(JsArray arr, JsObject ignored, JsObject message) {
    VertxEventBusMessage vMessage = new VertxEventBusMessage._(message);
    _logger.finest("event received on address: ${message['address']} get delivered to consumer: $consumer");
    consumer(vMessage);
  }
}

/**
 * Caller for a consumer of reply messages by javascript.
 */
class _ReplyConsumerCaller {
  static final Logger _logger = new Logger("_ReplyConsumerCaller");

  final Consumer consumer;

  const _ReplyConsumerCaller(this.consumer);

  void call(Window w, JsObject header, JsObject message) {
    try {
      VertxEventBusMessage vMessage = new VertxEventBusMessage._(message);
      _logger.finest("event with expect reply received on address: ${message['address']} get delivered to consumer");
      consumer(vMessage);
    } catch (e, st) {
      _logger.severe("Could not deliver received event on address: ${message['address']} to consumer", e, st);
    }
  }
}

/**
 * Message, received from the server SockJS event bus bridge.
 *
 * {failureCode: json.failureCode, failureType: json.failureType, message: json.message}
 */
class VertxEventBusMessage<VALUE, REPLY> {
  static const reply_function_property = "reply";

  String _address;
  VALUE _body;
  String _type;
  JsObject _headers;
  JsObject _wireObject;

  VertxEventBusMessage._(JsObject wireObject) {
    _address = wireObject["address"];
    _body = wireObject["body"];
    _type = wireObject["type"];
    _headers = wireObject["headers"];
    _wireObject = wireObject;
  }

  /**
     * Sends a reply to the sender of the incipient event.
     */
  void reply(REPLY reply, Map<String, String> headers) {
    if (expectReply) {
      _wireObject.callMethod(reply_function_property, [reply, _fromMapToObject(headers)]);
    } else {
      throw new EventBusException("Sender of the message on address $address doesn't expect a reply message");
    }
  }

  VALUE get body => _body;

  String get address => _address;

  String get type => _type;

  JsObject get headers => _headers;

  bool get expectReply => _wireObject.hasProperty(reply_function_property);
}

/**
 * Converts a Dart [Map] to a [JsObject]
 */
JsObject _fromMapToObject(Map<String, String> map) {
  if (map != null) {
    return new JsObject.jsify(map);
  } else {
    return null;
  }
}
