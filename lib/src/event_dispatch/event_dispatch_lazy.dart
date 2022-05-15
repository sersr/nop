import 'dart:async';

import '../../event_queue.dart';
import '../../utils.dart';

/// 默认实现
class StreamLazyController<T> with StreamLazyMixin<T> {}

/// [pause]的对象不会立即进入`dirty`状态,会在一个新的数据被添加进来后,
/// 设为`dirty`状态,只有在`dirty`状态下，`resume`才有可能调用`_childResume`,
/// 获取新数据
///
/// [_StreamSubscriptionUnit]:[pause]、[resume]、[cancel]都是同步操作
mixin StreamLazyMixin<T> {
  final dirtyUnits = <_StreamSubscriptionUnit<T>>{};
  final activeUnits = <_StreamSubscriptionUnit<T>>{};
  final pausedUnits = <_StreamSubscriptionUnit<T>>{};

  T? lastData;

  void _childResume(_StreamSubscriptionUnit<T> child) {
    /// T 可以是 T 或 T?
    if (lastData is T) {
      child.sendData(lastData as T);
    }
  }

  bool get shouldCache => false;

  List<T>? _caches;

  void onListen(_StreamSubscriptionUnit<T> child) {
    if (_listenFirst) return;
    if (shouldCache) {
      if (_caches != null) {
        for (var item in _caches!) {
          child.sendData(item);
        }
        return;
      }
    }
    _childResume(child);
  }

  void add(T data) {
    if (shouldCache) {
      _caches ??= <T>[];
      _caches!.add(data);
    }
    lastData = data;
    if (_listenFirst) _listenFirst = false;
    moveToDirty();
    if (isPaused) return;
    if (activeUnits.isNotEmpty) {
      for (var l in activeUnits) {
        l.sendData(data);
      }
    }
  }

  void addError(Object error, StackTrace stackTrace) {
    moveToDirty();
    if (isPaused) return;
    if (activeUnits.isNotEmpty) {
      for (var l in activeUnits.toList()) {
        l.sendError(error, stackTrace);
      }
    }
  }

  void moveToDirty() {
    if (pausedUnits.isNotEmpty) {
      for (var dirty in pausedUnits) {
        assert(!dirty._dirty);
        dirty._dirty = true;
        dirtyUnits.add(dirty);
      }
      pausedUnits.clear();
    }
  }

  void _dispose() {
    if (!hasListener && !_disposed) {
      _disposed = true;
      assert(Log.i('dispose.'));
      dispose();
    }
  }

  bool get hasListener =>
      dirtyUnits.isNotEmpty || activeUnits.isNotEmpty || pausedUnits.isNotEmpty;

  bool _listenFirst = true;
  bool get listenFirst => _listenFirst;

  /// 如果`isPaused`状态没有改变,`resume`时有可能发生这种情况
  /// 手动为`self`更新数据
  void trigger({_StreamSubscriptionUnit<T>? self}) {
    final _last = isPaused;
    _isPaused = activeUnits.isEmpty;

    var notified = false;
    if (_last != isPaused) {
      notifyClient();
      notified = true;
    }

    if (self != null) {
      if (!listenFirst) {
        _childResume(self);
      } else if (!notified) {
        notifyClient();
      }
    }
  }

  // pause <=> resume 调用
  void notifyClient() {}

  bool _isPaused = true;
  bool _canceled = false;
  bool _disposed = false;
  bool get isPaused => _isPaused;
  bool get isDisposed => _disposed;
  bool get isCanceled => _canceled;

  void resetDispose() {
    _disposed = false;
  }

  void close() => cancel();

  void cancel() {
    if (_canceled) return;
    _canceled = true;
    if (!hasListener) {
      _dispose();
      return;
    }
    final _active = List.of(activeUnits, growable: false);
    final _paused = List.of(pausedUnits, growable: false);
    final _ditry = List.of(dirtyUnits, growable: false);
    _active.forEach(_close);
    _paused.forEach(_close);
    _ditry.forEach(_close);
  }

  static void _close<T>(_StreamSubscriptionUnit<T> item) {
    item.sendDone();
  }

  /// 没有监听者调用一次
  void dispose() {}

  _SenderLayzeStream<T> get stream => _SenderLayzeStream<T>(this);
  _SenderLayzeStream<T> get streamAsync =>
      _SenderLayzeStream<T>(this, async: true);

  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    bool async = false,
  }) {
    final _StreamSubscriptionUnit<T> sub;
    if (async) {
      sub = _StreamSubscriptionAsyncUnit<T>(this, onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    } else {
      sub = _StreamSubscriptionUnit<T>(this, onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    }
    if (_canceled) {
      onListen(sub);
      sub.sendDone();
    } else {
      _onListen(sub);
    }

    return sub;
  }

  static bool ifSelfCancel(_StreamSubscriptionUnit self) => self._canceled;

  void _onListen(_StreamSubscriptionUnit<T> self) {
    assert(!_canceled);
    assert(!self._canceled);
    assert(!dirtyUnits.contains(self));
    assert(!self._dirty);

    activeUnits.add(self);
    onListen(self);
    trigger();
  }

  void _onResume(_StreamSubscriptionUnit<T> self) {
    if (ifSelfCancel(self)) return;
    final dirty = self._dirty;
    if (dirty) {
      self._dirty = false;
      dirtyUnits.remove(self);
      activeUnits.add(self);
    } else if (self._paused) {
      pausedUnits.remove(self);
      activeUnits.add(self);
    }

    trigger(self: dirty ? self : null);
  }

  void _onPause(_StreamSubscriptionUnit<T> self) {
    if (ifSelfCancel(self)) return;
    if (pausedUnits.contains(self) || dirtyUnits.contains(self)) return;
    activeUnits.remove(self);
    pausedUnits.add(self);
    trigger();
  }

  void _onCancel(_StreamSubscriptionUnit<T> self) {
    if (ifSelfCancel(self)) return;
    assert(self._dirty || !dirtyUnits.contains(self));
    if (self._dirty) {
      dirtyUnits.remove(self);
    } else if (self._paused) {
      pausedUnits.remove(self);
    } else {
      activeUnits.remove(self);
    }
    assert(!dirtyUnits.contains(self) && !activeUnits.contains(self),
        '${self._dirty} ${dirtyUnits.contains(self)} ${activeUnits.contains(self)}');
    _dispose();
  }
}

// stream delegate
class _SenderLayzeStream<T> extends Stream<T> {
  _SenderLayzeStream(this._source, {this.async = false});
  final StreamLazyMixin<T> _source;
  final bool async;

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _source.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
      async: async,
    );
  }
}

