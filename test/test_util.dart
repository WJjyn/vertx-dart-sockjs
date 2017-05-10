import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:quiver/core.dart';
import 'package:vertx_dart_sockjs/vertx_event_bus.dart';

/// Configures [Logger] for tests
void startLogger() {
  Logger.root.level = Level.ALL;
  recordStackTraceAtLevel = Level.SEVERE;
  Logger.root.onRecord.listen((LogRecord rec) {
    if (rec.stackTrace == null) {
      print('${rec.level.name} -> ${rec.loggerName}: ${rec.message}');
    } else {
      print('${rec.level.name} -> ${rec.loggerName}: ${rec.message} | ${rec.error}');
      print("${rec.stackTrace}");
    }
  });
}

EventBusBodyEncoder<TestDto> testDtoEncoder = (TestDto o) {
  return o.toJson();
};

EventBusBodyDecoder<TestDto> testDtoDecoder = (Object o) {
  return new TestDto.fromJson(o.toString());
};

class TestDto {
  final String string;
  final int integer;

  TestDto(this.string, this.integer);

  factory TestDto.fromJson(String json) {
    Map<String, Object> asMap = JSON.decode(json);
    return new TestDto(asMap["string"], asMap["integer"]);
  }

  String toJson() {
    Map<String, Object> asMap = {};
    asMap["string"] = string;
    asMap["integer"] = integer;

    return JSON.encode(asMap);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TestDto && runtimeType == other.runtimeType && string == other.string && integer == other.integer;

  @override
  int get hashCode => hash2(string, integer);

  @override
  String toString() {
    return '{"string": "$string", "integer": $integer}';
  }
}

class MoreComplexTestDtoCodec {
  static MoreComplexTestDto decoder(Object o) => new MoreComplexTestDto.fromJson(o.toString());

  static Object encoder(MoreComplexTestDto dto) => dto.toJson();
}

class MoreComplexTestDto {
  final int integer;
  final String integerString;
  final String string;
  final double doubleValue;
  final String doubleString;
  final bool boolean;
  final String booleanString;
  final NotComplexTestDto obj;

  MoreComplexTestDto(
      this.integer, this.integerString, this.string, this.doubleValue, this.doubleString, this.boolean, this.booleanString, this.obj);

  factory MoreComplexTestDto.fromJson(String json) {
    Map<String, Object> asMap = JSON.decode(json);
    return new MoreComplexTestDto(asMap["integer"], asMap["integerString"], asMap["string"], asMap["doubleValue"], asMap["doubleString"],
        asMap["boolean"], asMap["booleanString"], asMap["obj"] != null ? new NotComplexTestDto() : null);
  }

  String toJson() {
    Map<String, Object> asMap = {}
      ..["integer"] = integer
      ..["integerString"] = integerString
      ..["string"] = string
      ..["doubleValue"] = doubleValue
      ..["doubleString"] = doubleString
      ..["boolean"] = boolean
      ..["booleanString"] = booleanString
      ..["obj"] = obj != null ? {} : null;

    return JSON.encode(asMap);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoreComplexTestDto &&
          runtimeType == other.runtimeType &&
          integer == other.integer &&
          integerString == other.integerString &&
          string == other.string &&
          doubleValue == other.doubleValue &&
          doubleString == other.doubleString &&
          boolean == other.boolean &&
          booleanString == other.booleanString &&
          obj != null &&
          other.obj != null;

  @override
  int get hashCode => hashObjects([integer, integerString, string, doubleValue, doubleString, boolean, boolean]);
}

class NotComplexTestDto {}

/// Control for tests with multiple async stages.
class TestControl {
  final Completer completer = new Completer();

  final int expectVisits;

  int visits = 0;

  TestControl(this.expectVisits);

  visited() {
    if (++visits >= expectVisits) {
      completer.complete();
    }
  }

  Future waitUntilDone() => completer.future;
}
