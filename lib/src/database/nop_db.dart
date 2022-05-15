import 'dart:async';

typedef DatabaseOnCreate = FutureOr<void> Function(NopDatabase db, int version);
typedef DatabaseUpgrade = FutureOr<void> Function(
    NopDatabase db, int oVersion, int nVersion);

typedef IntFunction = FutureOr<int> Function(String sql,
    [List<Object?> paramters]);
typedef ListMapFunction = FutureOr<List<Map<String, Object?>>>
    Function(String sql, [List<Object?> paramters]);
typedef Execute = FutureOr<void> Function(String sql,
    [List<Object?> paramters]);
typedef PrePareFunction = NopPrepare Function(String sql,
    {bool persistent, bool vtab, bool checkNoTail});

abstract class NopDatabase {
  NopDatabase(this.path);
  final String path;

  static const memory = ':memory:';
  FutureOr<void> execute(String sql, [List<Object?> parameters = const []]);
  FutureOr<List<Map<String, Object?>>> rawQuery(String sql,
      [List<Object?> parameters = const []]);
  FutureOr<int> rawUpdate(String sql, [List<Object?> parameters = const []]);
  FutureOr<int> rawDelete(String sql, [List<Object?> parameters = const []]);
  FutureOr<int> rawInsert(String sql, [List<Object?> parameters = const []]);
  NopPrepare prepare(String sql,
      {bool persistent = false, bool vtab = true, bool checkNoTail = false});
  FutureOr<void> disposeNop() {}
}

abstract class NopPrepare {
  const NopPrepare();
  FutureOr<void> execute([List<Object?> parameters = const []]);
  FutureOr<List<Map<String, Object?>>> rawQuery(
      [List<Object?> parameters = const []]);
  FutureOr<int> rawUpdate([List<Object?> parameters = const []]);
  FutureOr<int> rawDelete([List<Object?> parameters = const []]);
  FutureOr<int> rawInsert([List<Object?> parameters = const []]);
  FutureOr<void> dispose();
}

class NopPrepareUnImpl extends NopPrepare {
  const NopPrepareUnImpl();
  @override
  FutureOr<void> dispose() {
    throw UnimplementedError();
  }

  @override
  FutureOr<void> execute([List<Object?> parameters = const []]) {
    throw UnimplementedError();
  }

  @override
  FutureOr<int> rawDelete([List<Object?> parameters = const []]) {
    throw UnimplementedError();
  }

  @override
  FutureOr<int> rawInsert([List<Object?> parameters = const []]) {
    throw UnimplementedError();
  }

  @override
  FutureOr<List<Map<String, Object?>>> rawQuery(
      [List<Object?> parameters = const []]) {
    throw UnimplementedError();
  }

  @override
  FutureOr<int> rawUpdate([List<Object?> parameters = const []]) {
    throw UnimplementedError();
  }
}
