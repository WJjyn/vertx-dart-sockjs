import 'dart:async';
import 'dart:js';

import 'package:logging/logging.dart';
import 'package:vertx_dart_sockjs/event_bus_codec.dart';
import 'package:vertx_dart_sockjs/event_bus_header.dart';
import 'package:vertx_dart_sockjs/src/consumer_base.dart';
import 'package:vertx_dart_sockjs/src/vertx_event_bus_base.dart';
import 'package:vertx_dart_sockjs/vertx_event_bus.dart';

/// Exception which get thrown when the user tries to reply on a message, that not expect a reply.
class NoReplyExpectException implements Exception {
  final String message;

  const NoReplyExpectException(this.message);

  @override
  String toString() {
    return 'EventBusException{message: $message}';
  }
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

  const AsyncResult(this._failure, this.message);

  /// Return [true] if the event has failed. Only useful on replies.
  bool get failed => _failure != null;

  bool get success => !failed;

  FailureType get failureType => failed ? _failureTypes[_failure.failureType] : null;

  String get failureMessage => failed ? _failure.message : null;

  int get failureCode => failed ? _failure.failureCode : null;
}

/// Message facet over the original javascript message for conversion tasks and other benefits.
class VertxMessage<T> {
  static final Logger _log = new Logger("VertxMessage");

  final VertxMessageJS _impl;

  final ConsumerExecutionDelegate _consumerExecDelegate;

  final T body;

  final EncoderRegistry _encoderRegistry;

  Map<String, String> _headers;

  VertxMessage(this._impl, this._consumerExecDelegate, this._encoderRegistry, EventBusBodyDecoder decoder)
      : body = decodeBody(decoder, _impl?.body);

  /// Sends a reply on this message with that [body] and [headers]. When the [consumer] if present,
  /// then a further reply will be expected.
  void reply({Object body, Map<String, String> headers, Consumer<AsyncResult> consumer, EventBusBodyDecoder decoder}) {
    if (expectReply) {
      Object encoded = encodeBody(_encoderRegistry, body);

      if (consumer != null) {
        _impl.reply(encoded, encodeHeader(headers), allowInterop((MessageFailureJS failure, [VertxMessageJS msg]) {
          try {
            executeConsumer(_consumerExecDelegate, consumer,
                new AsyncResult(failure, failure == null ? new VertxMessage(msg, _consumerExecDelegate, _encoderRegistry, decoder) : null));
          } catch (e, st) {
            _log.severe("Failed to execute reply consumer for event on initial address ${_impl?.address}", e, st);
          }
          _log.finest("Vertx reply answer event received for initial on address: $address");
        }));
        _log.finest("Vertx reply event sent as answer on address: $address");
      } else {
        _impl.reply(encoded, encodeHeader(headers), null);
        _log.finest("Vertx reply event sent as answer on address: $address");
      }
    } else {
      throw new NoReplyExpectException("Sender of the message on address $address doesn't expect a reply message");
    }
  }

  /// Like [reply] but with async / await.
  Future<AsyncResult> replyAsync({Object body, Map<String, String> headers, EventBusBodyDecoder decoder}) {
    Completer<AsyncResult> completer = new Completer();

    try {
      reply(body: body, headers: headers, consumer: completer.complete, decoder: decoder);
    } catch (e, st) {
      completer.completeError(e, st);
    }

    return completer.future;
  }

  /// Returns the address of the event
  String get address => _impl.address;

  /// Returns the type of the event
  String get type => _impl.type;

  /// Convert headers only on demand for performance.
  Map<String, String> get headers {
    if (_headers == null) {
      _headers = decodeHeader(_impl.headers);
    }
    return _headers != null ? new Map.unmodifiable(_headers) : null;
  }

  /// Returns [true] when the event contains a address to reply on. Otherwise [false]
  bool get expectReply => _impl.replyAddress != null && _impl.replyAddress.isNotEmpty;
}
