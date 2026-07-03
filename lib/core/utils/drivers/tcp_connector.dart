// Conditional import - uses native socket on io platforms, stub on web
export 'tcp_connector_native.dart'
    if (dart.library.html) 'tcp_connector_stub.dart';
