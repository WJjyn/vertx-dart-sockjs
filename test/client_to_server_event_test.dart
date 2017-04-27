import 'dart:async';
import 'dart:js';

import 'package:logging/logging.dart';
@TestOn("dartium")
@Timeout(const Duration(seconds: 10))
import 'package:test/test.dart';
import 'package:vertx_dart_sockjs/vertx_eb.dart';

final Logger _logger = new Logger("ClientToServerTest");

final Map<String, String> headers = {"headerName": "headerValue"};

main() async {
  EventBus eventBus;

  setUp(() async {
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
    _logger.info("try to connect to server");
    eventBus = await EventBus.create("http://localhost:9000/eventbus");
    _logger.info("connected to server");
  });

  test("Client motivated test", () async {
    Zone z = Zone.current;

    int expectConsumerValue = 3;

    final Function asyncCallback = expectAsync((int bodyValue, JsObject headers) {
      _logger.info("Call async callback");

      z.runBinary(expect, bodyValue, expectConsumerValue++);
      _logger.info("Body value validated");

      z.runBinary(expect, headers["headerName"], "headerValue");
      _logger.info("Header value validated");
    }, count: 2);

    eventBus.send("simpleSendConsumer", 1, headers);
    _logger.info("message to simpleSendConsumer send");

    eventBus.send("publishConsumer", 2, headers);
    _logger.info("message to publishConsumer send");

    eventBus.sendWithReply("consumerWithReply", 3, (VertxEventBusMessage<int, Object> message) {
      _logger.info("reply for consumerWithReply received");
      z.runBinary(asyncCallback, message.body, message.headers);
    }, headers);

    VertxEventBusMessage<int, Object> reply = await eventBus.sendWithReplyAsync("consumerWithReplyAsync", 4, headers);
    _logger.info("reply for consumerWithReplyAsync received");
    z.runBinary(asyncCallback, reply.body, reply.headers);
  });
}
