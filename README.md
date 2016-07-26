# vertx_dart_sockjs

Library to connect either to plain SockJS or Vert.x event bus server.

## Usage

This library do embrace two cases and contains separate implementations for each of them.

### Load JS files in index.html

There 1 or 2 JS file necessary. The one for SockJS and at the other hand Vert.x event bus.

> For sure, you can get at least the SockJS file also from many CDN platforms. I personally suggest to use the one from this library, specially when use Vert.x on the server side. 

```html
<head>
    ...
    <script defer src="packages/vertx_dart_sockjs/js/sockjs.min.js"></script>
    <script defer src="packages/vertx_dart_sockjs/js/event-bus.js"></script>
    ...
</head>
```

### Plain SockJS

Use this if you need more low level functionality for the communication with Vert.x or you work with an other plain SockJS server.

> Developed and tested is this library with Vert.x as server [Vert.x SockJS server](http://vertx.io/docs/vertx-web/java/#_sockjs)
> But it should work with any SockJS server on version 0.3.4.

#### Create SockJS instance
```dart
...

import 'package:vertx_dart_sockjs/sockjs.dart';

...

SockJS sockJS = await SockJS.create("serverUrl");

```

#### Send message through the socket
```dart
...

sockJS.sendData("Value);

...

```

#### Receive message from socket
```dart
...

sockJS.onMessage((SockJsMessageEvent event) {
     // do anything
});

...

```

#### On close socket event
```dart
...

void onClose( OnCloseCallback callback );

...

```

### Vert.x SockJS event bus bridge

This implementation is a counterpart for the [Vert.x SockJS bridge](http://vertx.io/docs/vertx-web/java/#_sockjs_event_bus_bridge)

Please visit this documentation for further information and the configuration.

#### Create client event bus instance
```dart
...

import 'package:vertx_dart_sockjs/vertx_eb.dart';

...

EventBus eventBus = await EventBus.create( "serverUrl" );

```

#### Send message over the event bus
```dart
...

/**
* For one way messages.
*/
eventbus.send( String address, Object message, [Map<String, String> headers] )

/**
* For message with reply. This one expect a consumer reference as callback
*/
eventbus.sendWithReply( String address, Object message, Consumer consumer, [Map<String, String> headers] )

/**
* For message with reply. On this async await can be used to receive messages.
*/
Future<VertxEventBusMessage> future = eventbus.sendWithReplyAsync( String address, Object message, [Map<String, String> headers] )
...

```

#### Publish messages over the event bus
```dart
...

eventbus.publish( String address, Object message, [Map<String, String> headers] );

...

```

#### Consume messages from the event bus
```dart
...

ConsumerRegistry reg = eventBus.consumer( String address, Consumer consumer );

/**
* Unregister this way.
*/
reg.unregister( );

...

```


## Lifecycle and updates
New versions of this library will be initiated by new Vert.x version or more detailed, when Vert.x make use of a new SockJS version on it's side.

> The version number of this library is similar to the used SockJS one.

## Features and bugs

Please submit them on  [issue tracker](https://github.com/wem/vertx-dart-sockjs/issues)
