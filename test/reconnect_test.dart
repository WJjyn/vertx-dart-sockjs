@TestOn("browser || phantomjs")
@Timeout(const Duration(seconds: 60))
import 'dart:async';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vertx_dart_sockjs/vertx_event_bus.dart';

import 'test_util.dart';

final Logger _log = new Logger("ReconnectTest");

final Map<String, String> headers = {"headerName": "headerValue"};

const eventbusAddress = "http://localhost:9000/eventbus";

main() async {
  startLogger();

  test("Test reconnect after connection lost", () async {
    TestControl testControl = new TestControl(6);

    try {
      EventBusOptions options = new EventBusOptions(reopenedCallback: (){
        // Must be called after reconnect
        _log.info("reopenedCallback executed");
        testControl.visited();
      }, autoReconnect: true, autoReconnectInterval: 2000);
      EventBus eventBus = await EventBus.create(eventbusAddress, consumerExecDelegate: Zone.current.runGuarded, options: options);

      expect(eventBus.open, isTrue);

      // Should get called twice
      eventBus.onClose((){
        _log.info("onClose executed");
        expect(eventBus.open, isFalse);
        testControl.visited();
      });

      eventBus.consumer("after", (VertxMessage msg) {
        // Must be called by server after reconnect. Two times
        _log.info("consumer after reconnect executed");
        testControl.visited();
        msg.reply();
      });
    } catch (e, st) {
      _log.severe("Failed to send test message", e, st);
      fail("Failed to send test message");
    }

    await testControl.completer.future;
  });
}