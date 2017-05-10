@JS()
library vertx.native;

import 'package:js/js.dart';
import 'package:vertx_dart_sockjs/sockjs.dart';
import 'package:vertx_dart_sockjs/src/sockjs_base.dart';

/// Native handler of event bus errors.
typedef void ErrorHandlerJS(ErrorJS error);

/// Consumer for incoming events
typedef void ConsumerJS(MessageFailureJS failure, VertxMessageJS msg);

/// Handler for incoming reply events
typedef void ReplyHandlerJS(dynamic body, String headers, ConsumerJS replyConsumer);

/// Error with that the [EventBusJS.onerror]
@JS()
@anonymous
class ErrorJS {
  external factory ErrorJS({String type, String body});

  external String get type;
  external String get body;
}

/// Failure state for server site of a sent event
@JS()
@anonymous
class MessageFailureJS {
  external factory MessageFailureJS({int failureCode, String failureType, String message});

  external int get failureCode;
  external String get failureType;
  external String get message;
}

/// Returns the parsed javascript object for that [String]
@JS("JSON.parse")
external dynamic parse(String obj);

/// Returns the [String] representation of the given object.
@JS("JSON.stringify")
external String stringify(dynamic obj);

/// Vertx message received over the event bus
@JS()
@anonymous
class VertxMessageJS {
  external factory VertxMessageJS({String address, dynamic body, String type, dynamic headers, ReplyHandlerJS reply});

  /// Address of this event.
  external String get address;

  /// Address to send replies to
  external String get replyAddress;

  /// Body / Payload of this event
  external dynamic get body;

  /// Message headers
  external dynamic get headers;

  /// Type of this event
  external String get type;

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

/// Possible connection states of the [EventBusJS]
class EventBusState {
  static const int kConnecting = 0;
  static const int kOpen = 1;
  static const int kClosing = 2;
  static const int kClosed = 3;
}

@JS("EventBus")
class EventBusJS {
  /// Constructor
  external factory EventBusJS(String url, EventBusJSOptions options);

  /// Sends an event to the given [address], [body] and [headers]. [body] and [headers] can be null. If the [replyConsumer] is not null,
  /// a reply will be expected.
  external send(String address, dynamic body, dynamic headers, ConsumerJS replyConsumer);

  /// Published an event to the given [address] with the given [body] and [headers]. [body] and [headers] can be null.
  external publish(String address, dynamic body, dynamic headers);

  /// Registers the given [consumer] on the given [address]. The consumer will receive any event on that [address].
  external registerHandler(String address, ConsumerJS consumer);

  /// Unregister all [ConsumerJS] on that [address] of this event bus client instance. So no further event will be received.
  external unregisterHandler(String address);

  /// Set the callback which will get called when the event bus get open and ready
  external set onopen(Function onOpenCallback);

  /// Set the callback which will get called when the event bus got closed.
  external set onclose(Function onCloseCallback);

  /// Set a custom handler that get called when an error has occurred like ""
  external set onerror(ErrorHandlerJS onErrorHandler);

  /// Return get current connection state of the event bus.
  external int get state;

  /// Enables ping on the event bus instance.
  external void pingEnabled(bool enable);

  /// Close this event bus client.
  external void close();
}
