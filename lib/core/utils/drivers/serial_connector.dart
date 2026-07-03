// Conditional import - uses native serial on io platforms, stub on web
export 'serial_connector_native.dart'
    if (dart.library.html) 'serial_connector_stub.dart';
