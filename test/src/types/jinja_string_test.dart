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

  group('Content equality', () {
    final empties = <String, JinjaString>{
      'no parts': const JinjaString([]),
      'two empty parts': const JinjaString([
        JinjaStringPart('', false),
        JinjaStringPart('', true),
      ]),
      'safe': JinjaString.from('', isSafe: true),
      'trim()': JinjaString.from('  ').trim(),
      'trimLeft()': JinjaString.from('  ').trimLeft(),
      'trimRight()': JinjaString.from('  ').trimRight(),
    };

    for (final e in empties.entries) {
      test("empty ${e.key} == ''", () {
        expect(e.value, equals(JinjaString.from('')));
        expect(e.value.hashCode, equals(JinjaString.from('').hashCode));
      });
    }

    test('ignores part boundaries', () {
      const split = JinjaString([
        JinjaStringPart('a', false),
        JinjaStringPart('b', true),
      ]);
      expect(split, equals(JinjaString.from('ab')));
      expect(split.hashCode, equals(JinjaString.from('ab').hashCode));
    });

    test('ignores input marking', () {
      expect(JinjaString.user('a'), equals(JinjaString.template('a')));
      expect(
        JinjaString.user('a').hashCode,
        equals(JinjaString.template('a').hashCode),
      );
    });

    test('ignores isSafe', () {
      final safe = JinjaString.from('a', isSafe: true);
      expect(safe, equals(JinjaString.from('a')));
      expect(safe.hashCode, equals(JinjaString.from('a').hashCode));
    });

    test('differs on content', () {
      expect(JinjaString.from('a'), isNot(equals(JinjaString.from('b'))));
      expect(JinjaString.from(''), isNot(equals(JinjaString.from(' '))));
    });

    test('differently built strings are the same map key', () {
      final map = <JinjaValue, JinjaValue>{
        JinjaStringValue(JinjaString.from('')): const JinjaInteger(1),
        JinjaStringValue(JinjaString.from('ab', isSafe: true)):
            const JinjaInteger(2),
      };
      expect(
        map[JinjaStringValue(JinjaString.from(' ').trim())],
        equals(const JinjaInteger(1)),
      );
      expect(
        map[const JinjaStringValue(
          JinjaString([
            JinjaStringPart('a', true),
            JinjaStringPart('b', false),
          ]),
        )],
        equals(const JinjaInteger(2)),
      );
    });
  });

  group('Template string equality matches Jinja2 and llama.cpp', () {
    const cases = <String, String>{
      "{{ ''.strip() == '' }}": 'True',
      "{% set x = '' %}{{ x.strip() == '' }}": 'True',
      "{{ ''.strip() | length }}": '0',
      "{{ ' a '.strip() == 'a' }}": 'True',
      "{{ '' == '' }}": 'True',
      "{{ '  '.lstrip() == '' }}": 'True',
      "{{ '  '.rstrip() == '' }}": 'True',
      "{{ '  ' | trim == '' }}": 'True',
      "{{ ''.strip() != '' }}": 'False',
      "{{ ''.strip() in ['', 'x'] }}": 'True',
      "{{ ''.strip() not in [''] }}": 'False',
      "{{ ''.strip() in {'': 1} }}": 'True',
      "{{ {'': 'hit'}[''.strip()] }}": 'hit',
      "{{ {''.strip(): 'hit'}[''] }}": 'hit',
      "{{ ''.strip() + ''.strip() == '' }}": 'True',
      "{{ ('a' | safe) == 'a' }}": 'True',
      "{{ ('a' | safe) + ('b' | safe) == 'ab' }}": 'True',
      "{% set x %}ab{% endset %}{{ x == 'ab' }}": 'True',
      "{% set k %}role{% endset %}{{ {'role': 'user'}[k] }}": 'user',
      "{{ ('role' | safe) in {'role': 1} }}": 'True',
      "{{ 'abc'[1:1] == '' }}": 'True',
      "{{ 'abc'[::2] == 'ac' }}": 'True',
      "{{ 'abc'[::-1] == 'cba' }}": 'True',
      "{{ ('a' | safe).replace('a', 'b') == 'b' }}": 'True',
      "{{ ''.strip() | upper == '' }}": 'True',
      "{{ ('a' | safe) | upper == 'A' }}": 'True',
      "{{ [] | join == '' }}": 'True',
      "{{ ['b', 'a' | safe, ''.strip()] | sort | join(',') }}": ',a,b',
      "{{ ('a' | safe) is in(['a']) }}": 'True',
    };

    for (final c in cases.entries) {
      test(c.key, () {
        expect(Template(c.key).render(), equals(c.value));
      });
    }

    const inputCases = <String, String>{
      "{{ s == 'hi' }}": 'True',
      "{{ s + '!' == 'hi!' }}": 'True',
      "{{ s in ['hi'] }}": 'True',
      "{{ {'hi': 'hit'}[s] }}": 'hit',
      "{{ not blank.strip() == '' }}": 'False',
    };

    for (final c in inputCases.entries) {
      test('user input: ${c.key}', () {
        final values = {
          's': JinjaString.user('hi'),
          'blank': JinjaString.user(''),
        };
        expect(Template(c.key).render(values), equals(c.value));
      });
    }
  });

  group('Template string equality matches Jinja2', () {
    test(
      "{{ ['a', 'a' | safe, ''.strip(), ''] | unique | list | length }}",
      () {
        expect(
          Template(
            "{{ ['a', 'a' | safe, ''.strip(), ''] | unique | list | length }}",
          ).render(),
          equals('2'),
        );
      },
    );
  });

  group('Input marking matches llama.cpp', () {
    // Parts as llama.cpp 7fe450e19 marks them, adjacent parts merged:
    // [I:...] is input, [T:...] is template text.
    for (final (source, expected) in [
      ('{{ s ~ t }}', '[I: Ab,c xy]'),
      ("{{ s ~ 'lit' }}", '[I: Ab,c ][T:lit]'),
      ('{{ s ~ n }}', '[I: Ab,c ][T:5]'),
      ('{{ l[0] ~ l[1] }}', '[I:pq]'),
      ('{{ (s ~ t) | upper }}', '[I: AB,C XY]'),
      ('{{ s * 2 }}', '[I: Ab,c  Ab,c ]'),
      ("{{ ('lit' ~ s) * 2 }}", '[T:lit][I: Ab,c ][T:lit][I: Ab,c ]'),
      ("{{ s | replace('A', t) }}", '[I: xyb,c ]'),
      ('{{ s | capitalize }}', '[I: ab,c ]'),
      ('{{ s.capitalize() }}', '[I: ab,c ]'),
      ("{{ ('lit' ~ s) | capitalize }}", '[T:Lit][I: ab,c ]'),
      ('{% filter capitalize %}{{ s }}{% endfilter %}', '[I: ab,c ]'),
      ('{{ s | title }}', '[I: Ab,c ]'),
      ('{{ s.title() }}', '[I: Ab,c ]'),
      ('{{ s | string }}', '[I: Ab,c ]'),
      ("{{ s.split(',') | last }}", '[I:c ]'),
      ("{{ s.split(',', 1) | last }}", '[I:c ]'),
      ("{{ t.split(',') | first }}", '[I:xy]'),
      ("{{ s.rsplit(',') | first }}", '[I: Ab]'),
      ('{{ s + t }}', '[I: Ab,c xy]'),
    ]) {
      test(source, () {
        expect(_marks(source), expected);
      });
    }
  });

  group('Input marking kept where llama.cpp drops or widens it', () {
    // Each character keeps the marking of where it came from, so input text
    // is escaped and template text is not. llama.cpp 7fe450e19 marks each as
    // noted; its marking only controls special-token parsing.
    for (final (source, expected) in [
      // llama.cpp: [T:pq]
      ('{{ l | join }}', '[I:pq]'),
      // llama.cpp: [T:p, q]
      ("{{ l | join(', ') }}", '[I:p][T:, ][I:q]'),
      // llama.cpp: [T:" Ab,c "]
      ('{{ s | tojson }}', '[T:"][I: Ab,c ][T:"]'),
      // llama.cpp: [T:{" Ab,c ": "xy"}]
      ('{{ {s: t} | tojson }}', '[T:{"][I: Ab,c ][T:": "][I:xy][T:"}]'),
      // llama.cpp: [T: Ab]
      ("{{ s.split(',') | first }}", '[I: Ab]'),
      // llama.cpp: [T:c ]
      ("{{ s.rsplit(',') | last }}", '[I:c ]'),
      // llama.cpp: [T:A]
      ('{{ s[1] }}', '[I:A]'),
      // llama.cpp: [T:lit Zb,c ]
      ("{{ ('lit' ~ s) | replace('A', 'Z') }}", '[T:lit][I: ][T:Z][I:b,c ]'),
      // llama.cpp: [T:lit Ab,c ]
      ("{{ ('lit' ~ s) | indent(2) }}", '[T:lit][I: Ab,c ]'),
      // llama.cpp: [I: Zb,c ]
      ("{{ s | replace('A', 'Z') }}", '[I: ][T:Z][I:b,c ]'),
      // llama.cpp: [I: Zb,c ]
      ("{{ s.replace('A', 'Z') }}", '[I: ][T:Z][I:b,c ]'),
      // llama.cpp: [I:   Ab,c ]
      ('{{ s | indent(2, true) }}', '[T:  ][I: Ab,c ]'),
    ]) {
      test(source, () {
        expect(_marks(source), expected);
      });
    }
  });

  group('Input escaping', () {
    for (final (source, expected) in [
      ("{{ s ~ '' }}", 'a&lt;b'),
      ('{{ s * 2 }}', 'a&lt;ba&lt;b'),
      ("{{ s | replace('a', 'z') }}", 'z&lt;b'),
      ('{{ s | capitalize }}', 'A&lt;b'),
      ("{% set x %}{{ s }}{% endset %}{{ x + '' }}", 'a&lt;b'),
      ("{% macro m() %}{{ s }}{% endmacro %}{{ m() + '' }}", 'a&lt;b'),
      ("{% set x %}{{ s }}{% endset %}{{ x ~ '' }}", 'a&lt;b'),
      ('{% set x %}{{ s }}{% endset %}{{ x * 2 }}', 'a&lt;ba&lt;b'),
      ('{% set x %}{{ s }}{% endset %}{{ x | capitalize }}', 'A&lt;b'),
      ("{% set x %}{{ s }}{% endset %}{{ x | replace('a', 'z') }}", 'z&lt;b'),
    ]) {
      test(source, () {
        expect(
          Template(source).render({'s': JinjaString.user('a<b')}),
          expected,
        );
      });
    }
  });
}

String _marks(String source) {
  final result = Template(source).renderJinjaResult({
    's': JinjaString.user(' Ab,c '),
    't': JinjaString.user('xy'),
    'l': [JinjaString.user('p'), JinjaString.user('q')],
    'n': 5,
  });
  final merged = <JinjaStringPart>[];
  for (final part in result.parts.where((p) => p.val.isNotEmpty)) {
    if (merged.isNotEmpty && merged.last.isInput == part.isInput) {
      merged.last = JinjaStringPart(merged.last.val + part.val, part.isInput);
    } else {
      merged.add(part);
    }
  }
  return merged.map((p) => '[${p.isInput ? 'I' : 'T'}:${p.val}]').join();
}
