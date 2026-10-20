class BackendApiEndpoint {
  BackendApiEndpoint._();

  static int? _port;

  static int? get port => _port;

  static String get baseUrl {
    final port = _port;
    if (port == null) {
      throw StateError('Le moteur Python n’a pas encore publié son port.');
    }
    return 'http://127.0.0.1:$port';
  }

  static void bindPort(int port) {
    if (port < 1 || port > 65535) {
      throw RangeError.range(port, 1, 65535, 'port');
    }
    _port = port;
  }

  static void clearPort([int? expectedPort]) {
    if (expectedPort == null || _port == expectedPort) {
      _port = null;
    }
  }
}
