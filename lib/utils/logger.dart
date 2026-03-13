import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

Logger createLogger(String tag) {
  return Logger(
    level: kReleaseMode ? Level.warning : Level.trace,
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: _TaggedOutput(tag),
  );
}

class _TaggedOutput extends LogOutput {
  final String tag;
  _TaggedOutput(this.tag);

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      // ignore: avoid_print
      print('[$tag] $line');
    }
  }
}
