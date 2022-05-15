import 'package:example/repository.dart';
import 'package:test/test.dart';

void main() {
  test('isolate test', () async {
    final repository = Repository();
    await repository.init();
    final result = await repository.workStatus();
    expect(result, true);
    await repository.doOtherWorks();
    await repository.doSecondOtherWork();
  });
}
