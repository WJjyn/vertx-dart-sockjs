import 'dart:async';

import 'package:logging/logging.dart';
@TestOn("dartium")
@Timeout(const Duration(seconds: 10))
import 'package:test/test.dart';
import 'package:vertx_dart_sockjs/sockjs.dart';

final Logger _logger = new Logger("ClientToServerTest");

final Map<String, String> headers = {"headerName": "headerValue"};

main() async {
  SockJS sockJS;

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
    sockJS = await SockJS.create("http://localhost:9000/sockjs");
    _logger.info("connected to server");
  });

  test("Ping pong SockJS test", () async {
    Zone z = Zone.current;

    final Function asyncCallback = expectAsync((int bodyValue) {
      _logger.info("Call async callback");

      z.runBinary(expect, 1, bodyValue);
      _logger.info("Body value validated");
    }, count: 1);

    sockJS.onMessage((SockJsMessageEvent event) {
      z.runUnary(asyncCallback, int.parse(event.data));
    });

    sockJS.sendData("1");
  });
}
