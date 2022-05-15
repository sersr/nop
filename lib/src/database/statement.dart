import 'dart:async';

import '../../utils.dart';
import 'empty_database.dart';
import 'gen_database.dart';
import 'nop_db.dart';
import 'table.dart';
import 'watcher.dart';
import 'where.dart';

mixin ItemExtension<D extends DatabaseTable<Table, D>> {
  D get table;
  ItemExtension item(String v);
  ItemExtension get all => item('*');

  String tableString(String v) => '${table.table}.$v';
}

abstract class ItemExtensionSuper<D extends DatabaseTable<Table, D>,
    S extends ItemExtensionSuper<D, S>> with ItemExtension<D> {
  ItemExtensionSuper(this.table, this.db);
  final $Database db;
  @override
  final D table;
}

abstract class Statement<D extends DatabaseTable<Table, D>,
    S extends Statement<D, S>> extends ItemExtensionSuper<D, S> {
  Statement(D table, $Database db) : super(table, db);
  final _args = <Object?>[];
  late final _tables = <DatabaseTable>{table};

  List<Object?> get args => [..._args, ...?_where?.allArgs];
  Set<DatabaseTable> get tables => {..._tables, ...?_where?.tables};

  Where<D, EmptyDatabaseTable, S>? _where;
  Where<D, EmptyDatabaseTable, S> get where =>
      _where ??= Where<D, EmptyDatabaseTable, S>(table, this as S);
  set where(Where<D, EmptyDatabaseTable, S> w) {
    _where = w;
  }

  S operator [](void Function(Where<D, EmptyDatabaseTable, S> where) o) {
    o(where);
    return this as S;
  }

  @override
  S item(String v) {
    _updateItems.add(v);
    return this as S;
  }

  S coverWith(Iterable v) {
    if (_where != null) {
      _where!.coverWith(v);
    }
    return this as S;
  }

  final _updateItems = <String>{};
  Set<String> get rawUpdateItems => _updateItems;
  Set<String> get updateItems {
    return {
      ..._updateItems.map((e) {
        final _sp = e.split('.');
        return '${_sp.length <= 1 ? '${table.table}.' : ''}$e';
      }),
      ...?_where?.updateItems
    };
  }

  S let(void Function(S s) s) {
    s(this as S);
    return this as S;
  }

  PrepareStatement<D, S> get prepare;

  String get sql;
  @override
  String toString() {
    return 'sql: "$sql", $args | tables: ${tables.map((e) => e.table).toList()} | updateItems: $updateItems';
  }

  FutureOr<int> notify(FutureOr<int> count) {
    if (count is Future<int>) {
      return count.then((value) {
        if (value > 0) {
          db.watcher.notifyListener(UpdateNotifyKey(tables, updateItems));
        }
        return value;
      });
    }

    if (count > 0) {
      db.watcher.notifyListener(UpdateNotifyKey(tables, updateItems));
    }

    return count;
  }
}

abstract class PrepareStatement<D extends DatabaseTable<Table, D>,
    S extends Statement<D, S>> extends Statement<D, S> {
  PrepareStatement(D table, $Database db, this.parent) : super(table, db) {
    try {
      _nopPrepare = db.prepare(sql);
    } catch (e) {
      Log.i(e);
    }
  }
  final S parent;
  NopPrepare _nopPrepare = const NopPrepareUnImpl();

  bool get supported => _nopPrepare is! NopPrepareUnImpl;

  @override
  List<Object?> get args => parent.args;
  @override
  Set<DatabaseTable> get tables => parent.tables;

  @override
  Where<D, EmptyDatabaseTable, S> get where => parent.where;
  @override
  S item(String v) => parent.item(v);

  @override
  Set<String> get rawUpdateItems => parent.rawUpdateItems;
  @override
  Set<String> get updateItems => parent.updateItems;

  @override
  S coverWith(Iterable v) {
    parent.coverWith(v);
    return parent;
  }

  @override
  PrepareStatement<D, S> get prepare => this;
  @override
  String get sql => parent.sql;

  FutureOr<void> dispose() {
    if (supported) {
      return _nopPrepare.dispose();
    }
  }
}

class QueryPrepare<T extends Table, D extends DatabaseTable<T, D>>
    extends PrepareStatement<D, QueryStatement<T, D>> {
  QueryPrepare(D table, $Database db, QueryStatement<T, D> parent)
      : super(table, db, parent);

  FutureOr<List<Map<String, Object?>>> get go {
    if (supported) {
      return _nopPrepare.rawQuery(args);
    } else {
      return db.query(sql, args.transform);
    }
  }

  FutureOr<List<T>> get goToTable {
    final g = go;
    if (g is Future<List<Map<String, Object?>>>) {
      return g.then((value) => table.toTable(value));
    }
    return table.toTable(g);
  }

  Stream<List<T>> get watchToTable => watch.map((data) => table.toTable(data));

  Stream<List<Map<String, Object?>>> get watch {
    return db.watcher
        .add(QueryStreamKey(tables, updateItems, toString()), () => go)
        .stream;
  }
}

