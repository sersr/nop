import 'empty_database.dart';
import 'statement.dart';
import 'table.dart';
import 'where.dart';

mixin Expr<D extends DatabaseTable<Table, D>, J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> on JoinItem<J>, ItemExtension<D> {
  @override
  D get table => _lastExpr!.table as D;
  @override
  Expr<D, J, L> get joinAll => joinItem('*');
  @override
  Expr<D, J, L> get all => item('*');

  Set<String> get updateItems => _nextExpr?.updateItems ?? {};

  Set<DatabaseTable>? get tables => _nextExpr?.tables;

  bool compare(Expr other) => _nextExpr?.compare(other) ?? false;
  @override
  J get joinTable => _lastExpr!.joinTable as J;

  Expr? _lastExpr;
  Expr? get lastExpr => _lastExpr;

  // 表达式的项
  Object? _cacheItem;

  Object? get cacheItem {
    final _current = current;
    final _currentItem = _current._cacheItem ?? _cacheItem;
    _current._cacheItem = _cacheItem = null;
    return _currentItem;
  }

  set cacheItem(Object? v) {
    final _current = current;
    if (_current == this) {
      _current._cacheItem = v;
    } else {
      _current.cacheItem = v;
    }
  }

  String get currentDesc => '';

  Expr? _nextExpr;
  Expr? get nextExpr => _nextExpr;

  List<Object?>? get args => nextExpr?.args;
  List<Object?> get allArgs => args ?? const [];

  @override
  String toString() => nextString;
  Expr get current {
    var _l = _nextExpr;
    while (_l != null) {
      if (_l._nextExpr == null) return _l;
      _l = _l._nextExpr;
    }
    return this;
  }

  set rawNextExpr(Expr? v) {
    _nextExpr = v;
  }

  set nextExpr(Expr? v) {
    final _current = current;
    _current._nextExpr = v;
    _current._nextExpr?._lastExpr = _current;
  }

  String get nextString => nextExpr == null ? '' : ' $nextExpr';

  @override
  Expr<D, J, L> item(String v) {
    cacheItem = tableString(v);
    return this;
  }

  @override
  Expr<D, J, L> joinItem(String v) {
    // _lastExpr!.joinItem(v);
    cacheItem = joinTableString(v);
    return this;
  }
  // Expr<D, J, L> coverWith(Iterable v) {
  //   final i = itemIterator;
  //   final iv = v.iterator;

  //   while (i.moveNext()) {
  //     if (!iv.moveNext())
  //       throw ItemIteratorExcption(
  //           '$args, cover: $v\n可能不是在第一个对象上调用.\n由当前对象为[root]往下遍历');

  //     final _current = i.current;
  //     assert(() {
  //       print('Item: $_current');
  //       return true;
  //     }());
  //     final _vCurrent = iv.current;
  //     _current.withValue(_vCurrent);
  //   }

  //   return this;
  // }

  // IteratorItemExpr<D, J, L, Expr<D, J, L>> get iterator =>
  //     IteratorItemExpr<D, J, L, Expr<D, J, L>>(this);
  // IteratorItemExpr<D, J, L, ItemExpr<D, J, L>> get itemIterator =>
  //     IteratorItemExpr<D, J, L, ItemExpr<D, J, L>>(this);

  CompareExpr<D, J, L> _compare(_Compare _compare, [Object? v]) {
    // assert(_cacheItem != null);
    final _current = current;
    if (_current is CompareExpr<D, J, L>) return _current;
    return nextExpr = CompareExpr<D, J, L>(_compare, cacheItem!, v);
  }

  CompareExpr<D, J, L> lessThan(Object v) => _compare(_Compare.lessThan, v);

  CompareExpr<D, J, L> lessThanOrEqualTo(Object v) =>
      _compare(_Compare.lessThanOrEqualTo, v);

  CompareExpr<D, J, L> equalTo(Object v) => _compare(_Compare.equalTo, v);

  CompareExpr<D, J, L> notEqualTo(Object v) => _compare(_Compare.notEqualTo, v);

  CompareExpr<D, J, L> greateThanOrEqualTo(Object v) =>
      _compare(_Compare.greateThanOrEqualTo, v);

  CompareExpr<D, J, L> greateThan(Object v) => _compare(_Compare.greateThan, v);

  CompareExpr<D, J, L> get lt => _compare(_Compare.lessThan);

  CompareExpr<D, J, L> get le => _compare(_Compare.lessThanOrEqualTo);

  CompareExpr<D, J, L> get eq => _compare(_Compare.equalTo);

  CompareExpr<D, J, L> get ne => _compare(_Compare.notEqualTo);

  CompareExpr<D, J, L> get ge => _compare(_Compare.greateThanOrEqualTo);

  CompareExpr<D, J, L> get gt => _compare(_Compare.greateThan);

  AndExpr<D, J, L> get and {
    final _current = current;
    if (_current is AndExpr<D, J, L>) return _current;
    return nextExpr = AndExpr<D, J, L>();
  }

  OrExpr<D, J, L> get or {
    final _current = current;
    if (_current is OrExpr<D, J, L>) return _current;
    return nextExpr = OrExpr<D, J, L>();
  }

  WhereExpr<D, J, L> get where {
    final _current = current;
    if (_current is WhereExpr<D, J, L>) return _current;
    return nextExpr = WhereExpr<D, J, L>();
  }

  ByExpr<D, J, L> _by(By by) {
    final _current = current;
    if (_current is ByExpr<D, J, L>) return _current;
    return nextExpr = ByExpr<D, J, L>(by);
  }

  ByExpr<D, J, L> get orderBy => _by(By.orderBy());
  ByExpr<D, J, L> get groupBy => _by(By.groupBy());

  LimitExpr<D, J, L> get limit {
    final _current = current;
    if (_current is LimitExpr<D, J, L>) return _current;
    return nextExpr = LimitExpr<D, J, L>();
  }

  HavingExpr<D, J, L> get having {
    final _current = current;
    if (_current is HavingExpr<D, J, L>) return _current;
    return nextExpr = HavingExpr<D, J, L>();
  }

  PriorityExpr<D, J, L> get priority {
    final _current = current;
    if (_current is PriorityExpr<D, J, L>) return _current;

    return nextExpr = PriorityExpr<D, J, L>();
  }

  // Decrease Priority
  Expr<D, J, L> get out {
    final _current = current;
    if (_current is PriorityBaseExpr) {
      _current.backRun();
      return this;
    }
    Expr? _la = _current;

    while (_la != null && _la is! PriorityBaseExpr) {
      _la = _la._lastExpr;
    }

    if (_la is PriorityBaseExpr) _la.backRun();
    return this;
  }

  LikeExpr<D, J, L> like(Object arg) {
    final _current = current;
    if (_current is LikeExpr<D, J, L>) return _current;
    return nextExpr = LikeExpr<D, J, L>(cacheItem!, arg);
  }

  QueryExpr<D, J, L> query(QueryStatement q) {
    final _current = current;
    if (_current is QueryExpr<D, J, L>) return _current;
    return nextExpr = QueryExpr<D, J, L>(q);
  }

  UsingExpr<D, J, L> get using {
    final _current = current;
    if (_current is UsingExpr<D, J, L>) return _current;
    return nextExpr = UsingExpr<D, J, L>();
  }

  OnExpr<D, J, L> get on {
    final _current = current;
    if (_current is OnExpr<D, J, L>) return _current;

    return nextExpr = OnExpr<D, J, L>();
  }

  GlobExpr<D, J, L> glob(Object arg) {
    final _current = current;
    if (_current is GlobExpr<D, J, L>) return _current;
    return nextExpr = GlobExpr<D, J, L>(cacheItem!, arg);
  }

  IsExpr<D, J, L> get is_ {
    final _current = current;
    if (_current is IsExpr<D, J, L>) return _current;
    return nextExpr = IsExpr<D, J, L>(cacheItem);
  }

  NotExpr<D, J, L> get not {
    final _current = current;
    if (_current is NotExpr<D, J, L>) return _current;
    return nextExpr = NotExpr<D, J, L>(cacheItem);
  }

  NullExpr<D, J, L> get null_ {
    final _current = current;
    if (_current is NullExpr<D, J, L>) return _current;
    return nextExpr = NullExpr<D, J, L>(cacheItem);
  }

  IsNullExpr<D, J, L> get isNull {
    final _current = current;
    if (_current is IsNullExpr<D, J, L>) return _current;
    return nextExpr = IsNullExpr<D, J, L>(cacheItem);
  }

  IsNotNullExpr<D, J, L> get isNotNull {
    final _current = current;
    if (_current is IsNotNullExpr<D, J, L>) return _current;
    return nextExpr = IsNotNullExpr<D, J, L>(cacheItem!);
  }

  InExpr<D, J, L> get in_ {
    final _current = current;
    if (_current is InExpr<D, J, L>) return _current;
    return nextExpr = InExpr<D, J, L>(cacheItem);
  }

  ExistsExpr<D, J, L> get exists {
    final _current = current;
    if (_current is ExistsExpr<D, J, L>) return _current;
    return nextExpr = ExistsExpr<D, J, L>();
  }

  ExistsExpr<D, J, L> get union {
    final _current = current;
    if (_current is ExistsExpr<D, J, L>) return _current;
    return nextExpr = ExistsExpr<D, J, L>();
  }

  IntersectExpr<D, J, L> get intersect {
    final _current = current;
    if (_current is IntersectExpr<D, J, L>) return _current;
    return nextExpr = IntersectExpr<D, J, L>();
  }

  ExceptExpr<D, J, L> get except {
    final _current = current;
    if (_current is ExceptExpr<D, J, L>) return _current;
    return nextExpr = ExceptExpr<D, J, L>();
  }

  BetweenExpr<D, J, L> get btw {
    final _current = current;
    if (_current is BetweenExpr<D, J, L>) return _current;
    return nextExpr = BetweenExpr<D, J, L>(cacheItem);
  }

  /// 返回到上一级，并执行 [backRun] 操作
  L get back {
    var _la = _lastExpr;
    if (_la is L) return _la..backRun();
    while (_la != null) {
      _la = _la._lastExpr;
      if (_la is L) {
        return _la..backRun();
      }
    }
    // 一般为根节点
    return this as L;
  }

  L get push => back;

  void backRun() {}

  BuiltInFuncExpr<D, J, L> _builtFun(BuiltInFunction function) {
    final _current = current;
    if (_current is BuiltInFuncExpr<D, J, L>) return _current;

    return nextExpr = BuiltInFuncExpr<D, J, L>(function);
  }

  //Scalar
  BuiltInFuncExpr<D, J, L> get sqliteVersion =>
      _builtFun(const BuiltInFunction.sqliteVersion());
  BuiltInFuncExpr<D, J, L> get random =>
      _builtFun(const BuiltInFunction.random());
  BuiltInFuncExpr<D, J, L> get abs => _builtFun(const BuiltInFunction.abs());
  BuiltInFuncExpr<D, J, L> get upper =>
      _builtFun(const BuiltInFunction.upper());
  BuiltInFuncExpr<D, J, L> get lower =>
      _builtFun(const BuiltInFunction.lower());
  BuiltInFuncExpr<D, J, L> get length =>
      _builtFun(const BuiltInFunction.length());

  // aggregate
  BuiltInFuncExpr<D, J, L> get avg => _builtFun(const BuiltInFunction.avg());
  BuiltInFuncExpr<D, J, L> get count =>
      _builtFun(const BuiltInFunction.count());
  // ignore: non_constant_identifier_names
  BuiltInFuncExpr<D, J, L> get group_concat =>
      _builtFun(const BuiltInFunction.group_concat());
  BuiltInFuncExpr<D, J, L> get max => _builtFun(const BuiltInFunction.max());
  BuiltInFuncExpr<D, J, L> get min => _builtFun(const BuiltInFunction.min());
  BuiltInFuncExpr<D, J, L> get sum => _builtFun(const BuiltInFunction.sum());
  BuiltInFuncExpr<D, J, L> get total =>
      _builtFun(const BuiltInFunction.total());

  Expr<D, J, L> let(void Function(Expr<D, J, L> exp) o) {
    o(this);
    return this;
  }

  Expr<D, J, L> operator [](void Function(Expr<D, J, L> exp) o) => let(o);
}

