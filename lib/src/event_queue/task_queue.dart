import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../nop.dart';

abstract class TaskQueue with TaskQueueMixin {
  TaskQueue._();

  factory TaskQueue({Object? globalKey, int channels = 1}) {
    if (globalKey != null) {
      return TaskQueueGlobal(globalKey: globalKey, channels: channels);
    }
    return TaskQueueImpl(channels: channels);
  }
  factory TaskQueue.all({Object? globalKey}) {
    return TaskQueue(globalKey: globalKey, channels: -1);
  }

  static void Function(Object error, StackTrace stackTrace)? catchErrorHandler;
}

class TaskQueueImpl extends TaskQueue {
  TaskQueueImpl({int channels = 1})
      : _eventQueue = EventQueue(channels: channels),
        super._();
  final EventQueue _eventQueue;
  @override
  S runTask<S>(S Function(EventQueue) callback) {
    return callback(_eventQueue);
  }

  @override
  Future? get runner => _eventQueue.runner;
  @override
  bool get actived => _eventQueue.actived;
}

class TaskQueueGlobal extends TaskQueue with EquatableMixin {
  TaskQueueGlobal({required this.globalKey, this.channels = 1}) : super._();
  final int channels;
  final Object globalKey;

  @override
  S runTask<S>(S Function(EventQueue) callback) {
    return EventQueue.runTask(globalKey, callback, channels: channels);
  }

  @override
  Future? get runner {
    return EventQueue.getQueueRunner(globalKey);
  }

  @override
  bool get actived {
    return EventQueue.getQueueState(globalKey);
  }

  @override
  List<Object?> get props => [globalKey, channels];
}

bool get tqIgnore => EventQueue.currentTask?.ignore ?? false;
bool get tqCanDiscard => EventQueue.currentTask?.canDiscard ?? false;
mixin TaskQueueMixin {
  @protected
  S runTask<S>(S Function(EventQueue) callback);

  Future? get runner;

  bool get actived;

  bool get ignore => tqIgnore;
  bool get canDiscard => tqCanDiscard;

  Future<R?> runOne<R>(EventCallback<R> action, {Object? taskKey}) {
    return runTask((eventQueue) {
      return eventQueue.awaitOne(action, taskKey: taskKey);
    });
  }

  Future<R> run<R>(EventCallback<R> action, {Object? taskKey}) {
    return runTask((eventQueue) {
      return eventQueue.awaitTask(action, taskKey: taskKey);
    });
  }

  void push<R>(EventCallback<R> action, {Object? taskKey}) {
    runTask((eventQueue) {
      eventQueue.addEventTask(action, taskKey: taskKey);
    });
  }

  void pushOne<R>(EventCallback<R> action, {Object? taskKey}) {
    runTask((eventQueue) {
      eventQueue.addOneEventTask(action, taskKey: taskKey);
    });
  }
}

/// 从当前对象获取全局的[TaskQueue]
extension TaskQueueExt on Object {
  TaskQueue get tqGlobal {
    return TaskQueue(globalKey: this);
  }

  TaskQueue get tqGlobalAll {
    return TaskQueue(globalKey: this, channels: -1);
  }
}
