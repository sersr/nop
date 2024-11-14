import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../nop.dart';

mixin Sender {
  void addData(data);
  void addError(Object error, StackTrace stackTrace);
  void cancel();
  late final Object identityKey = Capability();
  Object? messageKey;
  String? serverName;

  bool nullOnError = false;
}

dynamic materialize(dynamic data) {
  if (data is TransferableTypedData) {
    return data.materialize();
  }
}

mixin TransferTypeMapData<T> implements TransferType<T> {
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

mixin TransferTypeMapDataList<E, D, T> on TransferTypeMapData<T> {
  @protected
  List<E>? get raw;
  @protected
  set raw(List<E>? v);

  String get prefix => '_map_data_list';

  @override
  FutureOr<T> tranDecode() async {
    final list = <D>[];
    var index = 0;
    while (true) {
      final tranData = getData('$prefix$index');
      if (tranData == null) break;
      final data = tranData.materialize();
      list.add(await decodeToSelf(data, index));
      index++;
      await idleWait;
    }

    return getValueFrom(list);
  }

  FutureOr<T> getValueFrom(List<D> data);

  @override
  FutureOr<void> tranEncode() async {
    if (raw != null) {
      final rawDataList = List.of(raw!);
      raw = null;
      for (var i = 0; i < rawDataList.length; i++) {
        final data = await encodeToTypedData(rawDataList[i], i);
        push('$prefix$i', TransferableTypedData.fromList([data]));
        await idleWait;
      }
    }
  }

  FutureOr<D> decodeToSelf(ByteBuffer buffer, int index);

  FutureOr<TypedData> encodeToTypedData(E rawData, int index);
}

/// 创建一个[Isolate]
class IsolateRemoteServer<T> extends RemoteServer {
  IsolateRemoteServer(
      {required this.entryPoint, required this.args, this.debugName});
  final ServerConfigurations<T> args;
  final RemoteEntryPoint<T> entryPoint;
  final String? debugName;

  Isolate? _isolate;
  @override
  Future<void> create() async {
    _isolate ??= await Isolate.spawn(
        _nopIsolate, _IsolateCreaterWithArgs(entryPoint, args),
        debugName: debugName);
  }

  @override
  bool get killed => _isolate == null;
  @override
  void kill() {
    if (_isolate != null) {
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }
  }

  static void _nopIsolate(_IsolateCreaterWithArgs args) => args.apply();
}

class _IsolateCreaterWithArgs<T> {
  final ServerConfigurations<T> args;
  final RemoteEntryPoint<T> entryPoint;
  _IsolateCreaterWithArgs(this.entryPoint, this.args);
  FutureOr<void> apply() => entryPoint(args).then((runner) => runner.run());
}
