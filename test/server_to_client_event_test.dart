import 'dart:async';

@TestOn("browser || phantomjs")
@Timeout(const Duration(seconds: 10))
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vertx_dart_sockjs/vertx_event_bus.dart';

import 'test_util.dart';

final Logger _log = new Logger("ServerToClientTest");

main() async {
  EventBus eventBus;

  setUp(() async {
    startLogger();

    _log.info("try to connect to server");
    eventBus = await EventBus.create("http://localhost:9000/eventbus", consumerExecDelegate: Zone.current.runGuarded);
    _log.info("connected to server");
  });

  test("Server motivated event test", () async {
    TestControl control = new TestControl(12);

    eventBus.consumer("simpleSend", (VertxMessage msg) {
      _log.info("Event on address simpleSendConsumer received");

      expect(msg.body, 1);
      expect(msg.headers["headerName"], "headerValue");

      control.visited();
    });

    _log.info("simpleSendConsumer registered");

    eventBus.consumer("string", (VertxMessage<int> msg) {
      _log.info("string received");
      expect(msg.body, "string");
      control.visited();
    });

    eventBus.consumer("integer", (VertxMessage<int> msg) {
      _log.info("integer received");
      expect(msg.body, 1);
      control.visited();
    });

    eventBus.consumer("integerString", (VertxMessage<int> msg) {
      _log.info("integerString received");
      expect(msg.body, "1");
      control.visited();
    });

    eventBus.consumer("double", (VertxMessage<int> msg) {
      _log.info("double received");
      expect(msg.body, 1.1);
      control.visited();
    });

    eventBus.consumer("doubleString", (VertxMessage<int> msg) {
      _log.info("doubleString received");
      expect(msg.body, "1.1");
      control.visited();
    });

    eventBus.consumer("boolean", (VertxMessage<int> msg) {
      _log.info("boolean received");
      expect(msg.body, true);
      control.visited();
    });

    eventBus.consumer("booleanString", (VertxMessage<int> msg) {
      _log.info("booleanString received");
      expect(msg.body, "true");
      control.visited();
    });

    eventBus.consumer("publish", (VertxMessage msg) {
      _log.info("Event on address publish received");

      expect(msg.body, 2);
      expect(msg.headers["headerName"], "headerValue");

      control.visited();
    });
    _log.info("publishConsumer registered");

    eventBus.consumer("withReply", (VertxMessage<int> msg) {
      _log.info("Event on address withReply received");

      expect(msg.body, 3);
      expect(msg.headers["headerName"], "headerValue");

      msg.reply(body: msg.body, headers: msg.headers);

      control.visited();
    });
    _log.info("withReply registered");

    eventBus.consumer("doubleReply", (VertxMessage<int> msg) async {
      _log.info("Event on address doubleReply received");

      expect(msg.body, 4);
      expect(msg.headers["headerName"], "headerValue");

      AsyncResult result = await msg.replyAsync(body: msg.body, headers: msg.headers);
      _log.info("Event on address doubleReply received");

      expect(result.success, isTrue);
      expect(result.failed, isFalse);
      expect(result.message.body, 4);
      expect(result.message.headers["headerName"], "headerValue");

      result.message.reply(body: result.message.body, headers: result.message.headers);

      control.visited();
    });

    eventBus.encoderRegistry[MoreComplexTestDto] = MoreComplexTestDtoCodec.encoder;

    eventBus.consumer("complexWithReply", (VertxMessage<MoreComplexTestDto> msg) {
      _log.info("Event on address withReply received");

      expect(msg.body, new isInstanceOf<MoreComplexTestDto>());
      MoreComplexTestDto dto = msg.body;
      expect(dto.integer, 100);
      expect(dto.integerString, "100");
      expect(dto.string, "value");
      expect(dto.doubleValue, 100.1);
      expect(dto.doubleString, "100.1");
      expect(dto.boolean, isTrue);
      expect(dto.booleanString, "true");
      expect(dto.obj, isNotNull);

      expect(msg.headers["headerName"], "headerValue");

      msg.reply(body: msg.body, headers: msg.headers);

      control.visited();
    }, decoder: MoreComplexTestDtoCodec.decoder);

    _log.info("doubleReply registered");

    await control.waitUntilDone();
  });
}
