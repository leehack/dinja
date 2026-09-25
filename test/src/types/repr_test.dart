import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('list and dict string conversion matches llama.cpp', () {
    // Expected values are llama.cpp common/jinja output at 7fe450e1.
    final cases = <(String, String, Map<String, dynamic>, String)>[
      (
        'string with a single quote uses JSON form',
        '{{ \'\' ~ ["it\'s"] }}',
        {},
        '["it\'s"]',
      ),
      (
        'string with both quotes',
        '{{ \'\' ~ [\'it\\\'s "x"\'] }}',
        {},
        '["it\'s \\"x\\""]',
      ),
      (
        'newline is escaped only in JSON form',
        "{{ '' ~ x }}",
        {
          'x': ['a\nb', "it's\nx", 't\tb'],
        },
        '[\'a\nb\', "it\'s\\nx", \'t\tb\']',
      ),
      (
        'backslash is escaped only in JSON form',
        "{{ '' ~ x }}",
        {
          'x': ['a\\b', "it's\\"],
        },
        '[\'a\\b\', "it\'s\\\\"]',
      ),
      (
        'non-ASCII stays',
        "{{ '' ~ x }}",
        {
          'x': ['é', "it's é"],
        },
        '[\'é\', "it\'s é"]',
      ),
      (
        'dict key with a single quote',
        '{{ \'\' ~ {"it\'s": \'v\'} }}',
        {},
        '{"it\'s": \'v\'}',
      ),
      (
        'control character',
        "{{ '' ~ x }}",
        {
          'x': ["it's\u{1}", '\u{1}'],
        },
        '["it\'s\\u0001", \'\u{1}\']',
      ),
    ];
    for (final (name, source, data, expected) in cases) {
      test(name, () => expect(Template(source).render(data), expected));
    }
  });

  group('printing a list or dict', () {
    // Expected values are llama.cpp's string form of the same value
    // (`value ~ ''`). llama.cpp itself prints a bare list as its items
    // run together and a bare dict as nothing.
    final cases = <(String, String, Map<String, dynamic>, String)>[
      ('list', "{{ [1, '1'] }}", {}, "[1, '1']"),
      ('dict', "{{ {'a': 'b'} }}", {}, "{'a': 'b'}"),
      (
        'list in an if block',
        "{% if true %}{{ [1, 'a'] }}{% endif %}",
        {},
        "[1, 'a']",
      ),
      ('list from set', "{% set y = ['a', 'b'] %}{{ y }}", {}, "['a', 'b']"),
      (
        'list and dict from context',
        '{{ x }}|{{ y }}',
        {
          'x': [1, 'a'],
          'y': {'k': 'v'},
        },
        "[1, 'a']|{'k': 'v'}",
      ),
    ];
    for (final (name, source, data, expected) in cases) {
      test(name, () => expect(Template(source).render(data), expected));
    }

    test('escapes input-marked items but not quotes', () {
      final data = {
        'x': [1, JinjaString.user('a<b'), JinjaString.user("it's <")],
        'y': {'k': JinjaString.user('<v>')},
      };
      expect(
        Template('{{ x }}|{{ y }}').render(data),
        '[1, \'a&lt;b\', "it&#39;s &lt;"]|{\'k\': \'&lt;v&gt;\'}',
      );
    });

    test('does not escape an already escaped item again', () {
      final source = '{% set s %}{{ x }}{% endset %}{{ [s] }}';
      expect(Template(source).render({'x': JinjaString.user('<')}), "['&lt;']");
    });
  });
}
