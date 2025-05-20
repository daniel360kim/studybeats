import 'package:logger/logger.dart';
class MyFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}

class SimpleLogPrinter extends LogPrinter {
  final String className;
  SimpleLogPrinter({required this.className});

  @override
  bool shouldLog(LogEvent event) {
    return true;
  }

  @override
  List<String> log(LogEvent event) {
    final time = event.time.toIso8601String();
    final color = PrettyPrinter.defaultLevelColors[event.level];
    final emoji = PrettyPrinter.defaultLevelEmojis[event.level];
    final level = LogfmtPrinter.levelPrefixes[event.level];

    StringBuffer buffer = StringBuffer();
    buffer.write('$time: ');
    buffer.write('$emoji ');
    buffer.write(color!('[$level]'));
    buffer.write(color(' ($className): '));
    buffer.write(color(event.message.toString()));

    List<String> output = [buffer.toString()];
    return output;
  }
}

Logger getLogger(String className) {
  return Logger(
    filter: MyFilter(),
    printer: SimpleLogPrinter(className: className),
  );
}
