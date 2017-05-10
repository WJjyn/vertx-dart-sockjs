@TestOn("browser || phantomjs")
@Timeout(const Duration(seconds: 10))
import 'dart:async';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vertx_dart_sockjs/vertx_event_bus.dart';

import 'test_util.dart';

final Logger _log = new Logger("ClientToServerTest");

final Map<String, String> headers = {"headerName": "headerValue"};

const eventbusAddress = "http://localhost:9000/eventbus";

main() async {
  startLogger();

  EventBus eventBus;

  tearDown(() {
    if (eventBus != null) {
      eventBus.close();
      eventBus = null;
      _log.info("Event bus closed");
    }
  });

  test("Test send", () async {
    try {
      eventBus = await EventBus.create(eventbusAddress);
      eventBus.send("simpleSend", body: 1, headers: headers);
    } catch (e, st) {
      _log.severe("Failed to send", e, st);
      fail("send failed");
    }
  });

  test("Test publish", () async {
    try {
      eventBus = await EventBus.create(eventbusAddress);
      eventBus.publish("publish", body: 2, headers: headers);
    } catch (e, st) {
      _log.severe("Failed to publish", e, st);
      fail("publish failed");
    }
  });

  test("Test send with reply", () async {
    eventBus = await EventBus.create(eventbusAddress, consumerExecDelegate: Zone.current.runGuarded);

    final Completer<bool> done = new Completer();

    eventBus.sendWithReply("withReply", (AsyncResult result) {
      _log.info("reply for withReply received");
      expect(result.failed, isFalse);
      expect(result.success, isTrue);
      expect(result.message, isNotNull);
      VertxMessage msg = result.message;
      expect(msg.body, equals(3));
      expect(msg.headers, equals(headers));

      done.complete(true);
    }, body: 3, headers: headers);

    await done.future;
    _log.info('Send with reply test finished');
  });

  test("Test send with reply async await", () async {
    final Completer<bool> done = new Completer();
    eventBus = await EventBus.create(eventbusAddress, consumerExecDelegate: Zone.current.runGuarded);
    AsyncResult result = await eventBus.sendWithReplyAsync("withReply", body: 3, headers: headers);

    _log.info("reply for withReply received");
    expect(result.failed, isFalse);
    expect(result.success, isTrue);
    VertxMessage msg = result.message;
    expect(msg.body, equals(3));
    expect(msg.headers, equals(headers));

    done.complete(true);

    await done.future;
  });

  test("Test send with reply custom decoder / encoder", () async {
    EventBus eventBus = await EventBus.create(eventbusAddress, consumerExecDelegate: Zone.current.runGuarded);
    eventBus.encoderRegistry[TestDto] = testDtoEncoder;

    final Completer<bool> done = new Completer();

    final TestDto start = new TestDto("value", 10000);

    AsyncResult result = await eventBus.sendWithReplyAsync("withReply", body: start, headers: headers, decoder: testDtoDecoder);

    expect(result.failed, isFalse);
    expect(result.success, isTrue);
    VertxMessage msg = result.message;
    expect(msg.body, equals(start));
    expect(msg.headers, equals(headers));

    done.complete(null);

    await done.future;
  });

  test("Test reply and server fail", () async {
    final Completer<bool> done = new Completer();

    EventBus eventBus = await EventBus.create(eventbusAddress, consumerExecDelegate: Zone.current.runGuarded);

    AsyncResult result = await eventBus.sendWithReplyAsync("failing");

    _log.info("reply for withReply received");
    expect(result.failed, isTrue);
    expect(result.success, isFalse);
    expect(result.failureCode, 1000);
    expect(result.failureType, FailureType.RECIPIENT_FAILURE);
    expect(result.failureMessage, "failed");
    expect(result.message, isNull);

    done.complete(null);

    await done.future;
  });

  test("Send with reply 2 times async await", () async {
    final Completer<bool> done = new Completer();

    EventBus eventBus = await EventBus.create(eventbusAddress, consumerExecDelegate: Zone.current.runGuarded);

    AsyncResult result = await eventBus.sendWithReplyAsync("doubleReply", body: 3, headers: headers);
    _log.info("First reply for doubleReply received");

    expect(result.failed, isFalse);
    expect(result.success, isTrue);
    expect(result.message, isNotNull);
    VertxMessage message = result.message;
    expect(message.body, equals(3));
    expect(message.headers, equals(headers));
    expect(message.expectReply, isTrue);

    AsyncResult secondResult = await message.replyAsync(body: message.body, headers: message.headers);
    _log.info("Second reply for doubleReply received");

    expect(secondResult.failed, isFalse);
    expect(secondResult.success, isTrue);
    expect(secondResult.message, isNotNull);
    VertxMessage secondMessage = secondResult.message;
    expect(secondMessage.body, equals(3));
    expect(secondMessage.headers, equals(headers));
    expect(secondMessage.expectReply, isFalse);

    done.complete(null);

    await done.future;
  });

  test("Test send with reply more complex dto", () async {
    EventBus eventBus = await EventBus.create(eventbusAddress, consumerExecDelegate: Zone.current.runGuarded);
    eventBus.encoderRegistry[MoreComplexTestDto] = MoreComplexTestDtoCodec.encoder;

    final Completer<bool> done = new Completer();

    MoreComplexTestDto dto = new MoreComplexTestDto(100, "100", "value", 100.1, "100.1", true, "true", new NotComplexTestDto());

    AsyncResult result =
        await eventBus.sendWithReplyAsync("complexDto", body: dto, headers: headers, decoder: MoreComplexTestDtoCodec.decoder);

    expect(result.failed, isFalse);
    expect(result.success, isTrue);
    VertxMessage msg = result.message;
    expect(msg.body, equals(dto));
    expect(msg.headers, equals(headers));

    done.complete(null);

    await done.future;
  });
}