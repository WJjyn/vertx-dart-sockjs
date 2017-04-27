@JS()
library ch.sourcemotion.vertx.external;

import 'dart:js';

import 'package:js/js.dart';

@JS("EventBus")
class EventBusImpl {
  external EventBusImpl(String url, Object options);

  external send(String address, Object message, JsObject headers, dynamic replyConsumer);

  external publish(String address, Object message, JsObject headers);

  external registerHandler(String address, dynamic consumer);

  external unregisterHandler(String address);

  external set onopen(dynamic onOpenCallback);

  external set onclose(dynamic onCloseCallback);
}
