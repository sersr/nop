import 'dart:async';

import 'package:meta/meta.dart';

import '../../event_queue.dart';

mixin IsolateAutoInitAndCloseMixin {
  Timer? _timer;
  int get closeDelay => 10000;
  int get initIDelay => 100;

  SendInitCloseMixin get isolateHandle;

  bool closeIsolateState = false;
  bool initIsolateState = false;

  void onInitIsolate() {
    if (initIsolateState) _run(initIDelay, isolateHandle.init);
  }

  void onCloseIsolate() {
    if (closeIsolateState) _run(closeDelay, isolateHandle.close);
  }

  void _run(int mill, void Function() run) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: mill), run);
  }
}

/// 提供安全的调用接口
mixin SendInitCloseMixin {
  @protected
  FutureOr<void> initTask();
  @protected
  FutureOr<void> closeTask();
  final _privateKey = Object();

  bool get taskState => EventQueue.getQueueState(_privateKey);

  Future<void> init() {
    return EventQueue.runOne(_privateKey, initTask);
  }

  /// 要释放资源应该要调用本函数
  Future<void> close() {
    return EventQueue.runOne(_privateKey, closeTask);
  }
}