abstract class ExprBase<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> with JoinItem<J>, ItemExtension<D>, Expr<D, J, L> {
  ExprBase();
  final _updateItems = <String>{};

  @override
  Set<String> get updateItems => {..._updateItems, ...super.updateItems};
}

// 替换继承信息
class PriorityBaseExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>,
    S extends PriorityBaseExpr<D, J, L, S>> extends ExprBase<D, J, S> {
  L get endl {
    return _lastExpr as L;
  }

  Expr? _currentExpr;

  @override
  void backRun() {
    if (_currentExpr != null) return;

    _currentExpr = _nextExpr;
    rawNextExpr = null;
  }

  Expr? get currentExpr => _currentExpr;

  @override
  List<Object?>? get args => [...?_currentExpr?.args, ...?super.args];
  @override
  Set<String> get updateItems =>
      {...?_currentExpr?.updateItems, ...super.updateItems};

  String get priString =>
      '(${currentExpr ?? nextExpr})${currentExpr == null ? '' : nextString}';
}

class AndExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ExprBase<D, J, L> {
  AndExpr();
  @override
  String toString() => 'AND$nextString';
}

class OrExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ExprBase<D, J, L> {
  OrExpr();
  @override
  String toString() => 'OR$nextString';
}

class WhereExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ExprBase<D, J, L> {
  WhereExpr();
  @override
  String toString() => 'WHERE$nextString';
}

class ByExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ExprBase<D, J, ByExpr<D, J, L>> {
  ByExpr(this._byType);
  final By _byType;
  final _values = <String>{};

  @override
  ByExpr<D, J, L> joinItem(String v) {
    _values.add(joinTableString(v));
    return this;
  }

  @override
  ByExpr<D, J, L> item(String v) {
    _values.add(tableString(v));
    return this;
  }

  String _e = '';
  ByExpr<D, J, L> get asc {
    _e = ' ASC';
    return this;
  }

  ByExpr<D, J, L> get desc {
    _e = ' DESC';
    return this;
  }

  L get orderEnd => lastExpr as L;

  @override
  String toString() => '${_byType.name}${_values.join(',')}$_e$nextString';
}

class By {
  By(this.name);
  final String name;
  By.groupBy() : name = 'GROUP BY ';
  By.orderBy() : name = 'ORDER BY ';
}

class IsExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ItemExpr<D, J, L> {
  IsExpr(Object? currentItem) : super(currentItem);

  @override
  String get type => 'IS';
}

class IsNullExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ItemExpr<D, J, L> {
  IsNullExpr(Object? currentItem) : super(currentItem);

  @override
  String get type => 'IS NULL';
}

class NotExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ItemExpr<D, J, L> {
  NotExpr(Object? currentItem) : super(currentItem);

