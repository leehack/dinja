import 'package:test/test.dart';
import 'package:dinja/src/runtime/context.dart';
import 'package:dinja/src/types/value.dart';

void main() {
  group('Context', () {
    test('Stores and retrieves variables', () {
      final ctx = Context();
      ctx.set('foo', JinjaInteger(42));
      expect(ctx.get('foo'), isA<JinjaInteger>());
      expect(ctx.get('foo').asInt, 42);
    });

    test('Parent scope lookup', () {
      final parent = Context();
      parent.set('foo', JinjaInteger(1));
      final child = Context(parent: parent);
      expect(child.get('foo').asInt, 1);
    });

    test('Shadowing parent scope', () {
      final parent = Context();
      parent.set('foo', JinjaInteger(1));
      final child = Context(parent: parent);
      child.set('foo', JinjaInteger(2));
      expect(child.get('foo').asInt, 2);
      expect(parent.get('foo').asInt, 1);
    });

    test('Returns undefined for missing variable', () {
      final ctx = Context();
      expect(ctx.get('missing'), isA<JinjaUndefined>());
    });
  });
}
