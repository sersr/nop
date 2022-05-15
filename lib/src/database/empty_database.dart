import 'gen_database.dart';
import 'table.dart';

abstract class EmptyDatabaseTable
    extends DatabaseTable<Table, EmptyDatabaseTable> {
  EmptyDatabaseTable($Database db) : super(db);
}