class UpdatePrepare<T extends Table, D extends DatabaseTable<T, D>>
    extends PrepareStatement<D, UpdateStatement<T, D>> {
  UpdatePrepare(D table, $Database db, UpdateStatement<T, D> parent)
      : super(table, db, parent);

  FutureOr<int> get go {
    if (supported) {
      return _nopPrepare.rawUpdate(args);
    } else {
      final count = db.update(sql, args.transform);
      return notify(count);
    }
  }
}

class DeletePrepare<T extends Table, D extends DatabaseTable<T, D>>
    extends PrepareStatement<D, DeleteStatement<T, D>> {
  DeletePrepare(D table, $Database db, DeleteStatement<T, D> parent)
      : super(table, db, parent);

  FutureOr<int> get go {
    if (supported) {
      return _nopPrepare.rawDelete(args);
    } else {
      final count = db.delete(sql, args.transform);
      return notify(count);
    }
  }
}

class InsertPrepare<T extends Table, D extends DatabaseTable<T, D>>
    extends PrepareStatement<D, InsertStatement<T, D>> {
  InsertPrepare(D table, $Database db, InsertStatement<T, D> parent)
      : super(table, db, parent);

  FutureOr<int> get go {
    if (supported) {
      return _nopPrepare.rawInsert(args);
    } else {
      final count = db.insert(sql, args.transform);
      return notify(count);
    }
  }
}

class QueryStatement<T extends Table, D extends DatabaseTable<T, D>>
    extends Statement<D, QueryStatement<T, D>> {
  QueryStatement(D table, $Database db) : super(table, db);
  final _buffer = StringBuffer();

  @override
  QueryStatement<T, D> get all => super.all as QueryStatement<T, D>;
  @override
  QueryStatement<T, D> item(String v) => tableItem(table, v);

  QueryStatement<T, D> tableItem(DatabaseTable updateTable, String v) {
    _div();
    _tables.add(updateTable);
    final _v = '${updateTable.table}.$v';
    _buffer.write(_v);

    if (updateTable == table) _updateItems.add(_v);

    return this;
  }

  void addUpdateItem(String u) {
    final _v = '${table.table}.$u';
    _updateItems.add(_v);
  }

  bool _distinct = false;
  QueryStatement<T, D> get distinct {
    _distinct = true;
    return this;
  }

  QueryStatement<T, D> as(String v) {
    _buffer.write(' AS $v');
    return this;
  }

  void write(Object v) {
    _div();
    _buffer.write(v);
  }

  void _div() {
    if (_buffer.isNotEmpty) _buffer.write(', ');
  }

  Index<D>? _index;
  Index<D> get index => _index ??= Index(table);
  Order<D>? _order;
  Order<D> get order => _order ??= Order(table);

  bool _joinFirst = false;
  Join<T, D, DatabaseTable>? _join;
  Join<T, D, A> _joinf<J extends Table, A extends DatabaseTable<J, A>>(
      JoinType type, A joinTable) {
    if (_join is Join<T, D, A>) return _join as Join<T, D, A>;
    if (_where == null) _joinFirst = true;
    return _join = Join<T, D, A>(table, type, joinTable, this);
  }

  Join<T, D, A> join<J extends Table, A extends DatabaseTable<J, A>>(
          A joinTable) =>
      _joinf(JoinType.inner, joinTable);

  Join<T, D, A> crossJoin<J extends Table, A extends DatabaseTable<J, A>>(
          A joinTable) =>
      _joinf(JoinType.cross, joinTable);

  Join<T, D, A> outerJoin<J extends Table, A extends DatabaseTable<J, A>>(
          A joinTable) =>
      _joinf(JoinType.outer, joinTable);

  Join<T, D, A> naturalJoin<J extends Table, A extends DatabaseTable<J, A>>(
          A joinTable) =>
      _joinf(JoinType.natural, joinTable);

  SelectExpr<D, EmptyDatabaseTable, QueryStatement<T, D>>? _select;

  SelectExpr<D, EmptyDatabaseTable, QueryStatement<T, D>> get select {
    return _select ??=
        SelectExpr<D, EmptyDatabaseTable, QueryStatement<T, D>>(this, this);
  }

  @override
  String get sql => 'SELECT${_distinct ? ' DISTINCT' : ''} '
      '$_getSelects'
      ' FROM ${table.table}'
      '${_index ?? ''}'
      '${_join ?? ''}${_where ?? ''}${_order ?? ''}';

  FutureOr<List<Map<String, Object?>>> get go {
    final query = db.query(sql, args.transform);

    return query;
  }

  FutureOr<List<T>> get goToTable {
    final g = go;
    if (g is Future<List<Map<String, Object?>>>) {
      return g.then((value) => table.toTable(value));
    }
    return table.toTable(g);
  }

  FutureOr<Iterable<S>> goMap<S>(S Function(T) map) {
    final g = go;
    if (g is Future<List<Map<String, Object?>>>) {
      return g.then((value) => table.toTable(value).map(map));
    }
    return table.toTable(g).map(map);
  }

  Stream<List<T>> get watchToTable => watch.map((data) => table.toTable(data));

  Stream<List<Map<String, Object?>>> get watch {
    return db.watcher
        .add(QueryStreamKey(tables, updateItems, toString()), () => go)
        .stream;
  }

  // 依赖处理
  @override
  List<Object?> get args {
    var firstArgs = _where?.allArgs;
    var secondArgs = _join?.allArgs;

    if (_joinFirst) {
      firstArgs = _join?.allArgs;
      secondArgs = _where?.allArgs;
    }

    return <Object?>[
      ..._args,
      ...?firstArgs,
      ...?secondArgs,
      ...?_order?.allArgs
    ];
  }

  /// select 都是实时的写入 [_buffer] 中
  String get _getSelects =>
      '${_buffer.isNotEmpty ? _buffer : '${table.table}.*'}';

  /// 而 updateItems 可能在其他位置设置了
  Set<String> get _getUpdateItems =>
      _buffer.isNotEmpty ? _updateItems : {'${table.table}.*'};

  @override
  Set<String> get updateItems {
    return {
      ..._getUpdateItems,
      ...?_select?.updateItems,
      ...?_join?.updateItems,
      ...?_where?.updateItems,
    };
  }

  @override
  Set<DatabaseTable> get tables =>
      {table, ...?_join?.tables, ...?_where?.tables};

  @override
  QueryPrepare<T, D> get prepare => QueryPrepare(table, db, this);
}

