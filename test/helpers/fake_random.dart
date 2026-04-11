import 'dart:math';

class FakeRandom implements Random {
  final List<int> values;
  var _index = 0;
  FakeRandom(this.values);

  @override
  bool nextBool() {
    throw UnimplementedError();
  }

  @override
  double nextDouble() {
    throw UnimplementedError();
  }

  @override
  int nextInt(int max) {
    final value = values[_index];
    _index++;

    return value;
  }
}
