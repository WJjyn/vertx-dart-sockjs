import 'dart:convert';

import 'package:vertx_dart_sockjs/src/vertx_event_bus_base.dart';

/// Converts a javascript object into a Dart [Map]. This way is needed because Dart JS interopt not provides support for
/// [Map] <-> javascript objects at the moment.
Map<String, String> decodeHeader(dynamic obj) {
  if (obj != null) {
    return JSON.decode(stringify(obj));
  } else {
    return null;
  }
}

/// Converts a Dart [Map] to javascript object. This way is needed because Dart JS interopt not provides support for
/// [Map] <-> javascript objects at the moment.
dynamic encodeHeader(Map<String, String> map) {
  if (map != null) {
    return parse(JSON.encode(map));
  } else {
    return null;
  }
}
