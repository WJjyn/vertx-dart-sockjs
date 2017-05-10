import 'dart:async';
import 'dart:convert';
import 'dart:js';

import 'package:logging/logging.dart';
import 'package:vertx_dart_sockjs/event_bus_codec.dart';
import 'package:vertx_dart_sockjs/event_bus_header.dart';
import 'package:vertx_dart_sockjs/event_bus_message.dart';
import 'package:vertx_dart_sockjs/src/consumer_base.dart';
import 'package:vertx_dart_sockjs/src/sockjs_base.dart';
import 'package:vertx_dart_sockjs/src/vertx_event_bus_base.dart';

export 'package:vertx_dart_sockjs/event_bus_codec.dart';
export 'package:vertx_dart_sockjs/event_bus_header.dart';
export 'package:vertx_dart_sockjs/event_bus_message.dart';
export 'package:vertx_dart_sockjs/sockjs.dart';

export 'src/consumer_base.dart';
export 'src/sockjs_base.dart';

/// Internal, base implementation.
void _DefaultConsumerExecutionDelegate(Function f) {
  f();
}

/// Type of callbacks they called when the event bus gets closed or reopened
typedef EventBusClosedOrReopenedCallback();

/// Errors they can happen on the [EventBus]
enum EventBusError { ACCESS_DENIED, AUTH_ERROR, NOT_LOGGED_IN }

final Map<String, EventBusError> _errorTypes = {
  "access_denied": EventBusError.ACCESS_DENIED,
  "auth_error": EventBusError.AUTH_ERROR,
  "not_logged_in": EventBusError.NOT_LOGGED_IN
};

/// Handler signature that can be registered to get called on [EventBusError] on the event bus.
typedef void ErrorHandler(EventBusError error);

/// JS hide facade specific configuration.
class EventBusOptions {
  static const EventBusOptions _default = const EventBusOptions();

  final bool autoReconnect;

  /// Interval in milliseconds
  final int autoReconnectInterval;

  /// Enable keep alive of connection?
  final bool enablePing;

  final EventBusClosedOrReopenedCallback reopenedCallback;
  final EventBusJSOptions jsOptions;

  const EventBusOptions(
      {this.autoReconnect = true, this.autoReconnectInterval = 5000, this.reopenedCallback, this.jsOptions, this.enablePing = true});
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

  EventBusJS _eb;

  final EventBusOptions options;

  /// When given all [Consumer] will get executed within this zone. Useful for Angular for example.
  final ConsumerExecutionDelegate consumerExecDelegate;

  /// Registry for encoders. So the responsible [JsonEncoder] must not get passed with each sent event.
  final EncoderRegistry encoderRegistry = new EncoderRegistry();

  final _ReconnectHandler _reconnectHandler;

  /// Callback, that will get called when the connection to the server got closed.
  EventBusClosedOrReopenedCallback _onCloseCallback;

  /// Handler of failures on the [EventBus]
  ErrorHandler _errorHandler;

  EventBus._(this._eb, this._reconnectHandler, {this.consumerExecDelegate = _DefaultConsumerExecutionDelegate, this.options});

  /// Starts a new [EventBus] instance.
  /// Returns [Future] which will be called when the event bus becomes ready.
  static Future<EventBus> create(String url,
      {ConsumerExecutionDelegate consumerExecDelegate, EventBusOptions options = EventBusOptions._default}) {
    Completer<EventBus> completer = new Completer();
    try {
      // Start event bus
      EventBusJS impl = new EventBusJS(url, options?.jsOptions);
      impl.onopen = allowInterop(() {
        try {
          // Configure reconnection
          _ReconnectHandler reconnectHandler = null;
          if (options.autoReconnect) {
            reconnectHandler = new _ReconnectHandler(options, url);
          }

          EventBus facade = new EventBus._(impl, reconnectHandler, consumerExecDelegate: consumerExecDelegate, options: options);

          if (options.autoReconnect) {
            reconnectHandler.facade = facade;
          }

          // May enables ping
          impl.pingEnabled(options.enablePing);
          impl.onclose = allowInterop((SimpleEventImpl e) {
            facade._callOnClose();
          });

          _log.finest("Vertx event bus started");
          completer.complete(facade);
        } catch (e) {
          _log.severe("Failed to start Vert.x event bus");
        }
      });
    } catch (e, st) {
      completer.completeError(e, st);
    }

    return completer.future;
  }

