import 'package:flutter_test/flutter_test.dart';
import 'package:strive/core/format.dart';

void main() {
  test('parseHms accepts h:mm:ss, mm:ss and minutes', () {
    expect(parseHms('1:02:03'), 3723);
    expect(parseHms('45:10'), 2710);
    expect(parseHms('45'), 2700);
    expect(parseHms(' 0:30 '), 30);
    expect(parseHms(''), isNull);
    expect(parseHms('1:75'), isNull);
    expect(parseHms('abc'), isNull);
    expect(parseHms('1:2:3:4'), isNull);
  });
}
