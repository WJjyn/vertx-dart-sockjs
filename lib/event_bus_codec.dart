import 'dart:convert';

import 'package:logging/logging.dart';

final Logger _log = new Logger("Codec");

/// Thrown on codec failure. At this moment in fact only when [encodeBody] has failed. Because the javascript event bus
/// lib RECIPIENT_FAILURE from client.
class CodecException implements Exception {
  final String message;

  CodecException(this.message);

  @override
  String toString() {
    return 'CodecException{message: $message}';
  }
}

/// Decoder for bodies of event messages. Is a typedef to provide the best flexibility for decoder / encoder designs.
typedef T EventBusBodyDecoder<T>(Object body);

/// Encoder for bodies of event messages. Is a typedef to provide the best flexibility for decoder / encoder designs.
typedef Object EventBusBodyEncoder<T>(T dto);

/// Registry for [EventBusBodyEncoder]. Encoders can be registered by [Type], so they can be used against there [Type].
class EncoderRegistry {
  final Map<Type, EventBusBodyEncoder> _encoderByType = {};

  operator [](Type type) => _encoderByType[type];

  operator []=(Type type, EventBusBodyEncoder encoder) => _encoderByType[type] = encoder;

  EventBusBodyEncoder removeEncoder(Type type) => _encoderByType.remove(type);

  bool hasEncoderFor(Type type) => _encoderByType.containsKey(type);
}

final JsonCodec _jsonCodec = new JsonCodec();

final EventBusBodyDecoder _defaultDecoder = (Object o) {
  if (o == null) {
    return null;
  }
  if (o is num || o is bool) {
    return o;
  }
  // Presave String as type for much cases as possible
  if (o is String) {
    if (int.parse(o, onError: (_) => null) != null || double.parse(o, (_) => null) != null || (o == "true" || o == "false")) {
      return o;
    }
  }
  // Last stand is json decoder
  try {
    return _jsonCodec.decoder.convert(o);
  } catch (e) {
    _log.finest("Last stage on decoder (json) failed. Returns raw string");
    return o;
  }
};

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
/// [JSON.decoder] will be used.
Object decodeBody<T>(EventBusBodyDecoder<T> decoder, Object body) {
  if (body != null) {
    // Take default decoder when no defined
    EventBusBodyDecoder dec = decoder ?? _defaultDecoder;
    try {
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

/// Encodes and returns that body object with that [Converter<Object, String>].
/// If the user has not registered an [EventBusBodyEncoder] for that type, [JSON.encoder] will be used.
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
