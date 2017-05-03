import 'dart:async';
import 'dart:convert';
import 'dart:js';

import 'package:logging/logging.dart';
import 'package:vertx_dart_sockjs/event_bus_codec.dart';
import 'package:vertx_dart_sockjs/event_bus_consumer.dart';
import 'package:vertx_dart_sockjs/event_bus_header.dart';
import 'package:vertx_dart_sockjs/event_bus_message.dart';
import 'package:vertx_dart_sockjs/src/consumer_base.dart';
import 'package:vertx_dart_sockjs/src/vertx_event_bus_base.dart';

export 'src/consumer_base.dart';
export 'src/sockjs_base.dart';
export 'package:vertx_dart_sockjs/event_bus_codec.dart';
export 'package:vertx_dart_sockjs/event_bus_consumer.dart';
export 'package:vertx_dart_sockjs/event_bus_message.dart';
export 'package:vertx_dart_sockjs/event_bus_header.dart';
export 'package:vertx_dart_sockjs/sockjs.dart';

/// Internal, base implementation.
void _DefaultConsumerExecutionDelegate(Function f) {
  f();
}

/// Entry point to the connection API with the Vert.x SockJS event bus bridge:
///
/// http://vertx.io/docs/vertx-web/java/#_sockjs_event_bus_bridge.
///
/// Based on SockJS version 0.3.4
///
/// This facet provides a global flag [autoConvertMessageBodies]. When set to [true], the body of any event (incoming or sent) will get
/// converted. For incoming event this is from the wire [String] to a [Map]. When its activated and an non [String] body is provided for
/// send, it get converted to a [String].
/// This behavior can be overridden also on each send / reply call. When the conversion has failed on send / reply,
/// a [BodyConversionException] will be thrown.
class EventBus {
  static final Logger _log = new Logger("EventBus");

  final EventBusJS _eb;

  /// When given all [Consumer] will get executed within this zone. Useful for Angular for example.
  final ConsumerExecutionDelegate consumerExecDelegate;

  /// Registry for encoders. So the responsible [JsonEncoder] must not get passed with each sent event.
  final EncoderRegistry encoderRegistry = new EncoderRegistry();

  EventBus._(this._eb, {this.consumerExecDelegate = _DefaultConsumerExecutionDelegate});

  /// Starts a new [EventBus] instance.
  /// Returns [Future] which will be called when the event bus becomes ready.
  static Future<EventBus> create(String url,
      {EventBusJSOptions options, bool autoConvertMessageBodies = false, ConsumerExecutionDelegate consumerExecDelegate}) {
    Completer<EventBus> completer = new Completer();
    try {
      // Start event bus
      EventBusJS impl = new EventBusJS(url, options);
      impl.onopen = allowInterop(() {
        _log.fine("Vertx event bus started");
        completer.complete(new EventBus._(impl, consumerExecDelegate: consumerExecDelegate));
      });
    } catch (e, st) {
      completer.completeError(e, st);
    }

    return completer.future;
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
    Object encoded = encodeBody(encoderRegistry, body);

    _eb.send(address, encoded, encodeHeader(headers), null);
    _log.finest("Vertx event sent to $address");
  }

  /// Sends an event over the bus to that [address] with this [body] and [headers].
  /// A reply will be expected for which the [consumer] get called when was received.
  void sendWithReply(String address, Consumer<AsyncResult> consumer,
      {Object body, Map<String, String> headers, EventBusBodyDecoder decoder}) {
    Object encoded = encodeBody(encoderRegistry, body);

    _eb.send(address, encoded, encodeHeader(headers), allowInterop((MessageFailureJS failure, [VertxMessageJS msg]) {
      _log.finest("Vertx event received reply on address $address");
      executeConsumer(consumerExecDelegate, consumer,
          new AsyncResult(failure, failure == null ? new VertxMessage(msg, consumerExecDelegate, encoderRegistry, decoder) : null));
    }));
    _log.finest("Vertx event sent to $address");
  }

  /// Like [sendWithReply] but with use of async / await instead of a [Consumer]. So the returned [Future] get called when the
  /// reply was received.
  Future<AsyncResult> sendWithReplyAsync(String address, {Object body, Map<String, String> headers, EventBusBodyDecoder decoder}) async {
    Completer<AsyncResult> completer = new Completer();

    try {
      sendWithReply(address, completer.complete, body: body, headers: headers, decoder: decoder);
    } catch (e, st) {
      completer.completeError(e, st);
    }
    return completer.future;
  }

  /// Like [send] but publishes and no reply possible.
  void publish(String address, {Object body, Map<String, String> headers}) {
    Object encoded = encodeBody(encoderRegistry, body);

    _eb.publish(address, encoded, encodeHeader(headers));
    _log.finest("Vertx event published to $address");
  }

  /// Consumer of messages on a address.
  /// [address] the consumer will receive messages on. [consumer] receive messages.
  ConsumerRegistry consumer(String address, Consumer<VertxMessage> consumer, {EventBusBodyDecoder decoder}) {
    _eb.registerHandler(address, allowInterop((VertxMessageJS msg) {
      executeConsumer(consumerExecDelegate, consumer, new VertxMessage(msg, consumerExecDelegate, encoderRegistry, decoder));
    }));
    _log.finest("Vertx consumer registered on $address");
    return new ConsumerRegistry(consumer, address, _eb);
  }
}
