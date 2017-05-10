import 'package:logging/logging.dart';
import 'package:vertx_dart_sockjs/vertx_event_bus.dart';

final Logger _log = new Logger("Consumer");

/// Executes that [Consumer] with that [ConsumerExecutionDelegate]. The [Consumer] will be parametrized with that [messageOrResult]
void executeConsumer(ConsumerExecutionDelegate execDelegate, Consumer consumer, dynamic messageOrResult) {
  try {
    if (execDelegate != null) {
      execDelegate(() {
        consumer(messageOrResult);
      });
    } else {
      consumer(messageOrResult);
    }
  } catch (e, st) {
    // No exception thrown because its just the javascript layer below.
    _log.severe("Receipient failure on consumer ${consumer}", e, st);
  }
}
