import 'package:rfw/rfw.dart';

final class RfwEvent {
  const RfwEvent(this.name, this.arguments);

  /// The event name
  final String name;

  /// The event arguments.
  final DynamicMap arguments;
}
