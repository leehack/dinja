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
        equals('{"a":1,"b":[2,3]}'),
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
        Template("{{ items | max(attribute='age') }}").render(data),
        equals('40'),
      );
      expect(
        Template("{{ items | min(attribute='price') }}").render(data),
        equals('5'),
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
      // min/max return the item that has the min/max attribute, UNLESS it's just value comparison?
      // Checking builtins.dart: "return attribute != null ? mVal : m;"
      // Wait, if attribute is present, it returns mVal (the attribute value).
      expect(
        Template("{{ items|min(attribute='v') }}").render(data),
        equals("5"),
      );
      expect(
        Template("{{ items|max(attribute='v') }}").render(data),
        equals("15"),
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
        equals('{"a":1,"b":[2,3]}'),
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
}
