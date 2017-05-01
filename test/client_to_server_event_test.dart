@TestOn("browser")
@Timeout(const Duration(seconds: 10))
import 'dart:async';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vertx_dart_sockjs/vertx_eb.dart';

final Logger _logger = new Logger("ClientToServerTest");

final Map<String, String> headers = {"headerName": "headerValue"};

main() async {
  // Logger
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

  EventBus eventBus;

  tearDown(() {
    if (eventBus != null) {
      eventBus.close();
    }
  });

  test("Send test", () async {
    eventBus = await EventBus.create("http://localhost:9000/eventbus");
    eventBus.send("simpleSend", body: 1, headers: headers);
  });

  test("Publish test", () async {
    EventBus eventBus = await EventBus.create("http://localhost:9000/eventbus");
    eventBus.publish("publish", body: 2, headers: headers);
    eventBus.close();
  });

  test("Send with reply test", () async {
    eventBus = await EventBus.create("http://localhost:9000/eventbus", consumerZone: Zone.current);

    final Completer<bool> done = new Completer();

    eventBus.sendWithReply("withReply", (AsyncResult result) {
      _logger.info("reply for withReply received");
      expect(result.failed, isFalse);
      expect(result.success, isTrue);
      expect(result.message, isNotNull);
      VertxMessage msg = result.message;
      expect(msg.body, equals(3));
//      expect(msg.headers, equals(headers));
      _logger.info("checked!!!!!");

      done.complete(true);
    }, body: 3, headers: headers);

    bool successful = await done.future;
    print( 'Send with reply test finished' );
  });

//  test("Send with reply async await test", () async {
//    eventBus = await EventBus.create("http://localhost:9000/eventbus", consumerZone: Zone.current);
//
//    VertxMessage message = await eventBus.sendWithReplyAsync("withReply", body: 3, headers: headers);
//
//    _logger.info("reply for withReply received");
//    expect(message.failed, isFalse);
//    expect(message.success, isTrue);
//    expect(message.body, equals(3));
//    expect(message.headers, equals(headers));
//  });

//  test("Send with reply auto conversion test", () async {
//    EventBus eventBus = await EventBus.create("http://localhost:9000/eventbus", consumerZone: Zone.current, autoConvertMessageBodies: true);
//
//    final Completer<bool> done = new Completer();
//
//    final Map<String, String> body = {"key": 10};
//
//    eventBus.sendWithReply("withReply", (VertxMessage message) {
//      _logger.info("reply for withReply (auto conversion) received");
//
//      expect(message.failed, isFalse);
//      expect(message.success, isTrue);
//      expect(message.body, body);
//      expect(message.headers, equals(headers));
//      done.complete(true);
//    }, body: body, headers: headers);
//
//    await done.future;
//  });
//
//  test("Reply and server fail test", () async {
//    EventBus eventBus = await EventBus.create("http://localhost:9000/eventbus", consumerZone: Zone.current);
//
//    VertxMessage message = await eventBus.sendWithReplyAsync("failing");
//
//    _logger.info("reply for withReply received");
//    expect(message.failed, isTrue);
//    expect(message.success, isFalse);
//    expect(message.failureCode, 1000);
//    expect(message.failureMessage, "failed");
//    expect(message.body, isNull);
//  });
//
//  test("Send with reply 2 times async await", () async {
//    EventBus eventBus = await EventBus.create("http://localhost:9000/eventbus", consumerZone: Zone.current);
//
//    VertxMessage message = await eventBus.sendWithReplyAsync("doubleReply", body: 3, headers: headers);
//    _logger.info("First reply for doubleReply received");
//
//    expect(message.failed, isFalse);
//    expect(message.success, isTrue);
//    expect(message.body, equals(3));
//    expect(message.headers, equals(headers));
//    expect(message.expectReply, isTrue);
//
//    VertxMessage secondMessage = await message.replyAsync(body: message.body, headers: message.headers);
//    _logger.info("Second reply for doubleReply received");
//
//    expect(secondMessage.failed, isFalse);
//    expect(secondMessage.success, isTrue);
//    expect(secondMessage.body, equals(3));
//    expect(secondMessage.headers, equals(headers));
//    expect(secondMessage.expectReply, isTrue);
//  });
}
