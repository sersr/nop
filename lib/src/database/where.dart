import 'expr.dart';
import 'empty_database.dart';
import 'statement.dart';
import 'table.dart';

class Order<D extends DatabaseTable<Table, D>>
    with
        ItemExtension<D>,
        JoinItem<EmptyDatabaseTable>,
        Expr<D, EmptyDatabaseTable, Order<D>> {
  Order(this.table);
  @override
  final D table;

  @override
  Order<D> get back => this;
}

class Index<D extends DatabaseTable<Table, D>>
    with
        ItemExtension<D>,
        JoinItem<EmptyDatabaseTable>,
        Expr<D, EmptyDatabaseTable, Index<D>> {
  Index(this.table);
  @override
  final D table;

  IndexedByExpr<D, EmptyDatabaseTable, Index<D>> by(Object arg) {
    assert(!_not);
    final _current = current;
    if (_current is IndexedByExpr<D, EmptyDatabaseTable, Index<D>>) {
      return _current;
    }
    return nextExpr =
        IndexedByExpr<D, EmptyDatabaseTable, Index<D>>(cacheItem, arg);
  }

  bool _not = false;
  Index<D> get notIndexed {
    _not = true;
    return this;
  }

  @override
  String toString() {
    return '${_not ? ' NOT INDEXED' : ''}$nextString';
  }

  @override
  Index<D> get back => this;
}

class Where<D extends DatabaseTable<Table, D>,
        J extends DatabaseTable<Table, J>, S extends Statement<D, S>>
    with JoinItem<J>, ItemExtension<D>, Expr<D, J, Where<D, J, S>> {
  Where(this.table, this.s);

  final S s;

  @override
  final D table;

  @override
  Where<D, J, S> get back => this;

  @override
  List<Object?>? get args => _args ?? super.args;

  List<Object?>? _args;

  Where<D, J, S> coverWith(Iterable v) {
    if (_args != null && args?.length != _args!.length) {
      throw '$args : $_args';
    }
    _args = v.toList();
    return this;
  }

  SelectExpr<D, J, Where<D, J, S>>? _select;

  SelectExpr<D, J, Where<D, J, S>> get select {
    assert(s is QueryStatement);
    return _select ??=
        SelectExpr<D, J, Where<D, J, S>>(s as QueryStatement, this);
  }

  @override
  Set<String> get updateItems =>
      {...?_select?.updateItems, ...super.updateItems};
  @override
  String toString() {
    final _s = super.toString();
    if (_s.isEmpty) return '';
    return ' WHERE${super.toString()}';
  }

  S get whereEnd => s;
}

class JoinType {
  const JoinType(this.name);
  final String name;
  static const cross = JoinType('CROSS');
  static const inner = JoinType('INNER');
  static const natural = JoinType('NATURAL');
  static const outer = JoinType('LEFT OUTER');
}

mixin JoinItem<D extends DatabaseTable<Table, D>> {
  D get joinTable;

  JoinItem joinItem(String v);
  JoinItem get joinAll => joinItem('*');

  String joinTableString(String v) => '${joinTable.table}.$v';
}

class Join<T extends Table, D extends DatabaseTable<T, D>,
        J extends DatabaseTable<Table, J>>
    with JoinItem<J>, ItemExtension<D>, Expr<D, J, Join<T, D, J>> {
  Join(this.table, this._joinType, this.joinTable, this._queryStatement);
  @override
  final D table;
  @override
  final J joinTable;

  final JoinType _joinType;
  final QueryStatement<T, D> _queryStatement;

  @override
  Set<DatabaseTable>? get tables => {joinTable, ...?super.tables};

  @override
  Set<String> get updateItems =>
      {...?_select?.updateItems, ...super.updateItems};

  QueryStatement<T, D> get joinEnd => _queryStatement;

  SelectExpr<D, J, Join<T, D, J>>? _select;

  SelectExpr<D, J, Join<T, D, J>> get select {
    return _select ??= SelectExpr<D, J, Join<T, D, J>>(_queryStatement, this);
  }

  @override
  List<Object?>? get args => _args ?? super.args;

  List<Object?>? _args;
  Join<T, D, J> coverWith(Iterable v) {
    if (_args != null && args?.length != _args!.length) {
      throw '$args : $_args';
    }
    _args = v.toList();
    return this;
  }

  @override
  String toString() {
    return ' ${_joinType.name} JOIN ${joinTable.table}${super.toString()}';
  }
}

/// select 语句
///
/// 可使用 [Expr]:
/// [BuiltInFuncExpr], sql内置函数可以在 select 语句中使用
/// 其他 [Expr] 不能在 [SelectExpr] 中使用
/// [E] 必须是 [JoinItem], [ItemExtension] 的实现
class SelectExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    E> extends ExprBase<D, J, SelectExpr<D, J, E>> {
  SelectExpr(this._queryStatement, this.e);

  final E e;
  final QueryStatement _queryStatement;

  var _end = false;
  final _updateItems = <String>{};

  @override
  Set<String> get updateItems => {..._updateItems, ...super.updateItems};

  @override
  void backRun() {
    if (_end) return;
    assert(nextExpr is BuiltInFuncExpr);
    if (nextExpr != null) {
      _queryStatement.write(nextExpr.toString());
      _updateItems.addAll(nextExpr!.updateItems);
    }
    // nextExpr: setter 会自动寻找最下层的 Expr,即 nextExpr = null 永远无效
    rawNextExpr = null;
  }

  SelectExpr<D, J, E> get finish {
    _end = true;
    return this;
  }

  SelectExpr<D, J, E> as(String v) {
    _queryStatement.as(v);
    return this;
  }

  @override
  SelectExpr<D, J, E> joinItem(String v) {
    _queryStatement.write(joinTableString(v));
    return this;
  }

  @override
  SelectExpr<D, J, E> item(String v) {
    _queryStatement.write(tableString(v));
    return this;
  }

  E get selectEnd => e;

  @override
  J get joinTable => (e as JoinItem).joinTable as J;

  @override
  D get table => (e as ItemExtension).table as D;
}