  @override
  String get type => 'NOT';
}

class HavingExpr<D extends DatabaseTable<Table, D>,
        J extends DatabaseTable<Table, J>, L extends Expr<D, J, L>>
    extends PriorityBaseExpr<D, J, L, HavingExpr<D, J, L>> {
  HavingExpr();

  @override
  String toString() {
    return 'HAVING ${currentExpr ?? nextExpr}${currentExpr == null ? '' : nextString}';
  }
}

class IsNotNullExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ItemExpr<D, J, L> {
  IsNotNullExpr(Object? currentItem) : super(currentItem);

  @override
  String get type => 'IS NOT NULL';
}

class NullExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ItemExpr<D, J, L> {
  NullExpr(Object? currentItem) : super(currentItem);

  @override
  String get type => 'NULL';
}

class InExpr<D extends DatabaseTable<Table, D>,
        J extends DatabaseTable<Table, J>, L extends Expr<D, J, L>>
    extends PriorityBaseExpr<D, J, L, InExpr<D, J, L>> {
  InExpr(this._currentItem);
  final Object? _currentItem;
  List? _v;

  InExpr<D, J, L> withValue(List? v) {
    _v = v;
    return this;
  }

  String get getList {
    if (_v != null) {
      return _v!.map((e) => '?').join(',');
    }
    return '';
  }

  @override
  List<Object?> get args => [...?_v, ...?super.args];
  @override
  String toString() {
    if (_v == null || _v!.isEmpty) {
      return '$_currentItem IN $priString';
    } else {
      return '$_currentItem IN ($getList)$nextString';
    }
  }
}

class IndexedByExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ItemExpr<D, J, L> {
  IndexedByExpr(Object? _currentItem, [Object? _v]) : super(_currentItem, _v);

  String get rightValue => _v == null ? '' : '$_v';
  @override
  String toString() {
    return '$type$rightValue';
  }

  @override
  final type = 'INDEXED BY ';
}

class ExistsExpr<D extends DatabaseTable<Table, D>,
        J extends DatabaseTable<Table, J>, L extends Expr<D, J, L>>
    extends PriorityBaseExpr<D, J, L, ExistsExpr<D, J, L>> {
  ExistsExpr();

  @override
  String toString() => 'EXISTS $priString';
}

class UnionExpr<D extends DatabaseTable<Table, D>,
        J extends DatabaseTable<Table, J>, L extends Expr<D, J, L>>
    extends PriorityBaseExpr<D, J, L, UnionExpr<D, J, L>> {
  UnionExpr();

  String _v = '';
  @override
  UnionExpr<D, J, L> get all {
    _v = ' ALL';
    return this;
  }

  @override
  String toString() => 'UNION$_v $priString';
}

class ExceptExpr<D extends DatabaseTable<Table, D>,
        J extends DatabaseTable<Table, J>, L extends Expr<D, J, L>>
    extends PriorityBaseExpr<D, J, L, ExceptExpr<D, J, L>> {
  ExceptExpr();

  @override
  String toString() => 'EXCEPT $priString';
}

class IntersectExpr<D extends DatabaseTable<Table, D>,
        J extends DatabaseTable<Table, J>, L extends Expr<D, J, L>>
    extends PriorityBaseExpr<D, J, L, IntersectExpr<D, J, L>> {
  IntersectExpr();

  @override
  String toString() => 'INTERSECT $priString';
}

class PriorityExpr<D extends DatabaseTable<Table, D>,
        J extends DatabaseTable<Table, J>, L extends Expr<D, J, L>>
    extends PriorityBaseExpr<D, J, L, PriorityExpr<D, J, L>> {
  PriorityExpr();

  @override
  String toString() => priString;
}

enum _Compare {
  lessThan,
  lessThanOrEqualTo,
  equalTo,
  notEqualTo,
  greateThanOrEqualTo,
  greateThan,
}

abstract class ItemExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ExprBase<D, J, L> {
  ItemExpr([this._currentItem, this._v]);
  Object? _v;
  final Object? _currentItem;

  @override
  List<Object?> get args => [if (_v != null) _v, ...?super.args];
  // @override
  // Set<String> get updateItems =>
  //     {if (_v == null) ..._values, ...super.updateItems};
  ItemExpr<D, J, L> withValue(Object? v) {
    _v = v;
    return this;
  }

