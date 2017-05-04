import 'dart:convert';

import 'dart:js';
import 'package:logging/logging.dart';
import 'package:vertx_dart_sockjs/src/vertx_event_bus_base.dart';

final Logger _log = new Logger("Codec");

/// Thrown on codec failures.
class CodecException implements Exception {
  final String message;

  CodecException(this.message);

  @override
  String toString() {
    return 'CodecException{message: $message}';
  }
}

/// Decoder for bodies of event messages. Is a typedef to provide the best flexibility for decoder / encoder designs.
typedef T EventBusBodyDecoder<T>(dynamic body);

/// Encoder for bodies of event messages. Is a typedef to provide the best flexibility for decoder / encoder designs.
typedef dynamic EventBusBodyEncoder<T>(T dto);

/// Registry for [EventBusBodyEncoder]. Encoders can be registered by [Type], so they can be used against there [Type].
class EncoderRegistry {
  final Map<Type, EventBusBodyEncoder> _encoderByType = {};

  operator [](Type type) => _encoderByType[type];

  operator []=(Type type, EventBusBodyEncoder encoder) => _encoderByType[type] = encoder;

  EventBusBodyEncoder removeEncoder(Type type) => _encoderByType.remove(type);

  bool hasEncoderFor(Type type) => _encoderByType.containsKey(type);
}

final JsonCodec _jsonCodec = new JsonCodec();

/// Returns true when the given body is a [String] but it may get converted byte json parsing.
bool shouldStayAsString(dynamic body) =>
    body != null && body is String && (num.parse(body, (_) => null) != null || (body == "true" || body == "false"));

/// Returns [true] when that [body] needs to get stringified. Means cannot proceed directly by type or json parser.
bool needStringify(dynamic body) => body != null && !(body is num || body is String || body is bool);

/// Default [EventBusBodyDecoder], when the user not provides it's own.
/// - Presaves (int, bool) for numeric and bool types
/// - Presaves (String) for string representation of numeric or bool values
/// - For any other value it will be tried to get "jsonify", when that failes the raw value will be delivered to [Consumer].
final EventBusBodyDecoder _defaultDecoder = (dynamic o) {
  if (o == null) {
    return null;
  }
  if (o is num || o is bool) {
    return o;
  }
  // Presave String as type for much cases as possible
  if (shouldStayAsString(o)) {
    return o;
  }
  // Last stand is json decoder
  try {
    return _jsonCodec.decoder.convert(o);
  } catch (e) {
    _log.finest("Last stage on decoder (json) failed. Returns raw string");
    return o;
  }
};

/// Default [EventBusBodyEncoder], when the user not provides it's own.
/// - Presaves (int, bool) for numeric and bool types
/// - Presaves (String) for string representation of numeric or bool values
/// - String values will pass the event bus 1 to 1
/// - For any other value it will be tried to get "jsonify", when that failes the raw value will be delivered to the event bus.
final EventBusBodyEncoder _defaultEncoder = (Object o) {
  if (o == null) {
    return null;
  } else if (o is num || o is bool) {
    return o;
  }
  // Presave String as type for much cases as possible
  else if (o is String) {
    return o;
  } else {
    // Last stand is json encoder
    try {
      return _jsonCodec.encoder.convert(o);
    } catch (e) {
      _log.finest("Last stage on decoder (json) failed. Returns raw string");
      return o;
    }
  }
};

/// Decodes and returns that body decoded with the given [EventBusBodyDecoder]. If the user not provides its own [EventBusBodyDecoder],
/// [_defaultDecoder] will be used.
Object decodeBody<T>(EventBusBodyDecoder<T> decoder, dynamic body) {
  if (body != null) {
    // Take default decoder when no defined
    EventBusBodyDecoder dec = decoder ?? _defaultDecoder;
    try {
      // Json object in this case ... string representation
      if (needStringify(body)) {
        body = stringify(body);
      }
      return dec(body);
    } catch (e, st) {
      String message = "Failed to decode body: $body of type ${body?.runtimeType} with decoder: ${dec}.";
      _log.severe(message, e, st);
      // Just for messaging
      throw new CodecException(message);
    }
  } else {
    return null;
  }
}

/// Encodes and returns that body object with that [EventBusBodyEncoder].
/// If the user has not registered an [EventBusBodyEncoder] for that type, [_defaultEncoder] will be used.
Object encodeBody<T>(EncoderRegistry encoderReg, T body) {
  if (body != null) {
    // Take default encoder when no defined
    EventBusBodyEncoder encoder = encoderReg[body.runtimeType] ?? _defaultEncoder;
    try {
      return encoder(body);
    } catch (e, st) {
      String message = "Failed to encode body: ${body?.runtimeType} with decoder: ${encoder}";
      _log.severe(message, e, st);
      // Just for messaging
      throw new CodecException(message);
    }
  } else {
    return null;
  }
}
