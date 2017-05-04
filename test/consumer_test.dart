@TestOn("browser || phantomjs")
@Timeout(const Duration(seconds: 10))
@Tags(const ["client_only"])
import 'package:test/test.dart';

import 'package:vertx_dart_sockjs/vertx_event_bus.dart';
import 'test_util.dart';

void main() {
  startLogger();

  test("Test executeConsumer", () {
    final String value = "value";

    executeConsumer(ConsumerExecutionDelegateImpl, (String body) {
      expect(body, equals(value));
    }, value);
  });

  test("Test executeConsumer failing consumer", () {
    final String value = "value";

    try {
      executeConsumer(ConsumerExecutionDelegateImpl, (String body) {
        expect(body, equals(value));
        throw "Consumer fail";
      }, value);
    } catch (e) {
      fail("Consumer exception should not get thrown");
    }
  });
}

void ConsumerExecutionDelegateImpl(Function f) {
  f();
}
