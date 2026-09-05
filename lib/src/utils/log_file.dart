import '../../utils.dart';
import '_log_file_io.dart' if (dart.library.js_interop) '_log_file_web.dart'
    as lf;

abstract class LogFile {
  factory LogFile(String fileName) = lf.LogFile;

  String get fileName;
  void log(
    Object? message,
    LogLevel minLevel,
    LogLevel level,
    LogColor color,
    String path,
  );

  void updateLogDir(String dir);
}
