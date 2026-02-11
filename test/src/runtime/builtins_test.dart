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
}
