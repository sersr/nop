import 'dart:math' as math;

extension MaxMin<T extends num> on T {
  T maxThan(T other) {
    return math.max(this, other);
  }

  T minThan(T other) {
    return math.min(this, other);
  }
}
