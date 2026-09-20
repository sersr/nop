class NopDbItem {
  const NopDbItem({
    this.name = '',
    this.primaryKey = false,
    this.constraints = '',
    this.type,
  });
  final String name;
  final bool primaryKey;
  final String constraints;
  final Type? type;
}

class NopDb {
  const NopDb({this.tables = const []});

  final List<Type> tables;
}
