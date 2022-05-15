import 'dart:async';

import 'log.dart';

class Time {
  Time();
  static final defaultTime = Time();
  final _stop = Stopwatch();
  int get currentMicroseconds {
    if (!_stop.isRunning) {
      _stop.start();
    }
    return _stop.elapsedMicroseconds;
  }

  double useTimeMs(int lastTime) {
    return (currentMicroseconds - lastTime) / 1000;
  }
}

Time get stopTime => Time.defaultTime;

extension UseTimeMs on int {
  double get useTimeMs {
    return stopTime.useTimeMs(this);
  }
}

extension UseTime<T> on Future<T> {
  /// 从正式开始异步开始计算
  /// 前面同步块区域是没有计算其中
  Future<T> useTimeMs(void Function(T current, double useTime) end) {
    return onWait<int>(() => stopTime.currentMicroseconds,
        (current, use) => end(current, use.useTimeMs));
  }

  Future<T> logi([bool onlyDebug = true]) =>
      log(Log.info, StackTrace.current, onlyDebug);
  Future<T> logw([bool onlyDebug = true]) =>
      log(Log.warn, StackTrace.current, onlyDebug);
  Future<T> loge([bool onlyDebug = true]) =>
      log(Log.error, StackTrace.current, onlyDebug);

  Future<T> log(int level, [StackTrace? stack, bool onlyDebug = true]) {
    if (onlyDebug && !debugMode) return this;
    stack ??= StackTrace.current;
    return useTimeMs((current, useTime) {
      Log.log(level, 'use: $useTime ms', position: 1, onlyDebug: onlyDebug);
    });
  }

  Future<T> onWait<D>(D Function() start, void Function(T current, D end) end) {
    final d = start();
    then((v) => end(v, d));
    return this;
  }
}
