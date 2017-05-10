# vertx_dart_sockjs

Library to connect either to plain SockJS or Vert.x event bus server.

## Usage

This library do embrace two cases and contains separate implementations for each of them.

### Load JS files in index.html

There 1 or 2 JS file necessary. The one for SockJS and at the other hand Vert.x event bus.

> For sure, you can get at least the SockJS file also from many CDN platforms. I personally suggest to use the one from this library, specially when use Vert.x on the server side. 

```html
<head>
    <script defer src="packages/vertx_dart_sockjs/src/js/sockjs-0.3.4.min.js"></script>
    <script defer src="packages/vertx_dart_sockjs/src/js/vertx-eventbus-3.4.1.min.js"></script>
</head>
```

### Plain SockJS

Use this if you need more low level functionality for the communication with Vert.x or you work with an other SockJS server.

> Developed and tested is this library with Vert.x as server [Vert.x SockJS server](http://vertx.io/docs/vertx-web/java/#_sockjs)
> But it should work with any SockJS server thats' compatible to version 0.3.4.

#### SockJS Configuration

You can configure the SockJS instance for your needs. For more details about the protocol white list, please visit the 
[SockJS documentation](https://github.com/sockjs/sockjs-client/tree/v0.3.4)


```dart
class SockJSOptions {
  external bool get debug;
  external bool get devel;
  external List<String> get protocols_whitelist;
}
```

#### Create SockJS instance

For a new SockJS connection just provide the server url and *optional* it's configuration.  

```dart

import 'package:vertx_dart_sockjs/sockjs.dart';

SockJS sockJS = await SockJS.create("serverUrl", configuration);

```

#### Send message through the socket

Any String data can be send over SockJS.

```dart
sockJS.sendData("value");

```

#### Receive message from socket

To receive you have to register a callback. 

> Stream API support may in the future.

```dart
sockJS.onMessage((SockJsMessageEvent event) {
     // do anything
});
```

#### On close socket event

You can define a callback that get called when SockJS lost the connection.

```dart
void onClose( OnCloseCallback callback );
```

### Vert.x SockJS event bus bridge

This implementation is a counterpart for the [Vert.x SockJS bridge](http://vertx.io/docs/vertx-web/java/#_sockjs_event_bus_bridge)

Please visit this documentation for further information and the configuration on the server side.

> A goal was to provide a server like API where it makes sense.

#### Configuration

You can configure it with the SockJS configurations above and the following additional:

- enablePing : Enables pinging direct when the connection got established
- pingInterval : Ping interval that should be send to the server
- autoReconnect : When the event bus lost its connection, the connection will be tried to get established again.
- autoReconnectInterval : Interval the reconnect get tried. Makes only sense when *autoReconnect* is enabled. *Default 5 seconds*
- reopenedCallback : callback function that get called after reconnect (Not on initial connect)

Entry class for this configuration is **EventBusOptions**

#### Execution delegate (context)

Since many part of this library are async, the Dart zone can become very important, for example within AngularDart. When consumers or other callbacks 
get called not within the Angular zone, the re-rendering can be broken.

To ensure that any of them are called within the correct zone or other context, you can define your own execution delegate. 

```dart
typedef void ConsumerExecutionDelegate(Function f);
```

##### AngularDart Example

```dart
void delegate(Function f) {
  ngZone.runGuarded(() => f());
}
```


This delegator can be applied as parameter to the event bus create method.

#### Reconnect

The event bus can be configured to reconnect automatically after connection lost. All consumers and other callbacks will reattached too.
Just set the configuration properties *autoReconnect* to true and optional set the *autoReconnectInterval* and *reopenedCallback*.
 
#### Encoding / Decoding
 
JSON and plain basic types are supported out of the box. But many times you want or have to use your own protocol ... like Google Protobuf.
In this case you must tell the event bus how to encode and decode the data from and to the wire.

##### Decoding

Decoder can defined on consumer registration and on message send when a reply is expected.

```dart
typedef T EventBusBodyDecoder<T>(dynamic body);
```

 
##### Encoding

After you got an instance of the event bus you can access the **EncoderRegistry**

```dart
eventbus.encoderRegistry;
```

```dart
typedef dynamic EventBusBodyEncoder<T>(T dto);
```

On this instance you can register encoders by type of your dto's. So this encoder get used to encode anytime you send a event with an dto 
instance of this type.

#### Create client event bus instance

To get an instance of the event bus you **must** provide:

- Server url

and you **can** provide:

- consumer execution delegate : To ensure consumers and other callbacks get called within the correct zone for example.
- option : Options for SockJS and the event bus itself. Description above.

```dart
import 'package:vertx_dart_sockjs/vertx_eb.dart';

EventBus eventBus = await EventBus.create( "serverUrl", consumerExecDelegate: myExecutionDelegate, options: myBusOptions );
```

#### Send / publish message over the event bus

```dart
/**
* For one way messages.
*/
eventbus.send( "address", body: body, headers: headers );

/**
* For message with reply. This one expect a consumer reference as callback
*/
eventbus.sendWithReply( "address", consumer, body: body, headers: headers, decoder: decoder );

/**
* For message with reply. On this async await is used to receive messages asynchronously.
*/
Future<VertxEventBusMessage> future = eventbus.sendWithReplyAsync( "address", body: body, headers: headers, decoder: decoder );

eventbus.publish( "address", body: body, headers: headers );
```

#### Consume messages from the event bus

Usual consumer can be registered together with its responsible decoder.

```dart
ConsumerRegistry reg = eventBus.consumer( "address", consumer, decoder: decoder );

/**
* Unregister this way.
*/
reg.unregister( );
```

## Upcomings / planned

- Improvements on the SockJS API like Stream and / or async await
- Refactor file / class structure

## Lifecycle and updates

New versions of this library will be initiated by new Vert.x version.

## Features and bugs

Please submit them on  [issue tracker](https://github.com/wem/vertx-dart-sockjs/issues)
