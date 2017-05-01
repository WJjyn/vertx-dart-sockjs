import 'dart:async';
@TestOn("dartium")
@Timeout(const Duration(seconds: 10))
import 'dart:js';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vertx_dart_sockjs/vertx_eb.dart';

final Logger _logger = new Logger("ServerToClientTest");

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

//  test("Server motivated event test", () async {
//    Zone z = Zone.current;
//
//    int currentConsumerNumber = 0;
//
//    final Function asyncCallback = expectAsync((int bodyValue, JsObject headers) {
//      _logger.info("Call async callback");
//
//      z.runBinary(expect, bodyValue, ++currentConsumerNumber);
//      _logger.info("Body value validated");
//
//      z.runBinary(expect, headers["headerName"], "headerValue");
//      _logger.info("Header value validated");
//    }, count: 3);
//
//    eventBus.consumer("simpleSendConsumer", (VertxMessage msg) {
//      _logger.info("Event on address simpleSendConsumer received");
//
//      int bodyValue = msg.body;
//      JsObject header = msg.headers;
//      z.runBinary(asyncCallback, bodyValue, header);
//    });
//
//    _logger.info("simpleSendConsumer registered");
//
//    eventBus.consumer("publishConsumer", (VertxMessage msg) {
//      _logger.info("Event on address publishConsumer received");
//
//      int bodyValue = msg.body;
//      JsObject header = msg.headers;
//
//      z.runBinary(asyncCallback, bodyValue, header);
//    });
//    _logger.info("publishConsumer registered");
//
//    eventBus.consumer("consumerWithReply", (VertxMessage<int> msg) {
//      _logger.info("Event on address consumerWithReply received");
//
//      int bodyValue = msg.body;
//      JsObject header = msg.headers;
//
//      msg.reply(bodyValue, {"headerName": "${header['headerName']}"});
//
//      z.runBinary(asyncCallback, bodyValue, header);
//    });
//    _logger.info("consumerWithReply registered");
//  });
}
