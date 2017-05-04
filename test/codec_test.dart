@TestOn("browser || phantomjs")
@Timeout(const Duration(seconds: 10))
@Tags(const ["client_only"])
import 'dart:convert';

import 'package:quiver/core.dart';
import 'package:test/test.dart';

import 'package:vertx_dart_sockjs/vertx_event_bus.dart';
import 'test_util.dart';

void main() {
  startLogger();

  test("Test for EncoderRegistry", () {
    final EncoderRegistry encoderRegistry = new EncoderRegistry();

    expect(encoderRegistry.hasEncoderFor(TestDto), isFalse);

    encoderRegistry[TestDto] = TestDtoEncoder;

    expect(encoderRegistry.hasEncoderFor(TestDto), isTrue);
    expect(encoderRegistry[TestDto], isNotNull);

    encoderRegistry.removeEncoder(TestDto);

    expect(encoderRegistry.hasEncoderFor(TestDto), isFalse);
  });

  test("Test for EventBusBodyDecoder and EventBusBodyEncoder", () {
    EventBusBodyEncoder encoder = TestDtoEncoder;
    EventBusBodyDecoder decoder = TestDtoDecoder;

    TestDto start = new TestDto("string", 100);
    String wire = encoder(start);
    TestDto end = decoder(wire);

    expect(end, equals(start));
  });

  test("Test for encodeBody", () {
    final EncoderRegistry encoderRegistry = new EncoderRegistry();
    final String expected = '{"string":"string","integer":1000}';

    encoderRegistry[TestDto] = TestDtoEncoder;

    Object encoded = encodeBody(encoderRegistry, new TestDto("string", 1000)).toString().trim();
    expect(encoded, equals(expected));

    encoderRegistry.removeEncoder(TestDto);

    // Test auto Json
    String encodedMap = encodeBody(
            encoderRegistry,
            (new Map()
              ..["string"] = "string"
              ..["integer"] = 1000))
        .toString()
        .trim();
    expect(encodedMap, equals(expected));

    // Negative test with failing encoder
    encoderRegistry[TestDto] = FailingTestDtoEncoder;

    try {
      encodeBody(encoderRegistry, new TestDto("string", 1000)).toString().trim();
      fail("Encoder should fail");
    } catch (e) {
      expect(e, new isInstanceOf<CodecException>());
    }
  });

  test("Test for decodeBody", () {
    TestDto expected = new TestDto("string", 1000);

    String encoded = TestDtoEncoder(expected);

    TestDto resultConcrete = decodeBody(TestDtoDecoder, encoded);
    expect(resultConcrete, equals(expected));

    // Test auto json

    Map<String, Object> asMap = decodeBody(null, encoded);
    expect(asMap["string"], equals(expected.string));
    expect(asMap["integer"], equals(expected.integer));

    // Negativ test with failing decoder

    try {
      decodeBody(FailingTestDtoDecoder, encoded);
      fail("Decoder should fail");
    } catch (e) {
      expect(e, new isInstanceOf<CodecException>());
    }
  });

  test("Test for decodeBody simple type and default decoder", () {
    int integer = 1;
    Object decodedInt = decodeBody(null, integer);
    expect(decodedInt, equals(integer));

    bool boolean = true;
    Object decodedBool = decodeBody(null, boolean);
    expect(decodedBool, equals(boolean));

    // int value as string
    String string = "1";
    Object decodedString = decodeBody(null, string);
    expect(decodedString, equals(string));

    // double value as string
    string = "1.1";
    decodedString = decodeBody(null, string);
    expect(decodedString, equals(string));

    // Boolean value as string
    string = "true";
    decodedString = decodeBody(null, string);
    expect(decodedString, equals(string));

    // Non json string
    string = "abc";
    decodedString = decodeBody(null, string);
    expect(decodedString, equals(string));

    // Last stand should be JSON conversion
    string = '{}';
    decodedString = decodeBody(null, string);
    expect(decodedString, new isInstanceOf<Map>());
  });

  test("Test for encodeBody of simple types", () {
    EncoderRegistry reg = new EncoderRegistry();

    int i = 1;
    Object encoded = encodeBody(reg, i);
    expect(encoded, equals(i));

    double d = 1.1;
    encoded = encodeBody(reg, d);
    expect(encoded, equals(d));

    bool b = true;
    encoded = encodeBody(reg, b);
    expect(encoded, equals(b));

    String string = "true";
    encoded = encodeBody(reg, string);
    expect(encoded, equals(string));

    string = "1";
    encoded = encodeBody(reg, string);
    expect(encoded, equals(string));

    string = "1.1";
    encoded = encodeBody(reg, string);
    expect(encoded, equals(string));

    string = "{}";
    encoded = encodeBody(reg, string);
    expect(encoded, equals(string));
  });
}

TestDto TestDtoDecoder(String input) {
  Map<String, Object> map = JSON.decode(input);
  return new TestDto(map["string"], map["integer"]);
}

TestDto FailingTestDtoDecoder(String input) {
  throw "Failed";
}

String TestDtoEncoder(TestDto input) {
  return '{"string":"${input.string}","integer":${input.integer}}';
}

String FailingTestDtoEncoder(TestDto input) {
  throw "Failed";
}

class TestDto {
  final String string;
  final int integer;

  const TestDto(this.string, this.integer);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TestDto && runtimeType == other.runtimeType && string == other.string && integer == other.integer;

  @override
  int get hashCode => hash2(string, integer);
}
