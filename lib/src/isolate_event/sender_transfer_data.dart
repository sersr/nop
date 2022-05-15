import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../event_queue.dart';
import '../../utils.dart';

mixin TransferType<D> {
  FutureOr<void> encode();
  FutureOr<D> decode();
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
      final _raw = List.of(raw!);
      raw = null;
      for (var i = 0; i < _raw.length; i++) {
        final data = await encodeToTypedData(_raw[i], i);
        push('$prefix$i', TransferableTypedData.fromList([data]));
        await idleWait;
      }
    }
  }

  FutureOr<D> decodeToSelf(ByteBuffer buffer, int index);

  FutureOr<TypedData> encodeToTypedData(E rawData, int index);
}

abstract class TransferTypeMapList<E, D, T>
    with TransferTypeMapData<T>, TransferTypeMapDataList<E, D, T> {}
