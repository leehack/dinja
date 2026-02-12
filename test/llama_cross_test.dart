import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Llama.cpp Cross Tests', () {
    test('trim_blocks removes newline after tag', () {
      final template = Template(
        '{% if true %}\n"        "hello\n"        "{% endif %}\n',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('hello\n'));
    });

    test('lstrip_blocks removes leading whitespace', () {
      final template = Template(
        '    {% if true %}\n"        "    hello\n"        "    {% endif %}\n',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('    hello\n'));
    });

    test('for loop with trim_blocks', () {
      final template = Template(
        '{% for i in items %}\n"        "{{ i }}\n"        "{% endfor %}\n',
      );
      final Map<String, dynamic> data = {
        "items": [1, 2, 3],
      };
      expect(template.render(data), equals('1\n2\n3\n'));
    });

    test('explicit strip both', () {
      final template = Template(
        '  {%- if true -%}  \n"        "hello\n"        "  {%- endif -%}  \n',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('hello'));
    });

    test('expression whitespace control', () {
      final template = Template('  {{- \'hello\' -}}  \n');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('hello'));
    });

    test('inline block no newline', () {
      final template = Template('{% if true %}yes{% endif %}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('if true', () {
      final template = Template('{% if cond %}yes{% endif %}');
      final Map<String, dynamic> data = {"cond": true};
      expect(template.render(data), equals('yes'));
    });

    test('if false', () {
      final template = Template('{% if cond %}yes{% endif %}');
      final Map<String, dynamic> data = {"cond": false};
      expect(template.render(data), equals(''));
    });

    test('if else', () {
      final template = Template('{% if cond %}yes{% else %}no{% endif %}');
      final Map<String, dynamic> data = {"cond": false};
      expect(template.render(data), equals('no'));
    });

    test('if elif else', () {
      final template = Template(
        '{% if a %}A{% elif b %}B{% else %}C{% endif %}',
      );
      final Map<String, dynamic> data = {"a": false, "b": true};
      expect(template.render(data), equals('B'));
    });

    test('nested if', () {
      final template = Template(
        '{% if outer %}{% if inner %}both{% endif %}{% endif %}',
      );
      final Map<String, dynamic> data = {"outer": true, "inner": true};
      expect(template.render(data), equals('both'));
    });

    test('comparison operators', () {
      final template = Template('{% if x > 5 %}big{% endif %}');
      final Map<String, dynamic> data = {"x": 10};
      expect(template.render(data), equals('big'));
    });

    test('object comparison', () {
      final template = Template(
        '{% if {0: 1, none: 2, 1.0: 3, \'0\': 4, true: 5} == {false: 1, none: 2, 1: 5, \'0\': 4} %}equal{% endif %}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('equal'));
    });

    test('array comparison', () {
      final template = Template(
        '{% if [0, 1.0, false] == [false, 1, 0.0] %}equal{% endif %}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('equal'));
    });

    test('logical and', () {
      final template = Template('{% if a and b %}both{% endif %}');
      final Map<String, dynamic> data = {"a": true, "b": true};
      expect(template.render(data), equals('both'));
    });

    test('logical or', () {
      final template = Template('{% if a or b %}either{% endif %}');
      final Map<String, dynamic> data = {"a": false, "b": true};
      expect(template.render(data), equals('either'));
    });

    test('logical not', () {
      final template = Template('{% if not a %}negated{% endif %}');
      final Map<String, dynamic> data = {"a": false};
      expect(template.render(data), equals('negated'));
    });

    test('in operator (element in array)', () {
      final template = Template('{% if \'x\' in items %}found{% endif %}');
      final Map<String, dynamic> data = {
        "items": ["x", "y"],
      };
      expect(template.render(data), equals('found'));
    });

    test('in operator (substring)', () {
      final template = Template('{% if \'bc\' in \'abcd\' %}found{% endif %}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('found'));
    });

    test('in operator (object key)', () {
      final template = Template('{% if \'key\' in obj %}found{% endif %}');
      final Map<String, dynamic> data = {
        "obj": {"key": 1, "other": 2},
      };
      expect(template.render(data), equals('found'));
    });

    test('is defined', () {
      final template = Template(
        '{% if x is defined %}yes{% else %}no{% endif %}',
      );
      final Map<String, dynamic> data = {"x": 1};
      expect(template.render(data), equals('yes'));
    });

    test('is not defined', () {
      final template = Template(
        '{% if y is not defined %}yes{% else %}no{% endif %}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is undefined falsy', () {
      final template = Template('{{ \'yes\' if not y else \'no\' }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is undefined attribute falsy', () {
      final template = Template('{{ \'yes\' if not y.x else \'no\' }}');
      final Map<String, dynamic> data = {"y": true};
      expect(template.render(data), equals('yes'));
    });

    test('is undefined key falsy', () {
      final template = Template('{{ \'yes\' if not y[\'x\'] else \'no\' }}');
      final Map<String, dynamic> data = {
        "y": [[]],
      };
      expect(template.render(data), equals('yes'));
    });

    test('is empty array falsy', () {
      final template = Template('{{ \'yes\' if not y else \'no\' }}');
      final Map<String, dynamic> data = {"y": []};
      expect(template.render(data), equals('yes'));
    });

    test('is empty object falsy', () {
      final template = Template('{{ \'yes\' if not y else \'no\' }}');
      final Map<String, dynamic> data = {"y": {}};
      expect(template.render(data), equals('yes'));
    });

    test('is empty string falsy', () {
      final template = Template('{{ \'yes\' if not y else \'no\' }}');
      final Map<String, dynamic> data = {"y": ""};
      expect(template.render(data), equals('yes'));
    });

    test('is 0 falsy', () {
      final template = Template('{{ \'yes\' if not y else \'no\' }}');
      final Map<String, dynamic> data = {"y": 0};
      expect(template.render(data), equals('yes'));
    });

    test('is 0.0 falsy', () {
      final template = Template('{{ \'yes\' if not y else \'no\' }}');
      final Map<String, dynamic> data = {"y": 0.0};
      expect(template.render(data), equals('yes'));
    });

    test('is non-empty array truthy', () {
      final template = Template('{{ \'yes\' if y else \'no\' }}');
      final Map<String, dynamic> data = {
        "y": [""],
      };
      expect(template.render(data), equals('yes'));
    });

    test('is non-empty object truthy', () {
      final template = Template('{{ \'yes\' if y else \'no\' }}');
      final Map<String, dynamic> data = {
        "y": ["x", false],
      };
      expect(template.render(data), equals('yes'));
    });

    test('is non-empty string truthy', () {
      final template = Template('{{ \'yes\' if y else \'no\' }}');
      final Map<String, dynamic> data = {"y": "0"};
      expect(template.render(data), equals('yes'));
    });

    test('is 1 truthy', () {
      final template = Template('{{ \'yes\' if y else \'no\' }}');
      final Map<String, dynamic> data = {"y": 1};
      expect(template.render(data), equals('yes'));
    });

    test('is 1.0 truthy', () {
      final template = Template('{{ \'yes\' if y else \'no\' }}');
      final Map<String, dynamic> data = {"y": 1.0};
      expect(template.render(data), equals('yes'));
    });

    test('simple for', () {
      final template = Template('{% for i in items %}{{ i }}{% endfor %}');
      final Map<String, dynamic> data = {
        "items": [1, 2, 3],
      };
      expect(template.render(data), equals('123'));
    });

    test('loop.index', () {
      final template = Template(
        '{% for i in items %}{{ loop.index }}{% endfor %}',
      );
      final Map<String, dynamic> data = {
        "items": ["a", "b", "c"],
      };
      expect(template.render(data), equals('123'));
    });

    test('loop.index0', () {
      final template = Template(
        '{% for i in items %}{{ loop.index0 }}{% endfor %}',
      );
      final Map<String, dynamic> data = {
        "items": ["a", "b", "c"],
      };
      expect(template.render(data), equals('012'));
    });

    test('loop.first and loop.last', () {
      final template = Template(
        '{% for i in items %}{% if loop.first %}[{% endif %}{{ i }}{% if loop.last %}]{% endif %}{% endfor %}',
      );
      final Map<String, dynamic> data = {
        "items": [1, 2, 3],
      };
      expect(template.render(data), equals('[123]'));
    });

    test('loop.length', () {
      final template = Template(
        '{% for i in items %}{{ loop.length }}{% endfor %}',
      );
      final Map<String, dynamic> data = {
        "items": ["a", "b"],
      };
      expect(template.render(data), equals('22'));
    });

    test('for over dict items', () {
      final template = Template(
        '{% for k, v in data.items() %}{{ k }}={{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "data": {"x": 1, "y": 2},
      };
      expect(template.render(data), equals('x=1 y=2 '));
    });

    test('for else empty', () {
      final template = Template(
        '{% for i in items %}{{ i }}{% else %}empty{% endfor %}',
      );
      final Map<String, dynamic> data = {"items": []};
      expect(template.render(data), equals('empty'));
    });

    test('for undefined empty', () {
      final template = Template(
        '{% for i in items %}{{ i }}{% else %}empty{% endfor %}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('empty'));
    });

    test('nested for', () {
      final template = Template(
        '{% for i in a %}{% for j in b %}{{ i }}{{ j }}{% endfor %}{% endfor %}',
      );
      final Map<String, dynamic> data = {
        "a": [1, 2],
        "b": ["x", "y"],
      };
      expect(template.render(data), equals('1x1y2x2y'));
    });

    test('for with range', () {
      final template = Template('{% for i in range(3) %}{{ i }}{% endfor %}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('012'));
    });

    test('simple variable', () {
      final template = Template('{{ x }}');
      final Map<String, dynamic> data = {"x": 42};
      expect(template.render(data), equals('42'));
    });

    test('dot notation', () {
      final template = Template('{{ user.name }}');
      final Map<String, dynamic> data = {
        "user": {"name": "Bob"},
      };
      expect(template.render(data), equals('Bob'));
    });

    test('negative float (not dot notation)', () {
      final template = Template('{{ -1.0 }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('-1.0'));
    });

    test('bracket notation', () {
      final template = Template('{{ user[\'name\'] }}');
      final Map<String, dynamic> data = {
        "user": {"name": "Bob"},
      };
      expect(template.render(data), equals('Bob'));
    });

    test('array access', () {
      final template = Template('{{ items[1] }}');
      final Map<String, dynamic> data = {
        "items": ["a", "b", "c"],
      };
      expect(template.render(data), equals('b'));
    });

    test('array negative access', () {
      final template = Template('{{ items[-1] }}');
      final Map<String, dynamic> data = {
        "items": ["a", "b", "c"],
      };
      expect(template.render(data), equals('c'));
    });

    test('array slice', () {
      final template = Template('{{ items[1:-1]|string }}');
      final Map<String, dynamic> data = {
        "items": ["a", "b", "c"],
      };
      expect(template.render(data), equals('[\'b\']'));
    });

    test('array slice step', () {
      final template = Template('{{ items[::2]|string }}');
      final Map<String, dynamic> data = {
        "items": ["a", "b", "c"],
      };
      expect(template.render(data), equals('[\'a\', \'c\']'));
    });

    test('tuple slice', () {
      final template = Template('{{ (\'a\', \'b\', \'c\')[::-1]|string }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('(\'c\', \'b\', \'a\')'));
    });

    test('arithmetic', () {
      final template = Template('{{ (a + b) * c }}');
      final Map<String, dynamic> data = {"a": 2, "b": 3, "c": 4};
      expect(template.render(data), equals('20'));
    });

    test('string concat ~', () {
      final template = Template('{{ \'hello\' ~ \' \' ~ \'world\' }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('hello world'));
    });

    test('ternary', () {
      final template = Template('{{ \'yes\' if cond else \'no\' }}');
      final Map<String, dynamic> data = {"cond": true};
      expect(template.render(data), equals('yes'));
    });

    test('simple set', () {
      final template = Template('{% set x = 5 %}{{ x }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('5'));
    });

    test('set with expression', () {
      final template = Template('{% set x = a + b %}{{ x }}');
      final Map<String, dynamic> data = {"a": 10, "b": 20};
      expect(template.render(data), equals('30'));
    });

    test('set list', () {
      final template = Template(
        '{% set items = [1, 2, 3] %}{{ items|length }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('3'));
    });

    test('set dict', () {
      final template = Template('{% set d = {\'a\': 1} %}{{ d.a }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('1'));
    });

    test('set dict with mixed type keys', () {
      final template = Template(
        '{% set d = {0: 1, none: 2, 1.0: 3, \'0\': 4, (0, 0): 5, false: 6, 1: 7} %}{{ d[(0, 0)] + d[0] + d[none] + d[\'0\'] + d[false] + d[1.0] + d[1] }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('37'));
    });

    test('print dict with mixed type keys', () {
      final template = Template(
        '{% set d = {0: 1, none: 2, 1.0: 3, \'0\': 4, (0, 0): 5, true: 6} %}{{ d|string }}',
      );
      final Map<String, dynamic> data = {};
      expect(
        template.render(data),
        equals('{0: 1, None: 2, 1.0: 6, \'0\': 4, (0, 0): 5}'),
      );
    });

    test('print array with mixed types', () {
      final template = Template(
        '{% set d = [0, none, 1.0, \'0\', true, (0, 0)] %}{{ d|string }}',
      );
      final Map<String, dynamic> data = {};
      expect(
        template.render(data),
        equals('[0, None, 1.0, \'0\', True, (0, 0)]'),
      );
    });

    test('object member assignment with mixed key types', () {
      final template = Template(
        '{% set d = namespace() %}{% set d.a = 123 %}{{ d[\'a\'] == 123 }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('True'));
    });

    test('tuple unpacking', () {
      final template = Template(
        '{% set t = (1, 2, 3) %}{% set a, b, c = t %}{{ a + b + c }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('6'));
    });

    test('upper', () {
      final template = Template('{{ \'hello\'|upper }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('HELLO'));
    });

    test('lower', () {
      final template = Template('{{ \'HELLO\'|lower }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('hello'));
    });

    test('capitalize', () {
      final template = Template('{{ \'heLlo World\'|capitalize }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('Hello world'));
    });

    test('title', () {
      final template = Template('{{ \'hello world\'|title }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('Hello World'));
    });

    test('trim', () {
      final template = Template('{{ \'  \r\n\thello\t\n\r  \'|trim }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('hello'));
    });

    test('trim chars', () {
      final template = Template('{{ \'xyxhelloxyx\'|trim(\'xy\') }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('hello'));
    });

    test('length string', () {
      final template = Template('{{ \'hello\'|length }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('5'));
    });

    test('replace', () {
      final template = Template(
        '{{ \'hello world\'|replace(\'world\', \'jinja\') }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('hello jinja'));
    });

    test('length list', () {
      final template = Template('{{ items|length }}');
      final Map<String, dynamic> data = {
        "items": [1, 2, 3],
      };
      expect(template.render(data), equals('3'));
    });

    test('first', () {
      final template = Template('{{ items|first }}');
      final Map<String, dynamic> data = {
        "items": [10, 20, 30],
      };
      expect(template.render(data), equals('10'));
    });

    test('last', () {
      final template = Template('{{ items|last }}');
      final Map<String, dynamic> data = {
        "items": [10, 20, 30],
      };
      expect(template.render(data), equals('30'));
    });

    test('reverse', () {
      final template = Template(
        '{% for i in items|reverse %}{{ i }}{% endfor %}',
      );
      final Map<String, dynamic> data = {
        "items": [1, 2, 3],
      };
      expect(template.render(data), equals('321'));
    });

    test('sort', () {
      final template = Template('{% for i in items|sort %}{{ i }}{% endfor %}');
      final Map<String, dynamic> data = {
        "items": [3, 1, 2],
      };
      expect(template.render(data), equals('123'));
    });

    test('sort reverse', () {
      final template = Template(
        '{% for i in items|sort(true) %}{{ i }}{% endfor %}',
      );
      final Map<String, dynamic> data = {
        "items": [3, 1, 2],
      };
      expect(template.render(data), equals('321'));
    });

    test('sort with attribute', () {
      final template = Template(
        '{{ items|sort(attribute=\'name\')|join(attribute=\'age\') }}',
      );
      final Map<String, dynamic> data = {
        "items": [
          {"name": "c", "age": 3},
          {"name": "a", "age": 1},
          {"name": "b", "age": 2},
        ],
      };
      expect(template.render(data), equals('123'));
    });

    test('sort with numeric attribute', () {
      final template = Template(
        '{{ items|sort(attribute=0)|join(attribute=1) }}',
      );
      final Map<String, dynamic> data = {
        "items": [
          [3, "z"],
          [1, "x"],
          [2, "y"],
        ],
      };
      expect(template.render(data), equals('xyz'));
    });

    test('join', () {
      final template = Template('{{ items|join(\', \') }}');
      final Map<String, dynamic> data = {
        "items": ["a", "b", "c"],
      };
      expect(template.render(data), equals('a, b, c'));
    });

    test('join default separator', () {
      final template = Template('{{ items|join }}');
      final Map<String, dynamic> data = {
        "items": ["x", "y", "z"],
      };
      expect(template.render(data), equals('xyz'));
    });

    test('abs', () {
      final template = Template('{{ -5|abs }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('5'));
    });

    test('int from string', () {
      final template = Template('{{ \'42\'|int }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('42'));
    });

    test('int from string with default', () {
      final template = Template('{{ \'\'|int(1) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('1'));
    });

    test('int from string with base', () {
      final template = Template('{{ \'11\'|int(base=2) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('3'));
    });

    test('float from string', () {
      final template = Template('{{ \'3.14\'|float }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('3.14'));
    });

    test('default with value', () {
      final template = Template('{{ x|default(\'fallback\') }}');
      final Map<String, dynamic> data = {"x": "actual"};
      expect(template.render(data), equals('actual'));
    });

    test('default without value', () {
      final template = Template('{{ y|default(\'fallback\') }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('fallback'));
    });

    test('default with falsy value', () {
      final template = Template('{{ \'\'|default(\'fallback\', true) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('fallback'));
    });

    test('tojson ensure_ascii=true', () {
      final template = Template('{{ data|tojson(ensure_ascii=true) }}');
      final Map<String, dynamic> data = {"data": "\u2713"};
      expect(template.render(data), equals('"\\u2713"'));
    });

    test('tojson sort_keys=true', () {
      final template = Template('{{ data|tojson(sort_keys=true) }}');
      final Map<String, dynamic> data = {
        "data": {"b": 2, "a": 1},
      };
      expect(template.render(data), equals('{"a":1,"b":2}'));
    });

    test('tojson', () {
      final template = Template('{{ data|tojson }}');
      final Map<String, dynamic> data = {
        "data": {
          "a": 1,
          "b": [1, 2],
        },
      };
      expect(template.render(data), equals('{"a":1,"b":[1,2]}'));
    });

    test('tojson indent=4', () {
      final template = Template('{{ data|tojson(indent=4) }}');
      final Map<String, dynamic> data = {
        "data": {
          "a": 1,
          "b": [1, 2],
        },
      };
      expect(
        template.render(data),
        equals('{\n    "a": 1,\n    "b": [\n        1,\n        2\n    ]\n}'),
      );
    });

    test('tojson separators=(\',\',\':\')', () {
      final template = Template('{{ data|tojson(separators=(\',\',\':\')) }}');
      final Map<String, dynamic> data = {
        "data": {
          "a": 1,
          "b": [1, 2],
        },
      };
      expect(template.render(data), equals('{"a":1,"b":[1,2]}'));
    });

    test('tojson separators=(\',\',\': \') indent=2', () {
      final template = Template(
        '{{ data|tojson(separators=(\',\',\': \'), indent=2) }}',
      );
      final Map<String, dynamic> data = {
        "data": {
          "a": 1,
          "b": [1, 2],
        },
      };
      expect(
        template.render(data),
        equals('{\n  "a": 1,\n  "b": [\n    1,\n    2\n  ]\n}'),
      );
    });

    test('chained filters', () {
      final template = Template('{{ \'  HELLO  \'|trim|lower }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('hello'));
    });

    test('none to string', () {
      final template = Template('{{ x|string }}');
      final Map<String, dynamic> data = {"x": null};
      expect(template.render(data), equals('None'));
    });

    test('integer', () {
      final template = Template('{{ 42 }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('42'));
    });

    test('float', () {
      final template = Template('{{ 3.14 }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('3.14'));
    });

    test('string', () {
      final template = Template('{{ \'hello\' }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('hello'));
    });

    test('boolean true', () {
      final template = Template('{{ true }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('True'));
    });

    test('boolean false', () {
      final template = Template('{{ false }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('False'));
    });

    test('none', () {
      final template = Template('{% if x is none %}null{% endif %}');
      final Map<String, dynamic> data = {"x": null};
      expect(template.render(data), equals('null'));
    });

    test('list literal', () {
      final template = Template('{% for i in [1, 2, 3] %}{{ i }}{% endfor %}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('123'));
    });

    test('dict literal', () {
      final template = Template('{% set d = {\'a\': 1} %}{{ d.a }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('1'));
    });

    test('integer|abs', () {
      final template = Template('{{ -42 | abs }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('42'));
    });

    test('integer|float', () {
      final template = Template('{{ 42 | float }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('42.0'));
    });

    test('integer|tojson', () {
      final template = Template('{{ 42 | tojson }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('42'));
    });

    test('float|abs', () {
      final template = Template('{{ -3.14 | abs }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('3.14'));
    });

    test('float|int', () {
      final template = Template('{{ 3.14 | int }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('3'));
    });

    test('float|tojson', () {
      final template = Template('{{ 3.14 | tojson }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('3.14'));
    });

    test('string|tojson', () {
      final template = Template('{{ \'hello\' | tojson }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('"hello"'));
    });

    test('boolean|int', () {
      final template = Template('{{ true | int }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('1'));
    });

    test('boolean|float', () {
      final template = Template('{{ true | float }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('1.0'));
    });

    test('boolean|tojson', () {
      final template = Template('{{ true | tojson }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('true'));
    });

    test('inline comment', () {
      final template = Template('before{# comment #}after');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('beforeafter'));
    });

    test('comment ignores code', () {
      final template = Template(
        '{% set x = 1 %}{# {% set x = 999 %} #}{{ x }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('1'));
    });

    test('simple macro', () {
      final template = Template(
        '{% macro greet(name) %}Hello {{ name }}{% endmacro %}{{ greet(\'World\') }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('Hello World'));
    });

    test('macro default arg', () {
      final template = Template(
        '{% macro greet(name=\'Guest\') %}Hi {{ name }}{% endmacro %}{{ greet() }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('Hi Guest'));
    });

    test('namespace counter', () {
      final template = Template(
        '{% set ns = namespace(count=0) %}{% for i in range(3) %}{% set ns.count = ns.count + 1 %}{% endfor %}{{ ns.count }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('3'));
    });

    test('is odd', () {
      final template = Template('{% if 3 is odd %}yes{% endif %}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is even', () {
      final template = Template('{% if 4 is even %}yes{% endif %}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is false', () {
      final template = Template('{{ \'yes\' if x is false }}');
      final Map<String, dynamic> data = {"x": false};
      expect(template.render(data), equals('yes'));
    });

    test('is true', () {
      final template = Template('{{ \'yes\' if x is true }}');
      final Map<String, dynamic> data = {"x": true};
      expect(template.render(data), equals('yes'));
    });

    test('string is false', () {
      final template = Template('{{ \'yes\' if x is false else \'no\' }}');
      final Map<String, dynamic> data = {"x": ""};
      expect(template.render(data), equals('no'));
    });

    test('is divisibleby', () {
      final template = Template('{{ \'yes\' if x is divisibleby(2) }}');
      final Map<String, dynamic> data = {"x": 2};
      expect(template.render(data), equals('yes'));
    });

    test('is eq', () {
      final template = Template('{{ \'yes\' if 3 is eq(3) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is not equalto', () {
      final template = Template('{{ \'yes\' if 3 is not equalto(4) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is ge', () {
      final template = Template('{{ \'yes\' if 3 is ge(3) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is gt', () {
      final template = Template('{{ \'yes\' if 3 is gt(2) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is greaterthan', () {
      final template = Template('{{ \'yes\' if 3 is greaterthan(2) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is lt', () {
      final template = Template('{{ \'yes\' if 2 is lt(3) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is lessthan', () {
      final template = Template('{{ \'yes\' if 2 is lessthan(3) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is ne', () {
      final template = Template('{{ \'yes\' if 2 is ne(3) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is lower', () {
      final template = Template('{{ \'yes\' if \'lowercase\' is lower }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is upper', () {
      final template = Template('{{ \'yes\' if \'UPPERCASE\' is upper }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is sameas', () {
      final template = Template('{{ \'yes\' if x is sameas(false) }}');
      final Map<String, dynamic> data = {"x": false};
      expect(template.render(data), equals('yes'));
    });

    test('is boolean', () {
      final template = Template('{{ \'yes\' if x is boolean }}');
      final Map<String, dynamic> data = {"x": true};
      expect(template.render(data), equals('yes'));
    });

    test('is callable', () {
      final template = Template('{{ \'yes\' if \'\'.strip is callable }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is escaped', () {
      final template = Template('{{ \'yes\' if \'foo\'|safe is escaped }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is filter', () {
      final template = Template('{{ \'yes\' if \'trim\' is filter }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is float', () {
      final template = Template('{{ \'yes\' if x is float }}');
      final Map<String, dynamic> data = {"x": 1.1};
      expect(template.render(data), equals('yes'));
    });

    test('is integer', () {
      final template = Template('{{ \'yes\' if x is integer }}');
      final Map<String, dynamic> data = {"x": 1};
      expect(template.render(data), equals('yes'));
    });

    test('is sequence', () {
      final template = Template('{{ \'yes\' if x is sequence }}');
      final Map<String, dynamic> data = {
        "x": [1, 2, 3],
      };
      expect(template.render(data), equals('yes'));
    });

    test('is test', () {
      final template = Template('{{ \'yes\' if \'sequence\' is test }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is undefined', () {
      final template = Template('{{ \'yes\' if x is undefined }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is none', () {
      final template = Template('{% if x is none %}yes{% endif %}');
      final Map<String, dynamic> data = {"x": null};
      expect(template.render(data), equals('yes'));
    });

    test('is string', () {
      final template = Template('{% if x is string %}yes{% endif %}');
      final Map<String, dynamic> data = {"x": "hello"};
      expect(template.render(data), equals('yes'));
    });

    test('is number', () {
      final template = Template('{% if x is number %}yes{% endif %}');
      final Map<String, dynamic> data = {"x": 42};
      expect(template.render(data), equals('yes'));
    });

    test('is iterable', () {
      final template = Template('{% if x is iterable %}yes{% endif %}');
      final Map<String, dynamic> data = {
        "x": [1, 2, 3],
      };
      expect(template.render(data), equals('yes'));
    });

    test('is mapping', () {
      final template = Template('{% if x is mapping %}yes{% endif %}');
      final Map<String, dynamic> data = {
        "x": {"a": 1},
      };
      expect(template.render(data), equals('yes'));
    });

    test('undefined is sequence', () {
      final template = Template('{{ \'yes\' if x is sequence }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('undefined is iterable', () {
      final template = Template('{{ \'yes\' if x is iterable }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is in (array, true)', () {
      final template = Template('{{ \'yes\' if 2 is in([1, 2, 3]) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is in (array, false)', () {
      final template = Template(
        '{{ \'yes\' if 5 is in([1, 2, 3]) else \'no\' }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('no'));
    });

    test('is in (string)', () {
      final template = Template('{{ \'yes\' if \'bc\' is in(\'abcde\') }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('yes'));
    });

    test('is in (object keys)', () {
      final template = Template('{{ \'yes\' if \'a\' is in(obj) }}');
      final Map<String, dynamic> data = {
        "obj": {"a": 1, "b": 2},
      };
      expect(template.render(data), equals('yes'));
    });

    test('reject with in test', () {
      final template = Template(
        '{{ items | reject(\'in\', skip) | join(\', \') }}',
      );
      final Map<String, dynamic> data = {
        "items": ["a", "b", "c", "d"],
        "skip": ["b", "d"],
      };
      expect(template.render(data), equals('a, c'));
    });

    test('select with in test', () {
      final template = Template(
        '{{ items | select(\'in\', keep) | join(\', \') }}',
      );
      final Map<String, dynamic> data = {
        "items": ["a", "b", "c", "d"],
        "keep": ["b", "c"],
      };
      expect(template.render(data), equals('b, c'));
    });

    test('string.upper()', () {
      final template = Template('{{ s.upper() }}');
      final Map<String, dynamic> data = {"s": "hello"};
      expect(template.render(data), equals('HELLO'));
    });

    test('string.lower()', () {
      final template = Template('{{ s.lower() }}');
      final Map<String, dynamic> data = {"s": "HELLO"};
      expect(template.render(data), equals('hello'));
    });

    test('string.strip()', () {
      final template = Template('[{{ s.strip() }}]');
      final Map<String, dynamic> data = {"s": "  hello  "};
      expect(template.render(data), equals('[hello]'));
    });

    test('string.lstrip()', () {
      final template = Template('[{{ s.lstrip() }}]');
      final Map<String, dynamic> data = {"s": "   hello"};
      expect(template.render(data), equals('[hello]'));
    });

    test('string.rstrip()', () {
      final template = Template('[{{ s.rstrip() }}]');
      final Map<String, dynamic> data = {"s": "hello   "};
      expect(template.render(data), equals('[hello]'));
    });

    test('string.title()', () {
      final template = Template('{{ s.title() }}');
      final Map<String, dynamic> data = {"s": "hello world"};
      expect(template.render(data), equals('Hello World'));
    });

    test('string.capitalize()', () {
      final template = Template('{{ s.capitalize() }}');
      final Map<String, dynamic> data = {"s": "heLlo World"};
      expect(template.render(data), equals('Hello world'));
    });

    test('string.startswith() true', () {
      final template = Template('{% if s.startswith(\'hel\') %}yes{% endif %}');
      final Map<String, dynamic> data = {"s": "hello"};
      expect(template.render(data), equals('yes'));
    });

    test('string.startswith() false', () {
      final template = Template(
        '{% if s.startswith(\'xyz\') %}yes{% else %}no{% endif %}',
      );
      final Map<String, dynamic> data = {"s": "hello"};
      expect(template.render(data), equals('no'));
    });

    test('string.endswith() true', () {
      final template = Template('{% if s.endswith(\'lo\') %}yes{% endif %}');
      final Map<String, dynamic> data = {"s": "hello"};
      expect(template.render(data), equals('yes'));
    });

    test('string.endswith() false', () {
      final template = Template(
        '{% if s.endswith(\'xyz\') %}yes{% else %}no{% endif %}',
      );
      final Map<String, dynamic> data = {"s": "hello"};
      expect(template.render(data), equals('no'));
    });

    test('string.split() with sep', () {
      final template = Template('{{ s.split(\',\')|join(\'-\') }}');
      final Map<String, dynamic> data = {"s": "a,b,c"};
      expect(template.render(data), equals('a-b-c'));
    });

    test('string.split() with maxsplit', () {
      final template = Template('{{ s.split(\',\', 1)|join(\'-\') }}');
      final Map<String, dynamic> data = {"s": "a,b,c"};
      expect(template.render(data), equals('a-b,c'));
    });

    test('string.rsplit() with sep', () {
      final template = Template('{{ s.rsplit(\',\')|join(\'-\') }}');
      final Map<String, dynamic> data = {"s": "a,b,c"};
      expect(template.render(data), equals('a-b-c'));
    });

    test('string.rsplit() with maxsplit', () {
      final template = Template('{{ s.rsplit(\',\', 1)|join(\'-\') }}');
      final Map<String, dynamic> data = {"s": "a,b,c"};
      expect(template.render(data), equals('a,b-c'));
    });

    test('string.replace() basic', () {
      final template = Template('{{ s.replace(\'world\', \'jinja\') }}');
      final Map<String, dynamic> data = {"s": "hello world"};
      expect(template.render(data), equals('hello jinja'));
    });

    test('string.replace() with count', () {
      final template = Template('{{ s.replace(\'a\', \'X\', 2) }}');
      final Map<String, dynamic> data = {"s": "banana"};
      expect(template.render(data), equals('bXnXna'));
    });

    test('undefined|capitalize', () {
      final template = Template('{{ arr|capitalize }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|title', () {
      final template = Template('{{ arr|title }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|truncate', () {
      final template = Template('{{ arr|truncate(9) }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|upper', () {
      final template = Template('{{ arr|upper }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|lower', () {
      final template = Template('{{ arr|lower }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|replace', () {
      final template = Template('{{ arr|replace(\'a\', \'b\') }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|trim', () {
      final template = Template('{{ arr|trim }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|wordcount', () {
      final template = Template('{{ arr|wordcount }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('0'));
    });

    test('array|selectattr by attribute', () {
      final template = Template(
        '{% for item in items|selectattr(\'active\') %}{{ item.name }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "items": [
          {"name": "a", "active": true},
          {"name": "b", "active": false},
          {"name": "c", "active": true},
        ],
      };
      expect(template.render(data), equals('a c '));
    });

    test('array|selectattr with operator', () {
      final template = Template(
        '{% for item in items|selectattr(\'value\', \'equalto\', 5) %}{{ item.name }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "items": [
          {"name": "a", "value": 3},
          {"name": "b", "value": 5},
          {"name": "c", "value": 5},
        ],
      };
      expect(template.render(data), equals('b c '));
    });

    test('array|tojson', () {
      final template = Template('{{ arr|tojson }}');
      final Map<String, dynamic> data = {
        "arr": [1, 2, 3],
      };
      expect(template.render(data), equals('[1,2,3]'));
    });

    test('array|tojson with strings', () {
      final template = Template('{{ arr|tojson }}');
      final Map<String, dynamic> data = {
        "arr": ["a", "b", "c"],
      };
      expect(template.render(data), equals('["a","b","c"]'));
    });

    test('array|tojson nested', () {
      final template = Template('{{ arr|tojson }}');
      final Map<String, dynamic> data = {
        "arr": [
          [1, 2],
          [3, 4],
        ],
      };
      expect(template.render(data), equals('[[1,2],[3,4]]'));
    });

    test('array|last', () {
      final template = Template('{{ arr|last }}');
      final Map<String, dynamic> data = {
        "arr": [10, 20, 30],
      };
      expect(template.render(data), equals('30'));
    });

    test('array|last single element', () {
      final template = Template('{{ arr|last }}');
      final Map<String, dynamic> data = {
        "arr": [42],
      };
      expect(template.render(data), equals('42'));
    });

    test('array|join with separator', () {
      final template = Template('{{ arr|join(\', \') }}');
      final Map<String, dynamic> data = {
        "arr": ["a", "b", "c"],
      };
      expect(template.render(data), equals('a, b, c'));
    });

    test('array|join with custom separator', () {
      final template = Template('{{ arr|join(\' | \') }}');
      final Map<String, dynamic> data = {
        "arr": [1, 2, 3],
      };
      expect(template.render(data), equals('1 | 2 | 3'));
    });

    test('array|join default separator', () {
      final template = Template('{{ arr|join }}');
      final Map<String, dynamic> data = {
        "arr": ["x", "y", "z"],
      };
      expect(template.render(data), equals('xyz'));
    });

    test('array|join attribute', () {
      final template = Template('{{ arr|join(attribute=\'age\') }}');
      final Map<String, dynamic> data = {
        "arr": [
          {"name": "a", "age": 1},
          {"name": "b", "age": 2},
          {"name": "c", "age": 3},
        ],
      };
      expect(template.render(data), equals('123'));
    });

    test('array|join numeric attribute', () {
      final template = Template('{{ arr|join(attribute=-1) }}');
      final Map<String, dynamic> data = {
        "arr": [
          [1],
          [2],
          [3],
        ],
      };
      expect(template.render(data), equals('123'));
    });

    test('array.pop() last', () {
      final template = Template('{{ arr.pop() }}-{{ arr|join(\',\') }}');
      final Map<String, dynamic> data = {
        "arr": ["a", "b", "c"],
      };
      expect(template.render(data), equals('c-a,b'));
    });

    test('array.pop() with index', () {
      final template = Template('{{ arr.pop(0) }}-{{ arr|join(\',\') }}');
      final Map<String, dynamic> data = {
        "arr": ["a", "b", "c"],
      };
      expect(template.render(data), equals('a-b,c'));
    });

    test('array.append()', () {
      final template = Template(
        '{% set _ = arr.append(\'d\') %}{{ arr|join(\',\') }}',
      );
      final Map<String, dynamic> data = {
        "arr": ["a", "b", "c"],
      };
      expect(template.render(data), equals('a,b,c,d'));
    });

    test('array|map with attribute', () {
      final template = Template(
        '{% for v in arr|map(attribute=\'age\') %}{{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "arr": [
          {"name": "a", "age": 1},
          {"name": "b", "age": 2},
          {"name": "c", "age": 3},
        ],
      };
      expect(template.render(data), equals('1 2 3 '));
    });

    test('array|map with attribute default', () {
      final template = Template(
        '{% for v in arr|map(attribute=\'age\', default=3) %}{{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "arr": [
          {"name": "a", "age": 1},
          {"name": "b", "age": 2},
          {"name": "c"},
        ],
      };
      expect(template.render(data), equals('1 2 3 '));
    });

    test('array|map without attribute default', () {
      final template = Template(
        '{% for v in arr|map(attribute=\'age\') %}{{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "arr": [
          {"name": "a", "age": 1},
          {"name": "b", "age": 2},
          {"name": "c"},
        ],
      };
      expect(template.render(data), equals('1 2  '));
    });

    test('array|map with numeric attribute', () {
      final template = Template(
        '{% for v in arr|map(attribute=0) %}{{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "arr": [
          [10, "x"],
          [20, "y"],
          [30, "z"],
        ],
      };
      expect(template.render(data), equals('10 20 30 '));
    });

    test('array|map with negative attribute', () {
      final template = Template(
        '{% for v in arr|map(attribute=-1) %}{{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "arr": [
          [10, "x"],
          [20, "y"],
          [30, "z"],
        ],
      };
      expect(template.render(data), equals('x y z '));
    });

    test('array|map with filter', () {
      final template = Template('{{ arr|map(\'int\')|sum }}');
      final Map<String, dynamic> data = {
        "arr": ["1", "2", "3"],
      };
      expect(template.render(data), equals('6'));
    });

    test('undefined|select', () {
      final template = Template(
        '{% for item in items|select(\'odd\') %}{{ item.name }} {% endfor %}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|selectattr', () {
      final template = Template(
        '{% for item in items|selectattr(\'active\') %}{{ item.name }} {% endfor %}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|reject', () {
      final template = Template(
        '{% for item in items|reject(\'even\') %}{{ item.name }} {% endfor %}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|rejectattr', () {
      final template = Template(
        '{% for item in items|rejectattr(\'active\') %}{{ item.name }} {% endfor %}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|list', () {
      final template = Template('{{ arr|list|string }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('[]'));
    });

    test('undefined|string', () {
      final template = Template('{{ arr|string }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|first', () {
      final template = Template('{{ arr|first }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|last', () {
      final template = Template('{{ arr|last }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|length', () {
      final template = Template('{{ arr|length }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('0'));
    });

    test('undefined|join', () {
      final template = Template('{{ arr|join }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|sort', () {
      final template = Template('{{ arr|sort|string }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('[]'));
    });

    test('undefined|reverse', () {
      final template = Template('{{ arr|reverse|join }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|map', () {
      final template = Template(
        '{% for v in arr|map(attribute=\'age\') %}{{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|min', () {
      final template = Template('{{ arr|min }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|max', () {
      final template = Template('{{ arr|max }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|unique', () {
      final template = Template('{{ arr|unique|join }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });

    test('undefined|sum', () {
      final template = Template('{{ arr|sum }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('0'));
    });

    test('object.get() existing key', () {
      final template = Template('{{ obj.get(\'a\') }}');
      final Map<String, dynamic> data = {
        "obj": {"a": 1, "b": 2},
      };
      expect(template.render(data), equals('1'));
    });

    test('object.get() missing key', () {
      final template = Template('[{{ obj.get(\'c\') is none }}]');
      final Map<String, dynamic> data = {
        "obj": {"a": 1},
      };
      expect(template.render(data), equals('[True]'));
    });

    test('object.get() missing key with default', () {
      final template = Template('{{ obj.get(\'c\', \'default\') }}');
      final Map<String, dynamic> data = {
        "obj": {"a": 1},
      };
      expect(template.render(data), equals('default'));
    });

    test('object.items()', () {
      final template = Template(
        '{% for k, v in obj.items() %}{{ k }}={{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "obj": {"x": 1, "y": 2},
      };
      expect(template.render(data), equals('x=1 y=2 '));
    });

    test('object.keys()', () {
      final template = Template(
        '{% for k in obj.keys() %}{{ k }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "obj": {"a": 1, "b": 2},
      };
      expect(template.render(data), equals('a b '));
    });

    test('object.values()', () {
      final template = Template(
        '{% for v in obj.values() %}{{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "obj": {"a": 1, "b": 2},
      };
      expect(template.render(data), equals('1 2 '));
    });

    test('dictsort ascending by key', () {
      final template = Template(
        '{% for k, v in obj|dictsort %}{{ k }}={{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "obj": {"z": 2, "a": 3, "m": 1},
      };
      expect(template.render(data), equals('a=3 m=1 z=2 '));
    });

    test('dictsort descending by key', () {
      final template = Template(
        '{% for k, v in obj|dictsort(reverse=true) %}{{ k }}={{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "obj": {"a": 1, "b": 2, "c": 3},
      };
      expect(template.render(data), equals('c=3 b=2 a=1 '));
    });

    test('dictsort by value', () {
      final template = Template(
        '{% for k, v in obj|dictsort(by=\'value\') %}{{ k }}={{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "obj": {"a": 3, "b": 1, "c": 2},
      };
      expect(template.render(data), equals('b=1 c=2 a=3 '));
    });

    test('dictsort case sensitive', () {
      final template = Template(
        '{% for k, v in obj|dictsort(case_sensitive=true) %}{{ k }}={{ v }} {% endfor %}',
      );
      final Map<String, dynamic> data = {
        "obj": {"a": 1, "A": 1, "b": 2, "B": 2, "c": 3},
      };
      expect(template.render(data), equals('A=1 B=2 a=1 b=2 c=3 '));
    });

    test('object|tojson', () {
      final template = Template('{{ obj|tojson }}');
      final Map<String, dynamic> data = {
        "obj": {"name": "test", "value": 42},
      };
      expect(template.render(data), equals('{"name":"test","value":42}'));
    });

    test('nested object|tojson', () {
      final template = Template('{{ obj|tojson }}');
      final Map<String, dynamic> data = {
        "obj": {
          "outer": {"inner": "value"},
        },
      };
      expect(template.render(data), equals('{"outer":{"inner":"value"}}'));
    });

    test('array in object|tojson', () {
      final template = Template('{{ obj|tojson }}');
      final Map<String, dynamic> data = {
        "obj": {
          "items": [1, 2, 3],
        },
      };
      expect(template.render(data), equals('{"items":[1,2,3]}'));
    });

    test('object attribute and key access', () {
      final template = Template(
        '{{ obj.keys()|join(\',\') }} vs {{ obj[\'keys\'] }} vs {{ obj.test }}',
      );
      final Map<String, dynamic> data = {
        "obj": {"keys": "value", "test": "attr_value"},
      };
      expect(template.render(data), equals('keys,test vs value vs attr_value'));
    });

    test('env should not have object methods', () {
      final template = Template(
        '{{ keys is undefined }} {{ obj.keys is defined }}',
      );
      final Map<String, dynamic> data = {
        "obj": {"a": "b"},
      };
      expect(template.render(data), equals('True True'));
    });

    test('expression as object key', () {
      final template = Template(
        '{% set d = {\'ab\': 123} %}{{ d[\'a\' + \'b\'] == 123 }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('True'));
    });

    test('numeric as object key (template: Seed-OSS)', () {
      final template = Template(
        '{% set d = {1: \'a\', 2: \'b\'} %}{{ d[1] == \'a\' and d[2] == \'b\' }}',
      );
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals('True'));
    });

    test('undefined|items', () {
      final template = Template('{{ arr|items|join }}');
      final Map<String, dynamic> data = {};
      expect(template.render(data), equals(''));
    });
  });
}
