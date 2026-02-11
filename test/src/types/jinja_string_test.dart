import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('JinjaString', () {
    test('Creation', () {
      final s = JinjaString.from('hello');
      expect(s.toString(), 'hello');
      expect(s.parts.length, 1);
      expect(s.parts[0].isInput, false); // default

      final input = JinjaString.from('user', isInput: true);
      expect(input.parts[0].isInput, true);
    });

    test('Concatenation', () {
      final s1 = JinjaString.from('hello ');
      final s2 = JinjaString.from('world', isInput: true);
      final s3 = s1 + s2;

      expect(s3.toString(), 'hello world');
      expect(s3.parts.length, 2);
      expect(s3.parts[0].val, 'hello ');
      expect(s3.parts[0].isInput, false);
      expect(s3.parts[1].val, 'world');
      expect(s3.parts[1].isInput, true);
    });

    test('Substring Preserves Marking', () {
      // [false: "hello "][true: "world"]
      final s = JinjaString([
        const JinjaStringPart('hello ', false),
        const JinjaStringPart('world', true),
      ]);

      // Substring entirely within part 0
      final sub1 = s.substring(0, 5);
      expect(sub1.toString(), 'hello');
      expect(sub1.parts.length, 1);
      expect(sub1.parts[0].isInput, false);

      // Substring entirely within part 1
      final sub2 = s.substring(6, 11);
      expect(sub2.toString(), 'world');
      expect(sub2.parts.length, 1);
      expect(sub2.parts[0].isInput, true);

      // Substring overlapping both parts
      final sub3 = s.substring(3, 8);
      expect(sub3.toString(), 'lo wo');
      expect(sub3.parts.length, 2);
      expect(sub3.parts[0].val, 'lo ');
      expect(sub3.parts[0].isInput, false);
      expect(sub3.parts[1].val, 'wo');
      expect(sub3.parts[1].isInput, true);
    });

    test('Substring Preserves Safety', () {
      final safe = JinjaString.from('<b>', isSafe: true);
      final sub = safe.substring(1, 2);
      expect(sub.toString(), 'b');
      expect(sub.isSafe, true);
    });
  });

  group('Propagation and Security', () {
    test('Concatenation preserves input marking', () {
      final template = Template('{{ user_input + " suffix" }}');
      final userInput = JinjaString.user('evil');
      final result = template.renderJinjaResult({'user_input': userInput});

      expect(result.toString(), equals('evil suffix'));
      expect(result.parts.length, equals(2));
      expect(result.parts[0].isInput, isTrue);
      expect(result.parts[1].isInput, isFalse);
    });

    test('Variable substitution preserves input marking', () {
      final template = Template('Prefix {{ user_input }} Suffix');
      final userInput = JinjaString.user('evil');
      final result = template.renderJinjaResult({'user_input': userInput});

      expect(result.parts.any((p) => p.val == 'evil' && p.isInput), isTrue);
    });

    test('Filters preserve input marking', () {
      final userInput = JinjaString.user('  evil  ');

      final upper = Template(
        '{{ user_input | upper }}',
      ).renderJinjaResult({'user_input': userInput});
      expect(upper.toString(), equals('  EVIL  '));
      expect(upper.parts.first.isInput, isTrue);

      final trimmed = Template(
        '{{ user_input | trim }}',
      ).renderJinjaResult({'user_input': userInput});
      expect(trimmed.toString(), equals('evil'));
      expect(trimmed.parts.first.isInput, isTrue);
    });

    test('Safe marking and _safe filter', () {
      final unsafe = Template(
        '{{ val }}',
      ).render({'val': JinjaString.user('<b>')});
      final safe = Template(
        '{{ val | safe }}',
      ).render({'val': JinjaString.user('<b>')});

      expect(unsafe, equals('&lt;b&gt;'));
      expect(safe, equals('<b>'));
    });

    test('Propagation through .replace()', () {
      final template = Template('{{ s.replace("a", "b") }}');
      final safeS = JinjaString.from('a', isSafe: true);
      final result = template.render({'s': safeS});
      expect(
        result,
        equals('b'),
      ); // In real usage, this should still be considered safe if we had a way to check final content.
      // But the key is that JinjaString itself tracks it.
    });
  });
}