  /// That [EventBusClosedOrReopenedCallback] get called when the [EventBus] has lost the connection to the server in any reason.
  void onClose(EventBusClosedOrReopenedCallback callback) {
    _onCloseCallback = callback;
  }

  /// Calls the on close callbacks with the [ConsumerExecutionDelegate]
  void _callOnClose() {
    _log.warning("Vertx event bus closed");
    consumerExecDelegate(() {
      if (_onCloseCallback != null) {
        _onCloseCallback();
      }
      _reconnectHandler?.startToReconnect();
    });
  }

  /// That [ErrorHandler] get called when an event bus error happens.
  void onError(ErrorHandler handler) {
    this._errorHandler = handler;
    _eb.onerror = allowInterop((ErrorJS errorNative) {
      consumerExecDelegate(() {
        handler(_errorTypes[errorNative.body]);
      });
    });
  }

  /// Close the underlying event bus
  void close() => _eb.close();

  /// Sends an event over the bus to that [address] with this [body] and [headers].
  void send(String address, {Object body, Map<String, String> headers}) {
    Object encoded = encodeBody(encoderRegistry, body);
    _eb.send(address, encoded, encodeHeader(headers), null);
  }

  /// Like [send] but publishes and no reply possible.
  void publish(String address, {Object body, Map<String, String> headers}) {
    Object encoded = encodeBody(encoderRegistry, body);
    _eb.publish(address, encoded, encodeHeader(headers));
  }

  /// Sends an event over the bus to that [address] with this [body] and [headers].
  /// A reply will be expected for which the [consumer] get called when was received.
  void sendWithReply(String address, Consumer<AsyncResult> consumer,
      {Object body, Map<String, String> headers, EventBusBodyDecoder decoder}) {
    Object encoded = encodeBody(encoderRegistry, body);

    _eb.send(address, encoded, encodeHeader(headers), allowInterop((MessageFailureJS failure, [VertxMessageJS msg]) {
      try {
        executeConsumer(consumerExecDelegate, consumer,
            new AsyncResult(failure, failure == null ? new VertxMessage(msg, consumerExecDelegate, encoderRegistry, decoder) : null));
      } catch (e, st) {
        _log.severe("Failed to execute reply consumer for event on initial address $address", e, st);
      }
    }));
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

  /// Register a consumer for events on that [address].
  ConsumerReference consumer(String address, Consumer<VertxMessage> consumer, {EventBusBodyDecoder decoder}) {
    ConsumerReference consumerRef = _consumer(address, consumer, decoder: decoder);
    _ConsumerRegistry.instance.addConsumer(consumerRef);
    return consumerRef;
  }

  /// Internal registry delegation to create a consumer and apply him to the [_ConsumerRegistry] in two steps
  ConsumerReference _consumer(String address, Consumer<VertxMessage> consumer, {EventBusBodyDecoder decoder}) {
    _eb.registerHandler(address, allowInterop((dynamic d, VertxMessageJS msg) {
      try {
        executeConsumer(consumerExecDelegate, consumer, new VertxMessage(msg, consumerExecDelegate, encoderRegistry, decoder));
      } catch (e, st) {
        _log.severe("Failed to execute consumer for event on initial address $address", e, st);
      }
    }));
    return new ConsumerReference(consumer, address, this, decoder);
  }

  void _unregisterConsumer(ConsumerReference consumerRef){
    _log.finest("Vertx consumer unregistered on ${consumerRef.address}");
    _eb.unregisterHandler(consumerRef.address);
    _ConsumerRegistry.instance.removeConsumer(consumerRef);
  }

  /// Returns [true] when the [EventBusJS] is connected. Otherwise [false]
  bool get open => _eb?.state == EventBusState.kOpen;
}

/// Delegator for the execution of consumers. This can be helpful to execute consumers within a specific [Zone] or [NgZone] for example.
/// The main use case here is Angular, but for tests this can be helpful too.
///
/// Example:
///
/// class Component implements OnInit {
/// ...
/// NgZone zone;
/// ...
/// EventBus eventBus;
///
/// @override
/// ngOnInit() async {
///   eventBus = await EventBus.create("server_url", consumerExecDelegate: zone.runGuarded);
/// }
///
typedef void ConsumerExecutionDelegate(Function f);

/// Consumer for incipient events of type [VertxMessage] or result events [AsyncResult].
typedef void Consumer<T>(T messageOrResult);

/// Reference for a registered [Consumer]. Provides some information about that [Consumer] and make it possible to unregister it.
class ConsumerReference {
  static final Logger _log = new Logger("ConsumerRegistry");

