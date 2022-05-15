import 'package:collection/collection.dart';

const equality = ListEquality(MapEquality());

bool matchListItem(Iterable v, Iterable y) => y.any(v.contains);
