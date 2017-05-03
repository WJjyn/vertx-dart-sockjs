import 'package:logging/logging.dart';
import 'package:vertx_dart_sockjs/src/vertx_event_bus_base.dart';

/// Delegator for the execution of consumers. This can be helpful to execute consumers within a specific [Zone] or [NgZone] for example.
/// The main use case here is Angular, but for tests this can be helpful too.
///
/// Example:
///
/// class Component implements OnInit {
/// ...
/// NgZone zone;
/// ...
/// EventBus eventBus;
///
/// @override
/// ngOnInit() async {
///   eventBus = await EventBus.create("server_url", consumerExecDelegate: zone.runGuarded);
/// }
///
typedef void ConsumerExecutionDelegate(Function f);

/// Consumer for incipient events of type [VertxMessage] or result events [AsyncResult].
typedef void Consumer<T>(T messageOrResult);

/// Reference for a registered [Consumer]. Provides some information about that [Consumer] and make it possible to unregister it.
class ConsumerRegistry {
  static final Logger _log = new Logger("ConsumerRegistry");

  final Consumer consumer;

  final String address;

  final EventBusJS _eb;

  const ConsumerRegistry(this.consumer, this.address, this._eb);

  /// Unregister this [Consumer] for its address.
  void unregister() {
    _log.finest("Vertx consumer unregistered on $address");
    _eb.unregisterHandler(address);
  }
}
