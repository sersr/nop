import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../nop.dart';

Object createIdentityKey() => Capability();

dynamic materialize(dynamic data) {
  if (data is TransferableTypedData) {
    return data.materialize();
  }
}

/// 创建一个[Isolate]
class IsolateRemoteServer<T> extends RemoteServer<T> {
  IsolateRemoteServer({
    required this.entry,
    this.debugName,
    required this.args,
  });
  final T args;
  final RemoteEntryPoint<T> entry;
  final String? debugName;

  @override
  SendHandleName? get lastSendHandle => _lastSendHandle;

  Isolate? _isolate;
  Future<SendHandleName>? _createTask;
  @override
  Future<SendHandleName> create(SendHandle rootSendHandle) async {
    if (_lastSendHandle case var handle? when _isolate != null) {
      return handle;
    }

    return _createTask ??= _create(rootSendHandle)
      ..whenComplete(() => _createTask = null);
  }

  SendHandleName? _lastSendHandle;
  Future<SendHandleName> _create(SendHandle sendHandle) async {
    final recv = ReceivePort();
    _isolate = await Isolate.spawn(_nopIsolate, (
      entry,
      recv.sendPort,
      sendHandle,
      args,
    ), debugName: debugName);
    final res = await recv.first;
    if (res case SendHandleName res) {
      return _lastSendHandle = res;
    } else {
      Log.e("error: $res");
      throw res;
    }
  }

  @override
  bool get killed => _isolate == null;
  @override
  void kill() {
    if (_isolate != null) {
      _lastSendHandle = null;
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }
    super.kill();
  }

  static void _nopIsolate(
    (dynamic entry, SendPort sendPort, SendHandle sendHandle, dynamic args)
    data,
  ) {
    final (entry, sendPort, sendHandle, args) = data;

    try {
      final isolate = IsolateResolve(
        remoteSendHandle: sendHandle,
        resolveRecord: entry(args),
      );

      isolate.run();
      sendPort.send(isolate.currentLocalSendHandle);
    } catch (e, s) {
      Log.e('init isolate error: $e\n$s');
      sendPort.send(e);
    }
  }
}

mixin _TransferTypeMapData<T> implements TransferType<T> {
  FutureOr<void> tranEncode();
  FutureOr<T> tranDecode();

  void push(Object key, TransferableTypedData data) {
    assert(!_data.containsKey(key) || Log.e('key: $key'));
    _data.putIfAbsent(key, () => data);
  }

  TransferableTypedData? getData(Object? key) {
    return _data[key];
  }

  int getLength<D>() {
    return _data.keys.whereType<D>().length;
  }

  final Map<Object, TransferableTypedData> _data = {};

  bool _decoded = false;
  bool get decoded => _decoded;
  T? _decodedData;
  @override
  FutureOr<T> decode() async {
    if (_decodedData != null) return _decodedData!;
    _decoded = true;
    final data = await tranDecode();
    return _decodedData = data;
  }

  bool _encoded = false;
  bool get encoded => _encoded;
  @override
  FutureOr<void> encode() async {
    if (_data.isNotEmpty || encoded) {
      Log.w('encoded: $encoded');
      return;
    }
    _encoded = true;
    try {
      await tranEncode();
    } catch (e) {
      assert(Log.e(e));
    }
  }
}

class Uint8ListType with _TransferTypeMapData<Uint8List?> {
  Uint8ListType(this.list);

  Uint8List? list;
  @override
  FutureOr<Uint8List?> tranDecode() {
    final buffer = getData('list');
    if (buffer != null) {
      final data = buffer.materialize();
      return data.asUint8List();
    } else if (list != null) {
      return list;
    }
    return null;
  }

  @override
  FutureOr<void> tranEncode() {
    if (list != null) {
      final data = list!;

      list = null;
      final typeData = TransferableTypedData.fromList([data]);
      push('list', typeData);
    }
  }
}
