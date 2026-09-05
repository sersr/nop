import '../../utils.dart';
import 'log_file.dart' as l;

final class LogFile implements l.LogFile {
  LogFile(this.fileName);
  @override
  final String fileName;

  @override
  void log(
    Object? message,
    LogLevel minLevel,
    LogLevel level,
    LogColor color,
    String path,
  ) {}

  @override
  void updateLogDir(String dir) {}
}