  final Consumer consumer;

  final String address;

  final EventBus _eb;

  final EventBusBodyDecoder decoder;

  const ConsumerReference(this.consumer, this.address, this._eb, this.decoder);

  /// Unregister this [Consumer] for its address.
  void unregister() {
    _eb._unregisterConsumer(this);
  }
}

/// Simple registry for [Consumer]
class _ConsumerRegistry {
  static final _ConsumerRegistry instance = new _ConsumerRegistry();

  final List<ConsumerReference> consumers = [];

  void addConsumer(ConsumerReference consumerRef) {
    consumers.add(consumerRef);
  }

  void removeConsumer(ConsumerReference consumerRef) {
    consumers.remove(consumerRef);
  }
}

/// Handler to reconnect automatically after a connection lost.
/// When a [EventBusClosedOrReopenedCallback] was defined in the [EventBusOptions], then he will get called when the
/// connection is established again.
class _ReconnectHandler {
  static final Logger _log = new Logger("_ReconnectHandler");

  final EventBusOptions options;

  EventBus facade;

  final String url;

  Timer reconnectTimer;

  _ReconnectHandler(this.options, this.url);

  /// Starts to try to establish a [SockJSImpl] connection.
  startToReconnect() async {
    // Avoid multiple parallel executions
    if (reconnectTimer == null) {
      _log.info("Start reconnect to $url");
      // Close existing SockJS channel properly
      facade._eb.close();

      reconnectTimer = new Timer.periodic(new Duration(milliseconds: options.autoReconnectInterval), (Timer timer) async {
        EventBusJS reconnected = await tryToReconnect();
        if (reconnected != null) {
          // first ... stop the timer
          timer.cancel();
          if (facade == null) {
            _log.warning("Event bus not reachable. Cannot finish reconnection tasks.");
            reconnectTimer = null;
          } else {
            doAfterReconnectTasks(reconnected);
          }
        }
      });
    }
  }

  /// Any tasks they must be done after connection is established again.
  void doAfterReconnectTasks(EventBusJS reconnected) {
    _log.info("Reconnected. Start establish previous state");
    try {
      // Reset the JS reference
      facade._eb = reconnected;

      // May enables ping
      reconnected.pingEnabled(options.enablePing);

      // Reset the on close handler
      reconnected.onclose = allowInterop((SimpleEventImpl e) {
        facade._callOnClose();
      });

      // Reattach on close callback
      if (facade._onCloseCallback != null) {
        _log.fine("Reattach close callback");
        facade.onClose(facade._onCloseCallback);
      }
      // Reattach on error callback
      if (facade._errorHandler != null) {
        _log.fine("Reattach error handler");
        facade.onError(facade._errorHandler);
      }

      // Reattach any previous consumers
      _ConsumerRegistry.instance.consumers.forEach((ConsumerReference consumerRef) {
        _log.fine("Reregister consumer on address: ${consumerRef.address}");
        facade._consumer(consumerRef.address, consumerRef.consumer);
      });

      // Finally call reopened connection callback
      if (options.reopenedCallback != null) {
        options.reopenedCallback();
      }
    } catch (e, st) {
      _log.severe("Error during reattach handlers and consumers. Reconnecting not possible", e, st);
    }finally{
      reconnectTimer = null;
    }
  }

  /// Single reconnection try
  Future<EventBusJS> tryToReconnect() async {
    Completer<EventBusJS> completer = new Completer();

    try {
      EventBusJS newEbConnection = new EventBusJS(url, options.jsOptions);
      newEbConnection.onopen = allowInterop(() {
        // Ensure is open event
        completer.complete(newEbConnection);
      });

      // Finish the completer anyway
      newEbConnection.onclose = allowInterop((SimpleEventImpl e) {
        _log.fine("reconnect try failed");
        completer.complete();
      });
    } catch (e, st) {
      _log.fine("Error during reconnect", e, st);
    }

    return completer.future;
  }
}
