import 'dart:convert';

import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Built-in Functions and Filters', () {
    test('tojson filter', () {
      final tpl = Template('{{ val | tojson }}');
      expect(
        tpl.render({
          'val': {
            'a': 1,
            'b': [2, 3],
          },
        }),
        equals('{"a": 1, "b": [2, 3]}'),
      );
    });

    test('range function', () {
      final tpl = Template('{% for i in range(3) %}{{ i }}{% endfor %}');
      expect(tpl.render(), equals('012'));
    });

    test('strftime_now builtin', () {
      final tpl = Template('{{ strftime_now("%Y") }}');
      final year = DateTime.now().year.toString();
      expect(tpl.render({}), equals(year));
    });

    test('dictsort filter', () {
      final template = Template(
        "{{ d | dictsort | map(attribute='0') | join(', ') }}",
      );
      final data = {
        'd': {'b': 2, 'a': 1, 'c': 3},
      };
      expect(template.render(data), equals('a, b, c'));
    });

    test('selectattr and rejectattr', () {
      final data = {
        'users': [
          {'name': 'Alice', 'active': true},
          {'name': 'Bob', 'active': false},
          {'name': 'Charlie', 'active': true},
        ],
      };

      final select = Template(
        "{{ users | selectattr('active') | map(attribute='name') | join(', ') }}",
      );
      expect(select.render(data), equals('Alice, Charlie'));

      final reject = Template(
        "{{ users | rejectattr('active') | map(attribute='name') | join(', ') }}",
      );
      expect(reject.render(data), equals('Bob'));
    });

    test('attribute support in sum, max, min', () {
      final data = {
        'items': [
          {'price': 10, 'age': 20},
          {'price': 20, 'age': 30},
          {'price': 5, 'age': 40},
        ],
      };
      expect(
        Template("{{ items | sum(attribute='price') }}").render(data),
        equals('35'),
      );
      expect(
        Template("{{ (items | max(attribute='age')).price }}").render(data),
        equals('5'),
      );
      expect(
        Template("{{ (items | min(attribute='price')).age }}").render(data),
        equals('40'),
      );
    });

    test('strip, lstrip, rstrip with chars', () {
      expect(
        Template("{{ '---abc---' | strip('-') }}").render({}),
        equals('abc'),
      );
      expect(
        Template("{{ '---abc---' | lstrip('-') }}").render({}),
        equals('abc---'),
      );
      expect(
        Template("{{ '---abc---' | rstrip('-') }}").render({}),
        equals('---abc'),
      );
    });

    test('map with default', () {
      final data = {
        'items': [
          {'val': 1},
          {},
          {'val': 2},
        ],
      };
      expect(
        Template(
          "{{ items | map(attribute='val', default=0) | join(',') }}",
        ).render(data),
        equals('1,0,2'),
      );
    });

    test('unique with attribute', () {
      final data = {
        'items': [
          {'id': 1},
          {'id': 2},
          {'id': 1},
        ],
      };
      expect(
        Template("{{ items | unique(attribute='id') | length }}").render(data),
        equals('2'),
      );
    });

    group('unique compares with Python equality', () {
      // Expected values are Jinja2 3.1.6 output.
      for (final (source, expected) in [
        ("{{ [1, '1'] | unique | list | length }}", '2'),
        ("{{ [1, 2, 1, '2'] | unique | join(',') }}", '1,2,2'),
        ("{{ (1, '1', 1) | unique | list | length }}", '2'),
        ("{{ [1.5, 1.5, '1.5'] | unique | list | length }}", '2'),
        ("{{ [none, none, 'None'] | unique | list | length }}", '2'),
        ("{{ [1, 1.0, true] | unique | join(',') }}", '1'),
        ("{{ [true, 1, 1.0] | unique | join(',') }}", 'True'),
        ('{{ [0, false, 0.0] | unique | list | length }}', '1'),
        ("{{ ['a', 'A', 'b'] | unique | join('') }}", 'ab'),
        (
          "{{ ['a', 'A', 'b'] | unique(case_sensitive=true) | join('') }}",
          'aAb',
        ),
        (
          "{{ [{'n': 'a'}, {'n': 'A'}, {'n': 1}, {'n': '1'}] "
              "| unique(attribute='n') | map(attribute='n') | join(',') }}",
          'a,1,1',
        ),
        ("{{ ['a', 'A', 'b'] | unique(true) | join('') }}", 'aAb'),
        ("{{ ['a', 'A', 'b'] | unique(false) | join('') }}", 'ab'),
        (
          "{{ [{'n': 'a'}, {'n': 'A'}] | unique(true, 'n') "
              "| map(attribute='n') | join(',') }}",
          'a,A',
        ),
        ("{{ 'abca' | unique | join(',') }}", 'a,b,c'),
        ("{{ 'abcA' | unique | join('') }}", 'abc'),
        ("{{ 'abcAa' | unique(true) | join('') }}", 'abcA'),
        ("{{ {'a': 1, 'A': 2, 'b': 3} | unique | join(',') }}", 'a,b'),
        ("{{ {'a': 1, 'A': 2, 'b': 3} | unique(true) | join(',') }}", 'a,A,b'),
        (
          "{{ {1: 'x', '1': 'y', 'a': 2, 'A': 3} | unique | list | length }}",
          '3',
        ),
      ]) {
        test(source, () {
          expect(Template(source).render(), expected);
        });
      }
    });

    test('unique keeps input marking on string characters', () {
      final result = Template(
        '{{ s | unique | first }}',
      ).renderJinjaResult({'s': JinjaString.user('aAb')});
      expect(result.toString(), 'a');
      expect(result.parts.every((p) => p.isInput), isTrue);
    });

    test('replace filter', () {
      expect(
        Template("{{ 'hello' | replace('l', 'w') }}").render({}),
        equals('hewwo'),
      );
    });
  });

  group('List Methods', () {
    test('append, pop, reverse, sort', () {
      final tpl = Template(
        "{% set l = [3, 1, 2] %}"
        "{% if l.append(4) %}{% endif %}"
        "{{ l | join(',') }}|"
        "{% if l.sort() %}{% endif %}"
        "{{ l | join(',') }}|"
        "{{ l.pop(0) }}|"
        "{{ l | join(',') }}|"
        "{% if l.reverse() %}{% endif %}"
        "{{ l | join(',') }}",
      );
      expect(tpl.render({}), equals('3,1,2,4|1,2,3,4|1|2,3,4|4,3,2'));
    });

    test('sort and unique with attribute and case-sensitivity', () {
      final data = {
        'items': [
          {'name': 'b'},
          {'name': 'A'},
          {'name': 'a'},
        ],
      };

      // sort
      final sortResult = Template(
        "{% if items.sort(attribute='name', case_sensitive=true) %}{% endif %}"
        "{{ items | map(attribute='name') | join('') }}",
      ).render(data);
      expect(sortResult, equals('Aab'));

      // unique
      final uniqueResult = Template(
        "{{ ['a', 'A', 'b'] | unique(case_sensitive=false) | join('') }}",
      ).render({});
      expect(uniqueResult, equals('ab'));
    });

    test('unique method compares with Python equality', () {
      expect(
        Template("{{ [1, '1', 1.0].unique() | join(',') }}").render(),
        equals('1,1'),
      );
    });
  });

  group('Tests (is operators)', () {
    test('ieq test (case-insensitive equality)', () {
      expect(Template("{{ 'ABC' is ieq('abc') }}").render({}), equals('True'));
      expect(Template("{{ 'ABC' is ieq('DEF') }}").render({}), equals('False'));
    });

    test('defined, undefined, none, etc.', () {
      expect(Template("{{ x is defined }}").render({'x': 1}), equals('True'));
      expect(Template("{{ x is defined }}").render({}), equals('False'));
      expect(Template("{{ x is none }}").render({'x': null}), equals('True'));
    });
  });

  group('Builtins Coverage', () {
    test('range function variants', () {
      // 1 arg
      expect(Template('{{ range(3)|join(",") }}').render(), equals('0,1,2'));
      // 2 args
      expect(Template('{{ range(1, 4)|join(",") }}').render(), equals('1,2,3'));
      // 3 args (positive step)
      expect(
        Template('{{ range(0, 5, 2)|join(",") }}').render(),
        equals('0,2,4'),
      );
      // 3 args (negative step)
      expect(
        Template('{{ range(5, 0, -1)|join(",") }}').render(),
        equals('5,4,3,2,1'),
      );
      // Error case
      expect(
        () => Template('{{ range() }}').render(),
        throwsA(isA<Exception>()),
      );
    });

    test('list function conversions', () {
      // String to chars
      expect(Template("{{ list('abc')|join(',') }}").render(), equals('a,b,c'));
      // Dict to keys
      final dictTpl = Template("{{ list({'a': 1, 'b': 2})|sort|join(',') }}");
      expect(dictTpl.render(), equals('a,b'));
      // Tuple to list
      // (Need to manipulate context to inject a tuple if not directly supported via literal)
      // Standard list
      expect(Template("{{ list([1, 2])|join(',') }}").render(), equals('1,2'));
      // Other (wrap)
      expect(Template("{{ list(123)|join(',') }}").render(), equals('123'));
    });

    test('int and float conversions', () {
      expect(Template("{{ int('123') }}").render(), equals('123'));
      expect(Template("{{ int(12.5) }}").render(), equals('12'));
      expect(Template("{{ int(true) }}").render(), equals('1'));
      expect(Template("{{ int(false) }}").render(), equals('0'));
      expect(Template("{{ int('abc', default=42) }}").render(), equals('42'));

      expect(Template("{{ float('12.5') }}").render(), equals('12.5'));
      expect(Template("{{ float(10) }}").render(), equals('10.0'));
      expect(Template("{{ float(true) }}").render(), equals('1.0'));
      expect(
        Template("{{ float('abc', default=0.5) }}").render(),
        equals('0.5'),
      );
    });

    test('first and last', () {
      expect(Template("{{ [1, 2, 3]|first }}").render(), equals('1'));
      expect(Template("{{ 'abc'|first }}").render(), equals('a'));
      expect(
        Template("{{ []|first }}").render(),
        equals(''),
      ); // Undefined -> empty string

      expect(Template("{{ [1, 2, 3]|last }}").render(), equals('3'));
      expect(Template("{{ 'abc'|last }}").render(), equals('c'));
      expect(Template("{{ []|last }}").render(), equals(''));
    });

    test('min and max', () {
      expect(Template("{{ [1, 3, 2]|min }}").render(), equals('1'));
      expect(Template("{{ [1, 3, 2]|max }}").render(), equals('3'));

      final data = {
        'items': [
          {'v': 10},
          {'v': 5},
          {'v': 15},
        ],
      };
      expect(
        Template("{{ items|min(attribute='v') }}").render(data),
        equals("{'v': 5}"),
      );
      expect(
        Template("{{ items|max(attribute='v') }}").render(data),
        equals("{'v': 15}"),
      );
    });

    test('sum filter', () {
      expect(Template("{{ [1, 2, 3]|sum }}").render(), equals('6'));
      expect(Template("{{ [1, 2, 3]|sum(start=10) }}").render(), equals('16'));
      // Attribute
      final data = {
        'items': [
          {'v': 10},
          {'v': 5},
        ],
      };
      expect(
        Template("{{ items|sum(attribute='v') }}").render(data),
        equals('15'),
      );
      // Float
      expect(Template("{{ [1.5, 2.5]|sum }}").render(), equals('4.0'));
    });

    test('abs filter', () {
      expect(Template("{{ -5|abs }}").render(), equals('5'));
      expect(Template("{{ -5.5|abs }}").render(), equals('5.5'));
    });

    test('round filter', () {
      expect(Template("{{ 3.14159|round(2) }}").render(), equals('3.14'));
      // round() with default precision=0 returns integer if no args?
      // builtins.dart: "if (precision == 0) return JinjaInteger(result.toInt());"
      expect(Template("{{ 3.6|round }}").render(), equals('4'));
      expect(Template("{{ 3.2|round(0, 'ceil') }}").render(), equals('4'));
      expect(Template("{{ 3.8|round(0, 'floor') }}").render(), equals('3'));
    });

    test('default filter', () {
      expect(Template("{{ undef|default('def') }}").render(), equals('def'));
      expect(
        Template("{{ false|default('def', true) }}").render(),
        equals('def'),
      );
      expect(
        Template("{{ false|default('def', false) }}").render(),
        equals('False'),
      );
    });

    test('map filter attributes', () {
      final data = {
        'users': [
          {'name': 'A'},
          {'name': 'B'},
          {},
        ],
      };
      expect(
        Template(
          "{{ users|map(attribute='name', default='Unknown')|join(',') }}",
        ).render(data),
        equals('A,B,Unknown'),
      );
    });

    test('items, keys, values', () {
      final data = {
        'd': {'a': 1, 'b': 2},
      };
      // keys
      expect(
        Template("{{ d|keys|sort|join(',') }}").render(data),
        equals('a,b'),
      );
      // values
      expect(
        Template("{{ d|values|sort|join(',') }}").render(data),
        equals('1,2'),
      );
      // items
      expect(Template("{{ d|items|length }}").render(data), equals('2'));
    });

    test('replace filter count', () {
      // Dart replaceAll replaces all occurrences. Jinja replace has count arg but our implementation
      // in builtins.dart currently takes only 3 args (obj, old, new).
      // Checking implementation... it does NOT seem to support count.
      expect(
        Template("{{ 'aabbcc'|replace('a', 'z') }}").render(),
        equals('zzbbcc'),
      );
    });

    test('is tests', () {
      expect(Template("{{ 3 is odd }}").render(), equals('True'));
      expect(Template("{{ 4 is even }}").render(), equals('True'));
      expect(Template("{{ 3 is number }}").render(), equals('True'));
      expect(Template("{{ 's' is string }}").render(), equals('True'));
      expect(Template("{{ [] is sequence }}").render(), equals('True'));
      expect(Template("{{ {} is mapping }}").render(), equals('True'));
      expect(Template("{{ [1] is iterable }}").render(), equals('True'));

      expect(
        Template("{{ 'abc' is startingwith('a') }}").render(),
        equals('True'),
      );
      expect(
        Template("{{ 'abc' is endingwith('c') }}").render(),
        equals('True'),
      );

      expect(Template("{{ 1 is eq(1) }}").render(), equals('True'));
      expect(Template("{{ 1 is ne(2) }}").render(), equals('True'));
      expect(Template("{{ 5 is gt(3) }}").render(), equals('True'));
      expect(Template("{{ 5 is ge(5) }}").render(), equals('True'));
      expect(Template("{{ 3 is lt(5) }}").render(), equals('True'));
      expect(Template("{{ 3 is le(3) }}").render(), equals('True'));

      expect(Template("{{ 1 is in([1, 2]) }}").render(), equals('True'));
    });

    test('attr filter', () {
      final data = {
        'd': {'a': 1},
      };
      expect(Template("{{ d|attr('a') }}").render(data), equals('1'));
      expect(Template("{{ d|attr('b') }}").render(data), equals(''));
    });

    test('sort and unique and reverse', () {
      expect(
        Template("{{ [3, 1, 2]|sort|join(',') }}").render(),
        equals('1,2,3'),
      );
      expect(
        Template("{{ [3, 1, 2]|sort(reverse=true)|join(',') }}").render(),
        equals('3,2,1'),
      );
      // case insensitive
      expect(
        Template("{{ ['b', 'A']|sort|join(',') }}").render(),
        equals('A,b'),
      ); // standard sort depends on impl?
      // builtins.dart sort defaults to case_sensitive=false if not specified?
      // check code: caseSensitive = kwargs['case_sensitive']?.asBool ?? false;
      // So 'b' and 'A'. 'a' < 'b'. So 'A', 'b'.

      expect(
        Template("{{ ['a', 'b', 'a']|unique|join(',') }}").render(),
        equals('a,b'),
      );

      expect(Template("{{ 'abc'|reverse }}").render(), equals('cba'));
      expect(
        Template("{{ [1, 2]|reverse|join(',') }}").render(),
        equals('2,1'),
      );
    });

    test('selectattr and rejectattr', () {
      final data = {
        'users': [
          {'active': true, 'id': 1},
          {'active': false, 'id': 2},
        ],
      };
      expect(
        Template(
          "{{ users|selectattr('active')|map(attribute='id')|join(',') }}",
        ).render(data),
        equals('1'),
      );
      expect(
        Template(
          "{{ users|rejectattr('active')|map(attribute='id')|join(',') }}",
        ).render(data),
        equals('2'),
      );

      // With test
      expect(
        Template(
          "{{ users|selectattr('id', 'eq', 2)|map(attribute='id')|join(',') }}",
        ).render(data),
        equals('2'),
      );
    });

    test('join filter', () {
      expect(Template("{{ [1, 2]|join }}").render(), equals('12'));
      expect(Template("{{ [1, 2]|join('|') }}").render(), equals('1|2'));

      final data = {
        'items': [
          {'v': 1},
          {'v': 2},
        ],
      };
      expect(
        Template("{{ items|join(',', attribute='v') }}").render(data),
        equals('1,2'),
      );
    });

    test('tojson filter coverage', () {
      final data = {
        'a': 1,
        'b': [2, 3],
      };
      expect(
        Template("{{ data|tojson }}").render({'data': data}),
        equals('{"a": 1, "b": [2, 3]}'),
      );
      // Indent
      // We can't easily match exact indented string in expect, but we can check if it contains newlines
      final json = Template(
        "{{ data|tojson(indent=2) }}",
      ).render({'data': data});
      expect(json, contains('\n'));
      expect(json, contains('  "a": 1'));
    });

    group('Member Methods', () {
      test('List members', () {
        // append
        final tpl = Template('{% do l.append(2) %}{{ l|join }}');
        // Note: modify-in-place requires the list to be mutable in context and passed closely depending on implementation.
        // But internal list member `append` modifies the wrapper's list?
        // JinjaList wraps a List. If we pass a Dart List, it gets wrapped.

        // However, `do` must be supported. If implementation supports do statement.
        // Let's see if it works. `l` must be passed as variable.
        // Pass a mutable list.
        expect(
          tpl.render({
            'l': [1],
          }),
          equals('12'),
        );

        // pop
        expect(Template("{{ [1, 2, 3].pop() }}").render(), equals('3'));
        expect(Template("{{ [1, 2, 3].pop(0) }}").render(), equals('1'));
        try {
          Template("{{ [1, 2, 3].pop(10) }}").render();
          fail('Should throw exception');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('Map members', () {
        expect(Template("{{ {'a': 1}.get('a') }}").render(), equals('1'));
        expect(Template("{{ {'a': 1}.get('b', 2) }}").render(), equals('2'));
        expect(
          Template("{{ {'a': 1}.keys()|list|join }}").render(),
          equals('a'),
        );
        expect(
          Template("{{ {'a': 1}.values()|list|join }}").render(),
          equals('1'),
        );
        // items is tricky to print as is, usually iterated.
      });

      test('String members', () {
        expect(
          Template("{{ 'a b c'.split()|join(',') }}").render(),
          equals('a,b,c'),
        ); // split default by space.
        expect(
          Template("{{ 'a-b-c'.split('-')|join(',') }}").render(),
          equals('a,b,c'),
        );

        expect(
          Template("{{ 'abc'.startswith('a') }}").render(),
          equals('True'),
        );
        expect(Template("{{ 'abc'.endswith('c') }}").render(), equals('True'));

        expect(Template("{{ 'a'.upper() }}").render(), equals('A'));
        expect(Template("{{ 'A'.lower() }}").render(), equals('a'));
      });
    });

    group('Is Tests', () {
      test('Type checks', () {
        expect(Template("{{ 1 is integer }}").render(), equals('True'));
        expect(Template("{{ 1.5 is float }}").render(), equals('True'));
        expect(Template("{{ 's' is string }}").render(), equals('True'));
        expect(Template("{{ true is boolean }}").render(), equals('True'));
        expect(Template("{{ none is none }}").render(), equals('True'));
        expect(Template("{{ x is undefined }}").render(), equals('True'));
        expect(Template("{{ 1 is defined }}").render(), equals('True'));
      });

      test('Collection checks', () {
        expect(Template("{{ [] is sequence }}").render(), equals('True'));
        expect(Template("{{ {} is mapping }}").render(), equals('True'));
        expect(Template("{{ 's' is iterable }}").render(), equals('True'));
      });

      test('Numeric checks', () {
        expect(Template("{{ 1 is odd }}").render(), equals('True'));
        expect(Template("{{ 2 is even }}").render(), equals('True'));
        expect(Template("{{ 5 is gt(3) }}").render(), equals('True'));
        expect(Template("{{ 3 is lt(5) }}").render(), equals('True'));
      });
    });

    group('Filters Coverage', () {
      test('indent', () {
        expect(Template("{{ 'a\nb'|indent(2) }}").render(), equals('a\n  b'));
        expect(
          Template("{{ 'a\nb'|indent(2, true) }}").render(),
          equals('  a\n  b'),
        );
        expect(
          Template("{{ '\n'|indent(2, false, true) }}").render(),
          equals('\n  '),
        ); // blank=true indents empty lines
      });

      test('strftime', () {
        // Just check it runs and returns a string, format dependent
        // "%Y" should be current year.
        final year = DateTime.now().year.toString();
        expect(Template("{{ '%Y'|strftime_now }}").render(), equals(year));
      });

      test('map/select/reject complex', () {
        // map with default
        expect(
          Template(
            "{{ [{'a': 1}, {}]|map(attribute='a', default=2)|join(',') }}",
          ).render(),
          equals('1,2'),
        );

        // selectattr with test
        expect(
          Template(
            "{{ [{'a': 1}, {'a': 2}]|selectattr('a', 'eq', 1)|map(attribute='a')|join }}",
          ).render(),
          equals('1'),
        );

        // rejectattr with test
        expect(
          Template(
            "{{ [{'a': 1}, {'a': 2}]|rejectattr('a', 'eq', 1)|map(attribute='a')|join }}",
          ).render(),
          equals('2'),
        );
      });
    });
  });

  group('tojson matches llama.cpp', () {
    // Expected values are llama.cpp common/jinja output at 7fe450e1.
    final cases = <(String, String, Map<String, dynamic>, String)>[
      (
        'spaces separators as json.dumps does',
        "{{ {'a': 1, 'b': [1, 2]} | tojson }}",
        {},
        '{"a": 1, "b": [1, 2]}',
      ),
      (
        'keeps insertion key order',
        "{{ {'b': 1, 'a': 2, 'c': {'z': 1, 'y': 2}} | tojson }}",
        {},
        '{"b": 1, "a": 2, "c": {"z": 1, "y": 2}}',
      ),
      (
        'nested values',
        "{{ {'a': [1, {'b': [none, true, false]}], 'c': {}} | tojson }}",
        {},
        '{"a": [1, {"b": [null, true, false]}], "c": {}}',
      ),
      ('empty containers', "{{ [[], {}, ''] | tojson }}", {}, '[[], {}, ""]'),
      (
        'negative indent is inline',
        "{{ {'a': 1, 'b': [1, 2]} | tojson(indent=-1) }}",
        {},
        '{"a": 1, "b": [1, 2]}',
      ),
      (
        'ignores a string indent',
        "{{ {'a': 1} | tojson(indent='  ') }}",
        {},
        '{"a": 1}',
      ),
      (
        'ignores a boolean indent',
        '{{ [1] | tojson(indent=true) }}',
        {},
        '[1]',
      ),
      ('ignores a float indent', '{{ [1] | tojson(indent=2.0) }}', {}, '[1]'),
      (
        'first positional argument is ensure_ascii',
        "{{ {'a': 'é'} | tojson(2) }}",
        {},
        '{"a": "\\u00e9"}',
      ),
      (
        'second positional argument is indent',
        "{{ {'a': 'é'} | tojson(false, 2) }}",
        {},
        '{\n  "a": "é"\n}',
      ),
      (
        'one separator sets only the item separator',
        "{{ {'a': 1, 'b': [1, 2]} | tojson(separators=[';']) }}",
        {},
        '{"a": 1;"b": [1;2]}',
      ),
      (
        'ignores string separators',
        "{{ [1, 2] | tojson(separators=';=') }}",
        {},
        '[1, 2]',
      ),
      ('keeps non-ASCII by default', "{{ 'é✓😀中' | tojson }}", {}, '"é✓😀中"'),
      (
        'keeps non-ASCII keys and values',
        '{{ x | tojson }}',
        {
          'x': {'é': 'Montréal ✓ 😀'},
        },
        '{"é": "Montréal ✓ 😀"}',
      ),
      (
        'ensure_ascii escapes UTF-16 code units',
        '{{ x | tojson(ensure_ascii=true) }}',
        {
          'x': {'é': 'Montréal ✓ 😀'},
        },
        '{"\\u00e9": "Montr\\u00e9al \\u2713 \\ud83d\\ude00"}',
      ),
      ('positional ensure_ascii false', "{{ 'é' | tojson(false) }}", {}, '"é"'),
      (
        'ensure_ascii leaves separators alone',
        "{{ {'a': 'é'} | tojson(ensure_ascii=true, separators=('é', ' ✓ ')) }}",
        {},
        '{"a" ✓ "\\u00e9"}',
      ),
      (
        'escapes only control characters, quote and backslash',
        '{{ x | tojson }}',
        {'x': '\n\t\r\b\f\u{1}\u{1f}\u{7f}\u{2028}/\\"'},
        '"\\n\\t\\r\\b\\f\\u0001\\u001f\u{7f}\u{2028}/\\\\\\""',
      ),
      (
        'NUL, DEL and Latin-1',
        '{{ x | tojson }}',
        {'x': '\u{0}\u{7f}\u{80}ÿ'},
        '"\\u0000\u{7f}\u{80}ÿ"',
      ),
      (
        'integers',
        '{{ x | tojson }}',
        {
          'x': [0, -5, 9007199254740991, -12345678901234],
        },
        '[0, -5, 9007199254740991, -12345678901234]',
      ),
      (
        'float literals use %g',
        '{{ [1.0, -2.25, 0.1, 1.5, 3.14159265, 100000.0, 1234567.0] | tojson }}',
        {},
        '[1, -2.25, 0.1, 1.5, 3.14159, 100000, 1.23457e+06]',
      ),
      (
        'floats use %g with 6 significant digits',
        '{{ x | tojson }}',
        {
          'x': [
            1.0,
            0.5,
            -2.25,
            3.14159265,
            1e+20,
            1e-07,
            1.5e+300,
            -0.0,
            123456.0,
            1234567.5,
            0.0001,
            1e-05,
          ],
        },
        '[1, 0.5, -2.25, 3.14159, 1e+20, 1e-07, 1.5e+300, -0, 123456, 1.23457e+06, 0.0001, 1e-05]',
      ),
      (
        'float rounding ties go to even',
        '{{ [1234565.0, 0.0009765625, 1234575.0, 999999.5, 9999995.0, 0.5, 0.000025, 123456.5] | tojson }}',
        {},
        '[1.23456e+06, 0.000976562, 1.23458e+06, 1e+06, 1e+07, 0.5, 2.5e-05, 123456]',
      ),
      (
        'large and small floats',
        '{{ [1000000000000000.0, 10000000000000000.0, 123456789012.0, 100000.0, 1000000.0, 0.001, 0.0001234567] | tojson }}',
        {},
        '[1e+15, 1e+16, 1.23457e+11, 100000, 1e+06, 0.001, 0.000123457]',
      ),
      (
        'subnormal, maximum and a carry into the exponent',
        '{{ x | tojson }}',
        {
          'x': [
            5e-324,
            2.2250738585072014e-308,
            1.7976931348623157e308,
            9.9999949e-5,
            0.000099999951,
          ],
        },
        '[4.94066e-324, 2.22507e-308, 1.79769e+308, 9.99999e-05, 0.0001]',
      ),
      (
        'booleans and none',
        '{{ [true, false, none, True, False, None] | tojson }}',
        {},
        '[true, false, null, true, false, null]',
      ),
      ('tuple is an array', "{{ (1, 'a') | tojson }}", {}, '[1, "a"]'),
      ('integer key', "{{ {1: 'a'} | tojson }}", {}, '{"1": "a"}'),
      ('float key', "{{ {2.5: 'a'} | tojson }}", {}, '{"2.5": "a"}'),
      ('boolean key', "{{ {true: 'a'} | tojson }}", {}, '{"True": "a"}'),
      ('none key', "{{ {none: 'a'} | tojson }}", {}, '{"None": "a"}'),
      (
        'tool declaration',
        '{{ tools | tojson }}',
        {
          'tools': [
            {
              'type': 'function',
              'function': {
                'name': 'get_weather',
                'description':
                    'Get the weather in a city, e.g. "Montréal" <or> \'Paris\' & more',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'city': {'type': 'string', 'description': 'City name'},
                    'days': {
                      'type': 'integer',
                      'minimum': 1,
                      'maximum': 7,
                      'default': 1.5,
                    },
                  },
                  'required': ['city'],
                },
              },
            },
          ],
        },
        '[{"type": "function", "function": {"name": "get_weather", "description": "Get the weather in a city, e.g. \\"Montréal\\" <or> \'Paris\' & more", "parameters": {"type": "object", "properties": {"city": {"type": "string", "description": "City name"}, "days": {"type": "integer", "minimum": 1, "maximum": 7, "default": 1.5}}, "required": ["city"]}}}]',
      ),
      (
        'tool declaration with indent',
        '{{ tools | tojson(indent=4) }}',
        {
          'tools': [
            {
              'type': 'function',
              'function': {
                'name': 'get_weather',
                'description':
                    'Get the weather in a city, e.g. "Montréal" <or> \'Paris\' & more',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'city': {'type': 'string', 'description': 'City name'},
                    'days': {
                      'type': 'integer',
                      'minimum': 1,
                      'maximum': 7,
                      'default': 1.5,
                    },
                  },
                  'required': ['city'],
                },
              },
            },
          ],
        },
        '[\n    {\n        "type": "function",\n        "function": {\n            "name": "get_weather",\n            "description": "Get the weather in a city, e.g. \\"Montréal\\" <or> \'Paris\' & more",\n            "parameters": {\n                "type": "object",\n                "properties": {\n                    "city": {\n                        "type": "string",\n                        "description": "City name"\n                    },\n                    "days": {\n                        "type": "integer",\n                        "minimum": 1,\n                        "maximum": 7,\n                        "default": 1.5\n                    }\n                },\n                "required": [\n                    "city"\n                ]\n            }\n        }\n    }\n]',
      ),
    ];
    for (final (name, source, data, expected) in cases) {
      test(name, () => expect(Template(source).render(data), expected));
    }

    test('a whole-number double from Dart is an integer on the web', () {
      final output = Template(
        '{{ x | tojson }}|{{ x }}',
      ).render({'x': 1234567.0});
      expect(
        output,
        identical(0, 0.0) ? '1234567|1234567' : '1.23457e+06|1234567.0',
      );
    });
  });

  group('min and max with attribute return the item', () {
    final data = <String, dynamic>{
      'items': [
        {'x': 2, 'n': 'b'},
        {'x': 1, 'n': 'A'},
        {'x': 3, 'n': 'c'},
      ],
      'pairs': [
        [2, 'x'],
        [1, 'y'],
      ],
      'keyed': [
        {'n': 'b', 'x': 1},
        {'n': 'a', 'x': 2},
      ],
    };

    // Jinja2 3.1.6 gives each of these outputs; llama.cpp 7fe450e1 throws
    // not-implemented for `attribute`.
    for (final (source, expected) in [
      ("{{ items|min(attribute='x') }}", "{'x': 1, 'n': 'A'}"),
      ("{{ items|max(attribute='x') }}", "{'x': 3, 'n': 'c'}"),
      ("{{ (items|min(attribute='x')).n }}", 'A'),
      ("{{ (items|max(attribute='n')).x }}", '3'),
      ("{{ items|min(attribute='x')|tojson }}", '{"x": 1, "n": "A"}'),
      ("{{ keyed|min(false, 'x') }}", "{'n': 'b', 'x': 1}"),
      ('{{ pairs|min(attribute=0) }}', "[1, 'y']"),
      (
        "{{ [{'x': 1, 'i': 'first'}, {'x': 1, 'i': 'second'}]"
            "|min(attribute='x') }}",
        "{'x': 1, 'i': 'first'}",
      ),
      (
        "{{ [{'x': 1, 'i': 'first'}, {'x': 1, 'i': 'second'}]"
            "|max(attribute='x') }}",
        "{'x': 1, 'i': 'first'}",
      ),
      (
        "{{ [{'p': {'q': 2}}, {'p': {'q': 1}}]|min(attribute='p.q') }}",
        "{'p': {'q': 1}}",
      ),
    ]) {
      test(source, () {
        expect(Template(source).render(data), expected);
      });
    }

    test('unchanged without attribute or with an empty list', () {
      expect(Template('{{ [3, 1, 2]|min }}').render(), '1');
      expect(Template('{{ [3, 1, 2]|max }}').render(), '3');
      expect(Template("[{{ []|min(attribute='x') }}]").render(), '[]');
    });
  });

  group('indent with a string width', () {
    final data = <String, dynamic>{'data': 'foo\nbar'};

    // llama.cpp 7fe450e1 and Jinja2 3.1.6 give each of these outputs.
    for (final (source, expected) in [
      ("{{ data|indent(width='>>>>') }}", 'foo\n>>>>bar'),
      ("{{ data|indent('> ') }}", 'foo\n> bar'),
      ("{{ data|indent('> ', true) }}", '> foo\n> bar'),
      ("{{ 'a\n\nb'|indent('-', blank=true) }}", 'a\n-\n-b'),
      ("{{ data|indent('') }}", 'foo\nbar'),
    ]) {
      test(source, () {
        expect(Template(source).render(data), expected);
      });
    }

    test('integer and default widths are unchanged', () {
      expect(Template('{{ data|indent(2) }}').render(data), 'foo\n  bar');
      expect(Template('{{ data|indent }}').render(data), 'foo\n    bar');
    });
  });

  group('str.format', () {
    final data = <String, dynamic>{'s': 'hello', 'n': 3};

    // llama.cpp 7fe450e1 and Jinja2 3.1.6 give each of these outputs.
    for (final (source, expected) in [
      ("{{ '<{}|{}>'.format(s, 42) }}", '<hello|42>'),
      ("{{ 'plain'.format() }}", 'plain'),
      (
        "{{ '{}|{}|{}|{}|{}'.format(1.5, true, none, [1, 'a'], {'k': 1}) }}",
        "1.5|True|None|[1, 'a']|{'k': 1}",
      ),
      ("{% set f = '[{}]' %}{{ f.format(n) }}", '[3]'),
      ("{{ '{}'.format(1, 2) }}", '1'),
      ("{{ '{}'.format(1, x=2) }}", '1'),
    ]) {
      test(source, () {
        expect(Template(source).render(data), expected);
      });
    }

    test('keeps input marking of arguments and the format string', () {
      final user = JinjaString.user('<b>');
      expect(
        Template("{{ '<{}>'.format(s) }}").render({'s': user}),
        '<&lt;b&gt;>',
      );
      expect(Template('{{ s.format(1) }}').render({'s': user}), '&lt;b&gt;');
      expect(
        Template('{{ f.format(1) }}').render({'f': JinjaString.user('<{}>')}),
        '&lt;1&gt;',
      );
    });

    test('keeps a lone closing brace, as llama.cpp does', () {
      expect(Template("{{ 'a}b'.format() }}").render(), 'a}b');
    });

    test('throws when an argument is missing', () {
      expect(
        () => Template("{{ '{} {}'.format(1) }}").render(),
        throwsA(
          predicate(
            (Object e) =>
                '$e'.contains('format() expected at least 2 arguments, got 1'),
          ),
        ),
      );
    });

    // llama.cpp 7fe450e1 throws not-implemented for these forms.
    for (final source in [
      "{{ '{1}-{0}-{1}'.format('a', 'b') }}",
      "{{ '{name} is {age}'.format(name='Bob', age=7) }}",
      "{{ '{{}} {} {{x}}'.format('mid') }}",
      "{{ '{:>5}'.format(1) }}",
      "{{ 'a{'.format() }}",
    ]) {
      test('throws: $source', () {
        expect(
          () => Template(source).render(),
          throwsA(
            predicate(
              (Object e) => '$e'.contains(
                "format() only supports simple '{}' placeholders",
              ),
            ),
          ),
        );
      });
    }
  });

  group('indent line handling', () {
    // llama.cpp 7fe450e1 and Jinja2 3.1.6 give each of these outputs.
    for (final (input, args, expected) in [
      ('foo\n', '', 'foo\n'),
      ('foo\n', '(2, true)', '  foo\n'),
      ('foo\n\n', '', 'foo\n\n'),
      ('foo\nbar\n', '', 'foo\n    bar\n'),
      ('a\n\nb\n', '(2)', 'a\n\n  b\n'),
      ('\n', '', '\n'),
      ('\n', '(2, true)', '  \n'),
      ('', '', ''),
      ('\nfoo', '(2, true)', '  \n  foo'),
    ]) {
      test('${jsonEncode(input)}|indent$args', () {
        expect(Template('{{ s|indent$args }}').render({'s': input}), expected);
      });
    }

    // llama.cpp 7fe450e1 gives an empty string; Jinja2 3.1.6 gives '  '.
    test("''|indent(2, true) follows llama.cpp", () {
      expect(Template('{{ s|indent(2, true) }}').render({'s': ''}), '');
    });

    // Jinja2 3.1.6 gives these; llama.cpp 7fe450e1 drops the leading empty
    // lines.
    for (final (input, args, expected) in [
      ('\nfoo', '', '\n    foo'),
      ('\n\nfoo', '(2, false, true)', '\n  \n  foo'),
    ]) {
      test('unchanged: ${jsonEncode(input)}|indent$args', () {
        expect(Template('{{ s|indent$args }}').render({'s': input}), expected);
      });
    }

    // llama.cpp 7fe450e1 and Jinja2 3.1.6 give each of these outputs.
    for (final (input, args, expected) in [
      ('\n', '(2, false, true)', '\n  '),
      ('foo\n', '(2, false, true)', 'foo\n  '),
    ]) {
      test('unchanged: ${jsonEncode(input)}|indent$args', () {
        expect(Template('{{ s|indent$args }}').render({'s': input}), expected);
      });
    }

    for (final (input, expected) in [
      ('foo', 'foo'),
      ('foo\r\nbar', 'foo\r\n    bar'),
      ('  \nfoo', '  \n    foo'),
    ]) {
      test('unchanged: ${jsonEncode(input)}|indent', () {
        expect(Template('{{ s|indent }}').render({'s': input}), expected);
      });
    }
  });

  group('Tests that take an argument', () {
    // llama.cpp 7fe450e1 and Jinja2 3.1.6 both throw for each of these.
    for (final source in [
      '{{ a is divisibleby }}',
      '{{ a is eq }}',
      '{{ a is equalto }}',
      '{{ a is ne }}',
      '{{ a is gt }}',
      '{{ a is greaterthan }}',
      '{{ a is ge }}',
      '{{ a is lt }}',
      '{{ a is lessthan }}',
      '{{ a is in }}',
      '{{ a is divisibleby -a }}',
      '{{ -2 is eq -a }}',
      "{{ [1, 2]|select('eq')|list }}",
    ]) {
      test('throw without one: $source', () {
        expect(
          () => Template(source).render({'a': 2}),
          throwsA(
            predicate((Object e) => '$e'.contains('Test expected 2 arguments')),
          ),
        );
      });
    }

    for (final source in [
      '{{ a is le }}',
      '{{ a is sameas }}',
      '{{ a is startingwith }}',
      '{{ a is endingwith }}',
      '{{ a is ieq }}',
    ]) {
      test('throw without one: $source', () {
        expect(
          () => Template(source).render({'a': 2}),
          throwsA(
            predicate((Object e) => '$e'.contains('Test expected 2 arguments')),
          ),
        );
      });
    }

    for (final (source, expected) in [
      ('{{ a is divisibleby(-a) }}', 'True'),
      ('{{ -2 is eq(-a) }}', 'True'),
      ('{{ a is divisibleby 2 }}', 'True'),
      ("{{ [1, 2]|select('eq', 2)|join(',') }}", '2'),
    ]) {
      test('unchanged: $source', () {
        expect(Template(source).render({'a': 2}), expected);
      });
    }
  });

  group('format filter', () {
    // llama.cpp 7fe450e1 gives each of these outputs; the filter reaches its
    // `{}`-only string format method.
    for (final (source, expected) in [
      ("{{ '{}-{}'|format(1, 2) }}", '1-2'),
      ("{{ '%s-%s'|format(1, 2) }}", '%s-%s'),
      ("{{ 'plain'|format }}", 'plain'),
      ("{{ '%(x)s'|format(x=1) }}", '%(x)s'),
    ]) {
      test(source, () {
        expect(Template(source).render(), expected);
      });
    }

    for (final (source, message) in [
      ('{{ a|format }}', "Unknown filter 'format' for type Integer"),
      ('{{ none|format }}', "Unknown filter 'format' for type None"),
      ("{{ '{}'|format }}", 'format() expected at least 1 arguments, got 0'),
      (
        "{{ '{0}'|format(1) }}",
        "format() only supports simple '{}' placeholders",
      ),
    ]) {
      test('throws: $source', () {
        expect(
          () => Template(source).render({'a': 2}),
          throwsA(predicate((Object e) => '$e'.contains(message))),
        );
      });
    }
  });

  group('Filters on none', () {
    // llama.cpp 7fe450e1 and Jinja2 3.1.6 give each of these outputs.
    const cases = {
      '{{ x | selectattr("a") | list | length }}': '0',
      '{{ x | selectattr("type", "equalto", "x") | list | tojson }}': '[]',
      '{{ x | rejectattr("a") | list | tojson }}': '[]',
      '{{ x | select("odd") | list | tojson }}': '[]',
      '{{ x | reject("odd") | list | tojson }}': '[]',
      '{{ x | map("upper") | list | tojson }}': '[]',
      '{{ x | map(attribute="a") | list | tojson }}': '[]',
      '{% for y in x | selectattr("a") %}{{ y }}{% endfor %}.': '.',
    };
    cases.forEach((source, expected) {
      test('renders $source', () {
        expect(Template(source).render({'x': null}), expected);
      });
    });

    test('unique gives an empty list', () {
      // llama.cpp 7fe450e1 output; Jinja2 raises.
      expect(
        Template('{{ x | unique | list | tojson }}').render({'x': null}),
        '[]',
      );
    });

    test('default replaces none', () {
      // llama.cpp 7fe450e1 output; Jinja2 keeps none.
      for (final source in [
        '{{ x | default("d") }}',
        '{{ x | default("d", false) }}',
        '{{ x | d("d") }}',
      ]) {
        expect(Template(source).render({'x': null}), 'd', reason: source);
      }
    });

    // llama.cpp 7fe450e1 and Jinja2 3.1.6 give each of these outputs.
    const guards = {
      '{{ "" | default("d") }}': '',
      '{{ "" | default("d", true) }}': 'd',
      '{{ 0 | default("d", true) }}': 'd',
      '{{ u | default("d") }}': 'd',
      '{{ [{"a": 0}, {"a": 1}] | rejectattr("a") | list | tojson }}':
          '[{"a": 0}]',
      '{{ [{"a": 0}, {"a": 1}] | selectattr("a") | list | tojson }}':
          '[{"a": 1}]',
    };
    guards.forEach((source, expected) {
      test('renders $source', () {
        expect(Template(source).render({'x': null}), expected);
      });
    });
  });
  group('tojson keeps input marking', () {
    // llama.cpp 7fe450e19 gives each output with the input unescaped, as
    // its tojson drops the marking and it never escapes. Only the input
    // text is escaped, after JSON escaping; the JSON's own quotes are not.
    final x = JinjaString.user('<b>');
    final cases = <(String, Map<String, dynamic>, String)>[
      ('{{ x | tojson }}', {'x': x}, '"&lt;b&gt;"'),
      ('{{ {"k": x} | tojson }}', {'x': x}, '{"k": "&lt;b&gt;"}'),
      (
        '{{ d | tojson }}',
        {
          'd': {JinjaString.user('<k>'): 1},
        },
        '{"&lt;k&gt;": 1}',
      ),
      (
        '{{ d | tojson }}',
        {
          'd': {
            'a': [
              x,
              {'c': x},
            ],
          },
        },
        '{"a": ["&lt;b&gt;", {"c": "&lt;b&gt;"}]}',
      ),
      (
        '{{ x | tojson }}',
        {'x': JinjaString.user('"q"')},
        r'"\&quot;q\&quot;"',
      ),
      (
        '{{ x | tojson(ensure_ascii=true) }}',
        {'x': JinjaString.user('é<')},
        r'"\u00e9&lt;"',
      ),
      (
        '{{ {"k": x} | tojson(indent=2) }}',
        {'x': x},
        '{\n  "k": "&lt;b&gt;"\n}',
      ),
      (
        '{{ [x, 1] | tojson(separators=(sep, ":")) }}',
        {'x': x, 'sep': JinjaString.user(';<')},
        '["&lt;b&gt;";&lt;1]',
      ),
      (
        '{{ {x: 1} | tojson(separators=(",", sep)) }}',
        {'x': x, 'sep': JinjaString.user(':<')},
        '{"&lt;b&gt;":&lt;1}',
      ),
      (
        '{{ [x, 1] | tojson(separators=("<,>", ":")) }}',
        {'x': x},
        '["&lt;b&gt;"<,>1]',
      ),
      // llama.cpp does not implement sort_keys.
      (
        '{{ d | tojson(sort_keys=true) }}',
        {
          'd': {'b': 1, JinjaString.user('<a>'): x},
        },
        '{"&lt;a&gt;": "&lt;b&gt;", "b": 1}',
      ),
      ('{{ x | tojson | safe }}', {'x': x}, '"<b>"'),
    ];
    for (final (source, data, expected) in cases) {
      test('renders $source', () {
        expect(Template(source).render(data), expected);
      });
    }

    test('marks only the input text', () {
      final result = Template(
        '{{ {"k": x} | tojson }}',
      ).renderJinjaResult({'x': x});
      expect(result.parts, [
        const JinjaStringPart('{"k": "', false),
        const JinjaStringPart('&lt;b&gt;', true),
        const JinjaStringPart('"}', false),
      ]);
    });

    test('is safe template text without input', () {
      const source = '{{ d | tojson }}|{{ d | tojson is escaped }}';
      final data = {
        'd': {'<k>': '<b>'},
      };
      expect(Template(source).render(data), '{"<k>": "<b>"}|True');
    });
  });

  group('join keeps input marking', () {
    // llama.cpp 7fe450e19 gives each output with the input unescaped, as
    // its join drops the marking and it never escapes. It does not map with
    // a filter, join a string, or join none or a list.
    final x = JinjaString.user('<b>');
    final cases = <(String, Map<String, dynamic>, String)>[
      ('{{ [x, "<i>"] | join }}', {'x': x}, '&lt;b&gt;<i>'),
      (
        '{{ [x, x] | join(sep) }}',
        {'x': x, 'sep': JinjaString.user('<,>')},
        '&lt;b&gt;&lt;,&gt;&lt;b&gt;',
      ),
      ('{{ [x, x] | join("<,>") }}', {'x': x}, '&lt;b&gt;<,>&lt;b&gt;'),
      (
        '{{ l | map("upper") | join }}',
        {
          'l': [JinjaString.user('<a>'), x],
        },
        '&lt;A&gt;&lt;B&gt;',
      ),
      (
        '{{ d | map(attribute="n") | join(", ") }}',
        {
          'd': [
            {'n': JinjaString.user('<a>')},
            {'n': x},
          ],
        },
        '&lt;a&gt;, &lt;b&gt;',
      ),
      (
        '{{ d | join(", ", attribute="n") }}',
        {
          'd': [
            {'n': x},
          ],
        },
        '&lt;b&gt;',
      ),
      ('{{ [x, 1, none] | join }}', {'x': x}, '&lt;b&gt;1None'),
      ('{{ [[x]] | join }}', {'x': x}, "['&lt;b&gt;']"),
      ('{{ x | join }}', {'x': x}, '&lt;b&gt;'),
      ('{{ [x | safe] | join }}', {'x': x}, '<b>'),
    ];
    for (final (source, data, expected) in cases) {
      test('renders $source', () {
        expect(Template(source).render(data), expected);
      });
    }

    test('marks only the input text', () {
      final result = Template(
        '{{ [x, x] | join(", ") }}',
      ).renderJinjaResult({'x': x});
      expect(result.parts, [
        const JinjaStringPart('&lt;b&gt;', true),
        const JinjaStringPart(', ', false),
        const JinjaStringPart('&lt;b&gt;', true),
      ]);
    });
  });
}
