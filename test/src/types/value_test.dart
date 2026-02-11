import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('JinjaValue', () {
    test('JinjaStringValue', () {
      final s = JinjaStringValue.fromString('test');
      expect(s.isString, true);
      expect(s.asBool, true);
      expect(s.toString(), 'test');
    });

    test('JinjaInteger', () {
      final i = JinjaInteger(42);
      expect(i.isNumeric, true);
      expect(i.asInt, 42);
      expect(i.asBool, true);
      expect(i.toString(), '42');
    });

    test('JinjaFloat', () {
      final f = JinjaFloat(3.14);
      expect(f.isNumeric, true);
      expect(f.asDouble, 3.14);
      expect(f.asBool, true);
      expect(f.toString(), '3.14');
    });

    test('JinjaBoolean', () {
      final b = JinjaBoolean(true);
      expect(b.asBool, true);
      expect(b.toString(), 'True'); // Python style

      final f = JinjaBoolean(false);
      expect(f.asBool, false);
      expect(f.toString(), 'False');
    });

    test('JinjaNone', () {
      final n = JinjaNone();
      expect(n.isNone, true);
      expect(n.asBool, false);
      expect(n.toString(), 'None');
    });

    test('JinjaUndefined', () {
      final u = JinjaUndefined();
      expect(u.isUndefined, true);
      expect(u.asBool, false);
      expect(u.toString(), '');
    });

    test('JinjaList', () {
      final l = JinjaList([const JinjaInteger(1), const JinjaInteger(2)]);
      expect(l.isList, true);
      expect(l.items.length, 2);
      expect(l.toString(), '[1, 2]');
    });

    test('JinjaMap', () {
      final m = JinjaMap({'key': JinjaStringValue.fromString('value')});
      expect(m.isMap, true);
      expect(m.items.length, 1);
      expect(m.toString(), "{'key': 'value'}");
    });

    test('JinjaTuple', () {
      final t = JinjaTuple([const JinjaInteger(1), const JinjaInteger(2)]);
      expect(t.toString(), '(1, 2)');
    });
  });

  group('JinjaValue Equality', () {
    test('Basic equality', () {
      expect(const JinjaBoolean(true) == const JinjaBoolean(true), isTrue);
      expect(const JinjaBoolean(true) == const JinjaBoolean(false), isFalse);
      expect(const JinjaInteger(1) == const JinjaInteger(1), isTrue);
      expect(const JinjaInteger(1) == const JinjaInteger(2), isFalse);
      expect(const JinjaFloat(1.5) == const JinjaFloat(1.5), isTrue);
    });

    test('Numeric equality across types', () {
      expect(const JinjaInteger(1) == const JinjaFloat(1.0), isTrue);
      expect(const JinjaInteger(1) == const JinjaBoolean(true), isTrue);
      expect(const JinjaInteger(0) == const JinjaBoolean(false), isTrue);
      expect(const JinjaFloat(1.0) == const JinjaBoolean(true), isTrue);
    });

    test('Deep equality for lists', () {
      final l1 = JinjaList([
        const JinjaInteger(1),
        JinjaList([const JinjaInteger(2)]),
      ]);
      final l2 = JinjaList([
        const JinjaInteger(1),
        JinjaList([const JinjaInteger(2)]),
      ]);
      final l3 = JinjaList([const JinjaInteger(1)]);

      expect(l1 == l2, isTrue);
      expect(l1 == l3, isFalse);
    });

    test('Deep equality for maps', () {
      final m1 = JinjaMap({
        'a': const JinjaInteger(1),
        'b': JinjaList([const JinjaInteger(2)]),
      });
      final m2 = JinjaMap({
        'a': const JinjaInteger(1),
        'b': JinjaList([const JinjaInteger(2)]),
      });
      final m3 = JinjaMap({'a': const JinjaInteger(1)});

      expect(m1 == m2, isTrue);
      expect(m1 == m3, isFalse);
    });

    test('Deep equality for tuples', () {
      final t1 = JinjaTuple([const JinjaInteger(1), const JinjaInteger(2)]);
      final t2 = JinjaTuple([const JinjaInteger(1), const JinjaInteger(2)]);
      final t3 = JinjaTuple([const JinjaInteger(1)]);

      expect(t1 == t2, isTrue);
      expect(t1 == t3, isFalse);
    });
  });

  group('Conversion', () {
    test('toDart()', () {
      expect(const JinjaBoolean(true).toDart(), isTrue);
      expect(const JinjaInteger(123).toDart(), 123);
      expect(const JinjaFloat(1.5).toDart(), 1.5);
      expect(const JinjaStringValue(JinjaString([])).toDart(), '');
      expect(JinjaList([const JinjaInteger(1)]).toDart(), [1]);
      expect(JinjaMap({'a': const JinjaInteger(1)}).toDart(), {'a': 1});
    });
  });
}