typedef _DataHandler<T> = void Function(T value);
typedef _DoneHandler = void Function();

void _nullOnDataHandler(dynamic value) {}
void _nullOnDoneHandler() {}
void _nullOnErrorHandler(Object error, StackTrace stackTrace) {
  Zone.current.handleUncaughtError(error, stackTrace);
}

class _StreamSubscriptionUnit<T> extends StreamSubscription<T> {
  _StreamSubscriptionUnit(
      StreamLazyMixin<T> _source, void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError})
      : this.zone(Zone.current, _source, onData,
            onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  _StreamSubscriptionUnit.zone(
      this.zone, this._source, void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError})
      : _cancelOnError = cancelOnError ?? false,
        _onData = onDataHandle(zone, onData),
        _onDone = onDoneHandler(zone, onDone),
        _onError = onErrorHandle(zone, onError);

  final StreamLazyMixin<T> _source;

  Zone zone;
  _DataHandler<T> _onData;
  _DoneHandler _onDone;
  Function _onError;
  bool _cancelOnError;

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final _future = Completer<E>();
    _onDone = () {
      _future.complete(futureValue);
    };
    _onError = (error, stackTrace) {
      _future.completeError(error, stackTrace);
    };
    return _future.future;
  }

  @override
  bool get isPaused => _paused;

  @override
  void onData(void Function(T data)? handleData) {
    _onData = onDataHandle(zone, handleData);
  }

  static _DataHandler<T> onDataHandle<T>(
      Zone zone, void Function(T data)? handleData) {
    return zone
        .registerUnaryCallback<void, T>(handleData ?? _nullOnDataHandler);
  }

  @override
  void onDone(void Function()? handleDone) {
    _onDone = onDoneHandler(zone, handleDone);
  }

  static _DoneHandler onDoneHandler(Zone zone, void Function()? handleDone) {
    return zone.registerCallback<void>(handleDone ?? _nullOnDoneHandler);
  }

  @override
  void onError(Function? handleError) {
    _onError = onErrorHandle(zone, handleError);
  }

  static Function onErrorHandle(Zone zone, Function? handleError) {
    handleError ??= _nullOnErrorHandler;
    if (handleError is void Function(Object, StackTrace)) {
      return zone.registerBinaryCallback(handleError);
    } else if (handleError is void Function(Object)) {
      return zone.registerUnaryCallback(handleError);
    }
    throw ArgumentError("handleError callback must take either an Object "
        "(the error), or both an Object (the error) and a StackTrace.");
  }

  bool _paused = false;
  @override
  void pause([Future<void>? resumeSignal]) {
    resumeSignal?.whenComplete(resume);
    if (_paused) return;
    _source._onPause(this);
    _paused = true;
  }

  @override
  void resume() {
    if (!_paused) return;
    _source._onResume(this);
    _paused = false;
  }

  bool _done = false;

  bool _dirty = false;
  bool _canceled = false;
  bool get isCanceled => _canceled;
  bool get closed => _canceled || _done;

  @override
  Future<void> cancel() async {
    _source._onCancel(this);
    _canceled = true;
  }

  @pragma('vm:prefer-inline')
  void runWork(FutureOr<void> Function() work) {
    if (closed) return;
    work();
  }

  void sendData(T data) {
    runWork(() {
      assert(!_dirty);
      zone.runUnaryGuarded(_onData, data);
    });
  }

  void sendError(Object error, StackTrace stackTrace) {
    runWork(() {
      if (_cancelOnError) {
        cancel();
      }
      final onError = _onError;
      if (onError is void Function(Object, StackTrace)) {
        return zone.runBinaryGuarded(onError, error, stackTrace);
      } else {
        return zone.runUnaryGuarded<Object>(onError as dynamic, error);
      }
    });
  }

  void sendDone() {
    assert(!closed);
    runWork(() {
      _done = true;
      zone.runGuarded(_onDone);
    });
  }
}

class _StreamSubscriptionAsyncUnit<T> extends _StreamSubscriptionUnit<T> {
  _StreamSubscriptionAsyncUnit(
      StreamLazyMixin<T> _source, void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError})
      : super.zone(Zone.current, _source, onData,
            onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  FutureOr<void> get runner {
    return EventQueue.getQueueRunner(this);
  }

  @override
  Future<void> cancel() {
    _complete();
    return super.cancel();
  }

  @override
  void resume() {
    super.resume();
    assert(!isPaused);
    _complete();
  }

  Completer? _wait;
  void _complete() {
    if (_wait?.isCompleted == false) {
      _wait?.complete();
      _wait = null;
    }
  }

  late final _innerQueue = EventQueue();

  /// 异步任务
  ///
  /// 需要处理状态的准确性
  /// 在[pause]状态时不会发送数据
  @override
  void runWork(FutureOr<void> Function() work) {
    _innerQueue.addEventTask(() async {
      while (isPaused) {
        if (closed) break;
        _wait ??= Completer();
        if (_wait != null) await _wait?.future;
      }

      super.runWork(work);
    });
  }
}
