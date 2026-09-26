import 'package:dinja/dinja.dart';
import 'package:test/test.dart';

void main() {
  group('Input-marked text keeps its marking', () {
    // llama.cpp 7fe450e19 drops the marking in these, or lacks the filter;
    // it gives each output with the input unescaped. dinja escapes it.
    final values = {'x': JinjaString.user('<b>')};
    const cases = {
      '{{ x[0] }}|{{ x[::2] }}': '&lt;|&lt;&gt;',
      '{{ x | first }}|{{ x | last }}|{{ x | reverse }}': '&lt;|&gt;|&gt;b&lt;',
      '{{ x | list | join }}|{% for c in x %}{{ c }}{% endfor %}|{{ x | unique | join }}':
          '&lt;b&gt;|&lt;b&gt;|&lt;b&gt;',
      "{{ x.split('b') | first }}|{{ x.rsplit('b') | last }}|{{ x.split() | join }}":
          '&lt;|&gt;|&lt;b&gt;',
      "{{ x.strip('<') }}|{{ x.lstrip('<') }}|{{ x.rstrip('>') }}":
          'b&gt;|b&gt;|&lt;b',
      '{{ x | truncate(2, true, "") }}|{{ "abcdef" | truncate(5, true, x) }}':
          '&lt;b|ab&lt;b&gt;',
      '{{ str(x) }}|{{ [x] | string }}|{{ "a" ~ [x] }}|{{ "{}" | format([x]) }}':
          "&lt;b&gt;|['&lt;b&gt;']|a['&lt;b&gt;']|['&lt;b&gt;']",
      '{{ ("a" ~ x) | indent(2, true) }}|{{ ("a" ~ x) | replace("a", "z") }}|{{ "a" | replace("a", x) }}':
          '  a&lt;b&gt;|z&lt;b&gt;|&lt;b&gt;',
      '{{ ("a" ~ x).format() }}|{{ [x] | upper }}|{{ [x] | trim }}':
          "a&lt;b&gt;|['&lt;B&gt;']|['&lt;b&gt;']",
      '{{ (x ~ "a") | capitalize }}': '&lt;b&gt;a',
    };
    cases.forEach((source, expected) {
      test('renders $source', () {
        expect(Template(source).render(values), expected);
      });
    });

    test('in a case change that can change the length', () {
      // On the web 'ß' upper-cases to 'SS'; on the VM it stays 'ß'.
      final out = Template(
        '{{ (x ~ "a") | capitalize }}|{{ (x ~ " a") | title }}',
      ).render({'x': JinjaString.user('ß<')});
      expect(out, matches(RegExp(r'^(SS|ß)&lt;a\|(SS|ß)&lt; A$')));
    });

    test('in a dict key', () {
      expect(
        Template(
          '{% for k in d %}{{ k }}{% endfor %}|{{ d | list | join }}',
        ).render({
          'd': {JinjaString.user('<k>'): 1},
        }),
        '&lt;k&gt;|&lt;k&gt;',
      );
    });

    test('in a strftime_now format', () {
      expect(
        Template(
          '{{ strftime_now(x) }}',
        ).render({'x': JinjaString.user('<%Y')}),
        startsWith('&lt;'),
      );
    });
  });

  group('Template text is not escaped', () {
    // llama.cpp 7fe450e19 marks all of a replace or indent result as input
    // when all of its source is.
    final values = {'x': JinjaString.user('<b>')};
    const cases = {
      '{{ x | replace("b", "<i>") }}': '&lt;<i>&gt;',
      '{{ x.replace("b", "<i>", 1) }}': '&lt;<i>&gt;',
      '{{ x | indent("> ", true) }}': '> &lt;b&gt;',
    };
    cases.forEach((source, expected) {
      test('renders $source', () {
        expect(Template(source).render(values), expected);
      });
    });
  });

  group('Safe text is not escaped again', () {
    final values = {'x': JinjaString.user('<b>'), 'y': JinjaString.user('<i>')};
    const cases = {
      '{{ (x ~ (y | safe)).format() }}': '&lt;b&gt;<i>',
      '{{ "{}" | format(x ~ (y | safe)) }}': '&lt;b&gt;<i>',
      '{{ (x ~ (y | safe)) | list | join }}': '&lt;b&gt;<i>',
      '{{ "a" | indent(x ~ (y | safe), true) }}': '&lt;b&gt;<i>a',
      '{{ (x | safe)[::2] }}': '<>',
    };
    cases.forEach((source, expected) {
      test('renders $source', () {
        expect(Template(source).render(values), expected);
      });
    });
  });

  group('Escaping invariants', () {
    // Every expression in every wrapper: input-marked text is escaped
    // exactly once, and template text is never escaped.
    const expressions = [
      'x',
      'x | upper',
      'x | title',
      'x | capitalize',
      'x | trim',
      'x.strip("<")',
      'x | replace("b", "[T]")',
      'x.replace("<", "[")',
      'x | indent(2, true)',
      'x[0]',
      'x[1:]',
      'x[::-1]',
      'x | first',
      'x | reverse',
      'x | list | join',
      'x | join(",")',
      '[x, "[T]"] | join(x)',
      'l | map("upper") | join',
      'x | tojson',
      '{x: [x]} | tojson(indent=1)',
      'd | tojson',
      'd | items | list',
      'd | list | join',
      'x.split("b") | join("|")',
      'x.rsplit("b", 1) | first',
      '"abcdef" | truncate(5, true, x)',
      'x | string',
      'str([x])',
      'x ~ "[T]"',
      '"[T]" ~ [x]',
      'x * 2',
      '"{}[T]".format(x)',
      '"{}" | format(d)',
      '("a" ~ x) | replace("a", x)',
      'x | default("d")',
      'nope | default(x)',
      'x if true else ""',
      '{"k": x}["k"]',
      'namespace(a=x).a',
      'l | sort | join',
      'l | unique | join',
      'l | max',
      'x | length',
    ];
    const wrappers = [
      '{{ E }}',
      '{% if true %}{{ E }}{% endif %}',
      '{% for i in [1] %}{{ E }}{% endfor %}',
      '{% for c in [E] %}{{ c }}{% endfor %}',
      '{% set s = E %}{{ s }}',
      '{% set s %}{{ E }}{% endset %}{{ s }}',
      '{% set s %}{{ E }}[T]{% endset %}{{ s | upper }}{{ s | length }}',
      '{% macro m() %}{{ E }}{% endmacro %}{{ m() }}',
      '{% macro m(a) %}[{{ a }}]{% endmacro %}{{ m(E) }}',
      '{% macro m() %}{{ caller() | trim }}{% endmacro %}'
          '{% call m() %}{{ E }}{% endcall %}',
      '{% filter upper %}{{ E }}{% endfilter %}',
      '{% filter replace("b", "[") %}{{ E }}{% endfilter %}',
      '{% filter tojson %}{{ E }}{% endfilter %}',
      '{{ (E) | string }}',
      '{{ [E] | join }}',
      '{{ "p" ~ (E) ~ "q" }}',
      '{% for i in [1, 2] %}{{ E }}{% if loop.first %}{% continue %}'
          '{% endif %}{% endfor %}',
    ];
    final entity = RegExp(r'&(lt|gt|amp|quot|#39);');

    test('escape input-marked text once', () {
      // Template text here has none of < > &, so each one in the output
      // must come from escaping.
      final values = <String, dynamic>{
        'x': JinjaString.user('<b>&'),
        'l': [JinjaString.user('<p>'), JinjaString.user('q&')],
        'd': {
          JinjaString.user('<k>'): [
            JinjaString.user('<v>'),
            {'n': JinjaString.user('&')},
          ],
        },
      };
      for (final w in wrappers) {
        for (final e in expressions) {
          final source = w.replaceAll('E', e);
          final out = Template(source).render(values);
          final stripped = out.replaceAll(entity, '');
          expect(stripped, isNot(matches(r'[<>&]')), reason: source);
          expect(out, isNot(contains('&amp;lt;')), reason: source);
          expect(out, isNot(contains('&amp;amp;')), reason: source);
        }
      }
    });

    test('never escape template text', () {
      // Input here has none of < > & ' ", so the output has no entity.
      final values = <String, dynamic>{
        'x': JinjaString.user('abc'),
        'l': [JinjaString.user('p'), JinjaString.user('q')],
        'd': {
          JinjaString.user('k'): [
            JinjaString.user('v'),
            {'n': JinjaString.user('w')},
          ],
        },
      };
      for (final w in wrappers) {
        for (final e in expressions) {
          final source = w
              .replaceAll('E', e)
              .replaceAll('[T]', "<T&'>")
              .replaceAll('"b"', '"a"');
          final out = Template(source).render(values);
          expect(out, isNot(contains(entity)), reason: source);
        }
      }
    });
  });
}