  final _values = <String>{};

  @override
  ItemExpr<D, J, L> joinItem(String v) {
    _values.add(joinTableString(v));
    return this;
  }

  @override
  ItemExpr<D, J, L> item(String v) {
    _values.add(tableString(v));
    return this;
  }

  String get _rightValue => _v != null ? '?' : _values.join(',');
  abstract final String type;
  String get currentItemString => _currentItem == null ? '' : '$_currentItem ';
  @override
  String get currentDesc => '$currentItemString$type$_rightValue';

  @override
  String toString() => '$currentDesc$nextString';
}

class QueryExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ExprBase<D, J, L> {
  QueryExpr(this._queryStatement);
  final QueryStatement _queryStatement;

  @override
  Set<DatabaseTable>? get tables =>
      {..._queryStatement.tables, ...?super.tables};

  @override
  List<Object?>? get args => [..._queryStatement.args, ...?super.args];
  @override
  Set<String> get updateItems =>
      {..._queryStatement.updateItems, ...super.updateItems};

  @override
  String toString() => _queryStatement.sql;
}

class CompareExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ItemExpr<D, J, L> {
  CompareExpr(this._compareType, Object _currentItem, [Object? _v])
      : super(_currentItem, _v);

  final _Compare _compareType;

  String get _compareString {
    switch (_compareType) {
      case _Compare.lessThan:
        return '< ';
      case _Compare.lessThanOrEqualTo:
        return '<= ';
      case _Compare.equalTo:
        return '= ';
      case _Compare.notEqualTo:
        return '!= ';
      case _Compare.greateThanOrEqualTo:
        return '>= ';
      case _Compare.greateThan:
        return '> ';
      default:
        return '';
    }
  }

  @override
  late final type = _compareString;

  @override
  bool compare(Expr other) {
    return super.compare(other);
  }
}

class LikeExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ItemExpr<D, J, L> {
  LikeExpr(Object _currentItem, [Object? _v]) : super(_currentItem, _v);
  @override
  final type = 'LIKE ';
}

class UsingExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ExprBase<D, J, L> {
  UsingExpr();

  final _items = <String>[];

  @override
  UsingExpr<D, J, L> item(String v) {
    _items.add(v);
    _updateItems
      ..add(tableString(v))
      ..add(joinTableString(v));
    return this;
  }

  @override
  UsingExpr<D, J, L> joinItem(String v) {
    _items.add(v);
    _updateItems
      ..add(tableString(v))
      ..add(joinTableString(v));
    return this;
  }

  @override
  String toString() {
    return 'USING (${_items.join(',')})$nextString';
  }
}

class OnExpr<D extends DatabaseTable<Table, D>,
        J extends DatabaseTable<Table, J>, L extends Expr<D, J, L>>
    extends PriorityBaseExpr<D, J, L, OnExpr<D, J, L>> {
  OnExpr();
  @override
  String toString() => 'ON $priString';
}

class GlobExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ItemExpr<D, J, L> {
  GlobExpr(Object _currentItem, [Object? _v]) : super(_currentItem, _v);
  @override
  final type = 'GLOB ';
}

class BetweenExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ExprBase<D, J, L> {
  BetweenExpr(this._currentItem);
  final Object? _currentItem;
  Expr? _btw;

  BetweenAndExpr<D, J, L> get btwAnd {
    if (nextExpr != null) {
      _btw = nextExpr;
      nextExpr = null;
    }
    return nextExpr = BetweenAndExpr<D, J, L>();
  }

  String get _btwString => _btw?.toString() ?? ' ? ';

  Object? _v;
  BetweenExpr<D, J, L> withValue(Object v) {
    _v = v;
    return this;
  }

  String get _currentFmt {
    return _currentItem == null ? '' : '$_currentItem ';
  }

  @override
  List<Object?> get args =>
      [if (_v != null && _btw == null) _v, ...?super.args];

