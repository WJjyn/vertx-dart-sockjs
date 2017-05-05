@JS()
library sockjs.native;

import 'package:js/js.dart';

@JS("SimpleEvent")
class SimpleEventImpl {
  external String get type;
  external String get data;
}

/// Options to configure SockJS
@JS()
@anonymous
class SockJSOptions {
  external bool get debug;
  external bool get devel;
  external List<String> get protocols_whitelist;

  external factory SockJSOptions({bool debug, bool devel, List<String> protocols_whitelist});
}

/// SockJS javascript object representation
@JS("SockJS")
class SockJSImpl {
  external SockJSImpl(String url, dynamic reserved, SockJSOptions options);

  external void set onopen(Function callback);

  external void set onmessage(Function callback);

  external void set onclose(Function callback);

  external send(String data);

  external int get readyState;
}
