abstract class Either<L, R> {
  const Either();
  S map<S>({required S Function(L) left, required S Function(R) right});
}

class Left<L, R> extends Either<L, R> {
  const Left(this.value);
  final L value;
  @override
  S map<S>({required S Function(L p1) left, required S Function(R p1) right}) {
    return left(value);
  }
}

class Right<L, R> extends Either<L, R> {
  const Right(this.value);
  final R value;
  @override
  S map<S>({required S Function(L p1) left, required S Function(R p1) right}) {
    return right(value);
  }
}