class UpdateStatement<T extends Table, D extends DatabaseTable<T, D>>
    extends Statement<D, UpdateStatement<T, D>> {
  UpdateStatement(D table, $Database db) : super(table, db);

  UpdateStatement<T, D> items(Iterable<String> v) {
    _updateItems.addAll(v);
    return this;
  }

  UpdateStatement<T, D> set(Object? v) {
    withArgs(v);
    return this;
  }

  void withArgs(Object? v) {
    if (v is Iterable) {
      _args.addAll(v);
    } else {
      _args.add(v);
    }
  }

  @override
  UpdateStatement<T, D> coverWith(Iterable v) {
    final _argsLength = _args.length;
    final vList = v.where((element) => element != null).toList();
    if (_args.isNotEmpty) {
      _args
        ..clear()
        ..addAll(vList.sublist(0, _argsLength));
    }
    return super.coverWith(vList.sublist(_argsLength));
  }

  UpdateStatement<T, D> updateTable(T _table) {
    final map = _table.toJson()..removeWhere((key, value) => value == null);
    _updateItems.addAll(map.keys);
    _args.addAll(map.values);

    return this;
  }

  @override
  String get sql {
    final _tableItems = _updateItems.map((e) => '$e = ?').join(', ');
    return 'UPDATE ${table.table} SET $_tableItems${_where ?? ''}';
  }

  FutureOr<int> get go {
    final count = db.update(sql, args.transform);
    return notify(count);
  }

  @override
  UpdatePrepare<T, D> get prepare => UpdatePrepare(table, db, this);
}

class InsertStatement<T extends Table, D extends DatabaseTable<T, D>>
    extends Statement<D, InsertStatement<T, D>> {
  InsertStatement(D table, $Database db) : super(table, db);

  InsertStatement<T, D> items(Iterable<String> v) {
    _updateItems.addAll(v);
    return this;
  }

  InsertStatement<T, D> insertTable(T _table, {bool removeNull = true}) {
    final map = _table.toJson();
    if (removeNull) {
      map.removeWhere((key, value) => value == null);
    }
    _updateItems.addAll(map.keys);
    _args.addAll(map.values);
    return this;
  }

  void addArgs(Object v) {
    if (v is Iterable) {
      _args.addAll(v);
    } else {
      _args.add(v);
    }
  }

  @override
  String get sql {
    final v = List.filled(_updateItems.length, '?').join(',');
    return 'INSERT INTO ${table.table} (${_updateItems.join(', ')}) VALUES($v)';
  }

  FutureOr<int> get go {
    final count = db.insert(sql, args.transform);
    return notify(count);
  }

  @override
  InsertPrepare<T, D> get prepare => InsertPrepare(table, db, this);
}

class DeleteStatement<T extends Table, D extends DatabaseTable<T, D>>
    extends Statement<D, DeleteStatement<T, D>> {
  DeleteStatement(D table, $Database db) : super(table, db);

  @override
  String get sql => 'DELETE FROM ${table.table}${_where ?? ''}';

  @override
  String toString() {
    final _args = _where?.args;
    return 'sql: "$sql", $_args';
  }

  DeleteStatement<T, D> deleteTable(T _table, {bool auto = true}) {
    final map = _table.toJson()..removeWhere((key, value) => value == null);
    map.forEach((key, value) => where.item(key).equalTo(value));
    if (auto) go;
    return this;
  }

  FutureOr<int> get go {
    final count = db.delete(sql, args.transform);
    return notify(count);
  }

  @override
  DeletePrepare<T, D> get prepare => DeletePrepare(table, db, this);
}

extension BoolListToint on Iterable {
  List get transform {
    return map((e) {
      if (e is bool) return Table.boolToInt(e);
      if (e is DateTime) return e.toString();
      return e;
    }).toList();
  }
}
