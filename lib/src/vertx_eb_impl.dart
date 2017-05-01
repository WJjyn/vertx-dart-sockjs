@JS()
library vertx.native;

import 'dart:js';

import 'package:js/js.dart';
import 'package:vertx_dart_sockjs/sockjs.dart';

typedef void ReplyConsumerJS(MessageFailureJS failure, VertxMessageJS msg);

typedef void ConsumerJS(VertxMessageJS msg);

typedef void ReplyHandlerJS(Object body, String headers, ReplyConsumerJS replyConsumer);


/// Failure state for server site of a sent event
@JS()
@anonymous
class MessageFailureJS {
  external factory MessageFailureJS({int failureCode, String failureType, String message});

  external int get failureCode;
  external String get failureType;
  external String get message;
}

@JS('Object.keys')
external List<String> getKeys(jsObject);

@JS("JSON.parse")
external dynamic parse(String obj);


/// Vertx message received over the event bus
@JS()
@anonymous
class VertxMessageJS {
  external factory VertxMessageJS({String address, String body, String type, JSObject headers, ReplyHandlerJS reply});

  /// Address of this event.
  external String get address;

  /// Address to send replies to
  external String get replyAddress;

  /// Body / Payload of this event
  external String get body;

  external JSObject get headers;

  /// Type of this event
  external String get type;

  /// Enables ping on the event bus instance.
  external void pingEnabled(bool enable);

  /// Handler to reply on this event. This handler is only present if the sender of this event expect a reply.
  external ReplyHandlerJS get reply;
}

/// Configuration for [EventBusJS] and the underlay [SockJS]
@JS()
@anonymous
class EventBusJSOptions extends SockJSOptions {
  @JS("vertxbus_ping_interval")
  external int get pingInterval;

  external factory EventBusJSOptions({bool debug, bool devel, List<String> protocols_whitelist, int pingInterval});
}

@JS("EventBus")
class EventBusJS {
  /// Constructor
  external factory EventBusJS(String url, EventBusJSOptions options);

  /// Sends an event to the given [address], [body] and [headers]. [body] and [headers] can be null. If the [replyConsumer] is not null,
  /// a reply will be expected.
  external send(String address, Object body, dynamic headers, ReplyConsumerJS replyConsumer);

  /// Published an event to the given [address] with the given [body] and [headers]. [body] and [headers] can be null.
  external publish(String address, Object body, String headers);

  /// Registers the given [consumer] on the given [address]. The consumer will receive any event on that [address].
  external registerHandler(String address, ConsumerJS consumer);

  /// Unregister all [ConsumerJS] on that [address] of this event bus client instance. So no further event will be received.
  external unregisterHandler(String address);

  /// Set the callback which will get called when the event bus get open and ready
  external set onopen(Function onOpenCallback);

  /// Set the callback which will get called when the event bus got closed.
  external set onclose(Function onCloseCallback);

  /// Close this event bus client.
  external void close();
}
