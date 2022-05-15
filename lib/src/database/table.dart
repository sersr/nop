import 'gen_database.dart';
import 'statement.dart';

abstract class Table {
  Table();
  Map<String, dynamic> toJson();

  Map<String, dynamic>? _maps;

  Map<String, dynamic> get jsonCache => _maps ??= toJson();

  bool get isEmpty => jsonCache.isEmpty;
  bool get isNotEmpty => !isEmpty;
  bool get hasNull => jsonCache.containsValue(null);
  bool hasNullIgnores(Iterable<String> i) => _ignores(i).containsValue(null);

  bool get notNull => !hasNull;
  bool notNullIgnores(Iterable<String> i) => !hasNullIgnores(i);

  Map<String, dynamic> _ignores(Iterable<String> i) =>
      Map.of(jsonCache)..removeWhere((key, value) => i.contains(key));

  bool isEmptyIgnores(Iterable<String> i) => _ignores(i).isEmpty;
  bool isNotEmptyIgnores(Iterable<String> i) => !isEmptyIgnores(i);

  @override
  String toString() => '$runtimeType: $jsonCache';

  static int? boolToInt(bool? v) {
    if (v == null) {
      return null;
    } else {
      return v ? 1 : 0;
    }
  }

  static bool? intToBool(int? v) {
    if (v == null) {
      return null;
    } else {
      return v != 0;
    }
  }
}

abstract class DatabaseTable<T extends Table, D extends DatabaseTable<T, D>> {
  DatabaseTable(this.db);
  final $Database db;

  String get table;
  String createTable();

  List<T> toTable(Iterable<Map<String, Object?>> query);

  QueryStatement<T, D> get query => QueryStatement<T, D>(this as D, db);

  UpdateStatement<T, D> get update => UpdateStatement<T, D>(this as D, db);

  InsertStatement<T, D> get insert => InsertStatement<T, D>(this as D, db);

  DeleteStatement<T, D> get delete => DeleteStatement<T, D>(this as D, db);
}
