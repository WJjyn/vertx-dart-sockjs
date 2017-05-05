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

  test("Test send without authority", () async {
    Completer completer = new Completer();
    try {
      eventBus = await EventBus.create(eventbusAddress, consumerExecDelegate: Zone.current.runGuarded);
      eventBus.onError((EventBusError error) {
        expect(error, equals(EventBusError.ACCESS_DENIED));
        completer.complete();
      });
      eventBus.send("with_authorization");
    } catch (e, st) {
      _log.severe("Failed to send test message", e, st);
      fail("Failed to send test message");
    }

    await completer.future;
  });
}