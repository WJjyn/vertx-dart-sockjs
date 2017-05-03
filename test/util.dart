import 'package:logging/logging.dart';

/// Configures [Logger] for tests
void startLogger() {
  Logger.root.level = Level.ALL;
  recordStackTraceAtLevel = Level.SEVERE;
  Logger.root.onRecord.listen((LogRecord rec) {
    if (rec.stackTrace == null) {
      print('${rec.level.name} -> ${rec.loggerName}: ${rec.message}');
    } else {
      print('${rec.level.name} -> ${rec.loggerName}: ${rec.message} | ${rec.error}');
      print("${rec.stackTrace}");
    }
  });
}
