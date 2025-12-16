class Logger {
  static void init() {
    // Initialize logging
  }

  static void log(String message) {
    print('[LOG] $message');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    print('[ERROR] $message');
    if (error != null) print(error);
    if (stackTrace != null) print(stackTrace);
  }
}