  @override
  String toString() => '${_currentFmt}BETWEEN$_btwString$nextString';
}

class BetweenAndExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ExprBase<D, J, L> {
  BetweenAndExpr();
  String get _andString => _and?.toString() ?? ' ? ';

  Expr? _and;
  BetweenAndExpr<D, J, L> andEnd() {
    _and = nextExpr;
    nextExpr = null;
    return this;
  }

  Object? _v;
  BetweenAndExpr<D, J, L> withValue(Object v) {
    _v = v;
    return this;
  }

  @override
  List<Object?> get args =>
      [if (_v != null && _and == null) _v, ...?super.args];
  @override
  String toString() => 'AND$_andString$nextString';
}

class LimitExpr<D extends DatabaseTable<Table, D>,
        J extends DatabaseTable<Table, J>, L extends Expr<D, J, L>>
    extends PriorityBaseExpr<D, J, L, LimitExpr<D, J, L>> {
  LimitExpr();
  Object? _v;

  LimitExpr<D, J, L> withValue(Object? v) {
    _v = v;
    return this;
  }

  Object? _offset;
  LimitExpr<D, J, L> offset(Object? v) {
    _offset = v;
    return this;
  }

  String get _offsetString => _offset == null ? '' : ' OFFSET $_offset';
  @override
  String toString() =>
      'LIMIT ${_v == null ? '${currentExpr ?? nextExpr}' : '$_v'}$_offsetString'
      '${currentExpr == null && _v == null ? '' : nextString}';
}

class BuiltInFuncExpr<
    D extends DatabaseTable<Table, D>,
    J extends DatabaseTable<Table, J>,
    L extends Expr<D, J, L>> extends ExprBase<D, J, L> {
  BuiltInFuncExpr(this._builtFunction);
  final _values = <String>{};
  final BuiltInFunction _builtFunction;

  @override
  set cacheItem(Object? v) {
    if (v == null) return;
    final _current = current;
    if (_current == this) {
      final _s = v.toString();
      final _v = _s.split('.');
      final _all = _v.length >= 2 && _v[1] == '*';
      _values.add(_all ? '*' : _s);
      _updateItems.add(_s);
      if (_all && J != EmptyDatabaseTable) {
        final _tableName = _v[0] == table.table ? joinTable.table : table.table;
        _updateItems.add('$_tableName.${_v[1]}');
      }
    } else {
      _current.cacheItem = v;
    }
  }

  @override
  BuiltInFuncExpr<D, J, L> joinItem(String v) {
    super.joinItem(v);
    return this;
  }

  @override
  BuiltInFuncExpr<D, J, L> item(String v) {
    super.item(v);
    return this;
  }

  BuiltInFuncExpr<D, J, L> withValue(Object v) {
    _values.add('$v');
    return this;
  }

  @override
  String get currentDesc => '${_builtFunction.name}(${_values.join(',')})';
  @override
  String toString() => '$currentDesc$nextString';
}

class BuiltInFunction {
  const BuiltInFunction(this.name);
  final String name;
  const BuiltInFunction.abs() : name = 'abs';
  const BuiltInFunction.upper() : name = 'upper';
  const BuiltInFunction.lower() : name = 'lower';
  const BuiltInFunction.length() : name = 'length';
  const BuiltInFunction.sqliteVersion() : name = 'sqlite_version';
  const BuiltInFunction.random() : name = 'random';
  const BuiltInFunction.round() : name = 'round';
  //aggregate
  const BuiltInFunction.avg() : name = 'AVG';
  const BuiltInFunction.count() : name = 'COUNT';
  // ignore: non_constant_identifier_names
  const BuiltInFunction.group_concat() : name = 'GROUP_CONCAT';
  const BuiltInFunction.max() : name = 'MAX';
  const BuiltInFunction.min() : name = 'MIN';
  const BuiltInFunction.sum() : name = 'SUM';
  const BuiltInFunction.total() : name = 'TOTAL';
}
