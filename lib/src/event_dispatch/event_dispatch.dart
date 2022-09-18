import 'dart:async';
export 'event_dispatch_lazy.dart';

/// 默认实现
class ListenerController<T> with ListenerControllerMixin<T> {
  @override
  bool get shouldCache => false;
}

/// 监听控制器
///
/// 与广播流不同的是，订阅者在`resume`时会重新接收到事件
mixin ListenerControllerMixin<T> {
  final listenUnits = <ListenerUnit<T>>{};
  final activeUnits = <ListenerUnit<T>>{};

  T? lastData;

  void _childResume(ListenerUnit<T> child) {
    /// T 可以是 T 或 T?
    if (lastData is T) {
      child.add(lastData as T);
    }
  }

  bool get shouldCache;

  List<T>? _caches;

  void onListen(ListenerUnit<T> child) {
    if (_listenFirst) return;
    if (shouldCache) {
      if (_caches != null) {
        for (var item in _caches!) {
          child.add(item);
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
    if (isPaused) return;
    for (var l in listenUnits) {
      l.add(data);
    }
  }

  void remove(ListenerUnit<T> unit) {
    listenUnits.remove(unit);
    activeUnits.remove(unit);
    if (listenUnits.isEmpty && !_disposed) {
      _disposed = true;
      dispose();
    }
  }

  bool get hasListener => listenUnits.any((e) => e.hasListener);

  bool _listenFirst = true;
  bool get listenFirst => _listenFirst;
  void trigger() {
    final lastPaused = isPaused;
    _isPaused = activeUnits.isEmpty;

    if (lastPaused != isPaused) notifyClient();
    if (_listenFirst) _listenFirst = false;
  }

  // pause <=> resume 调用
  void notifyClient() {}

  void onResume() {
    if (!isPaused) {
      for (var item in activeUnits) {
        if (item._dirty) {
          _childResume(item);
        }
      }
    }
  }

  bool _isPaused = true;
  bool _canceled = false;
  bool _disposed = false;
  bool get isPaused => _isPaused;
  bool get isDisposed => _disposed;
  bool get isCanceled => _canceled;

  void cancel() {
    if (_canceled) return;
    _canceled = true;
    final listeners = List.of(listenUnits, growable: false);
    for (var l in listeners) {
      l.close();
    }
  }

  void dispose() {}

  SenderStream<T> get stream {
    final consumer = ListenerUnit<T>(this);
    return consumer.stream;
  }
}

class ListenerUnit<T> {
  ListenerUnit(this.listener);
  final ListenerControllerMixin<T> listener;
  late final controller = StreamController<T>(
    onPause: trigger,
    onResume: trigger,
    onCancel: onCancel,
    onListen: onListen,
  );

  bool get hasListener => controller.hasListener;

  bool _dirty = false;

  void onListen() {
    if (isRemoved) return;
    listener.listenUnits.add(this);
    listener.activeUnits.add(this);
    listener.onListen(this);
    listener.trigger();
  }

  bool get isPause => controller.isPaused;
  void trigger() {
    if (isRemoved) return;
    final isPaused = isPause;
    if (isPaused) {
      listener.activeUnits.remove(this);
    } else {
      listener.activeUnits.add(this);
    }
    final mPause = listener.isPaused;
    listener.trigger();
    // 状态不变时需要手动发送数据
    if (!isPaused && mPause == listener.isPaused && _dirty) {
      listener._childResume(this);
    }
  }

  void close() {
    /// 一些特殊情况下，`controller.close()`不会立即调用`onCancel`
    /// 比如：没有`listen`
    onCancel();
    if (controller.isClosed) {
      return;
    }

    /// 还是要调用一次，因为不知道用户行为
    /// 比如：保存`stream`对象，在`close`之后才监听
    /// 确保`Stream`收到`close`事件
    controller.close();
  }

  void onCancel() {
    listener.remove(this);
  }

  void add(T data) {
    if (isPause) {
      if (!_dirty) _dirty = true;
      return;
    }
    if (!controller.isClosed) {
      controller.add(data);
      if (_dirty) _dirty = false;
    }
  }

  bool get isRemoved => listener._canceled;

  SenderStream<T> get stream => SenderStream(this);

  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final sub = controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    if (isRemoved) {
      listener.onListen(this);
      close();
    }

    return sub;
  }
}

// stream delegate
class SenderStream<T> extends Stream<T> {
  SenderStream(this._source);
  final ListenerUnit<T> _source;
  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _source.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
