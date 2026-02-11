import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Expression and Statement Execution', () {
    test('Basic rendering', () {
      expect(Template('Hello').render(), equals('Hello'));
      expect(Template('{{ 1 + 1 }}').render(), equals('2'));
      expect(Template('{{ "a" ~ "b" }}').render(), equals('ab'));
    });

    test('Arithmetic operators', () {
      expect(Template('{{ 5 + 2 }}').render(), equals('7'));
      expect(Template('{{ 5 - 2 }}').render(), equals('3'));
      expect(Template('{{ 5 * 2 }}').render(), equals('10'));
      expect(Template('{{ 5 / 2 }}').render(), equals('2.5'));
      expect(Template('{{ 5 // 2 }}').render(), equals('2'));
      expect(Template('{{ 5 % 2 }}').render(), equals('1'));
      expect(Template('{{ 5 ** 2 }}').render(), equals('25'));
    });

    test('Comparison operators', () {
      expect(Template('{{ 1 < 2 }}').render(), equals('True'));
      expect(Template('{{ 1 > 2 }}').render(), equals('False'));
      expect(Template('{{ 1 <= 1 }}').render(), equals('True'));
      expect(Template('{{ 1 >= 2 }}').render(), equals('False'));
      expect(Template('{{ 1 == 1 }}').render(), equals('True'));
      expect(Template('{{ 1 != 1 }}').render(), equals('False'));
    });

    test('Logic operators', () {
      expect(Template('{{ true and false }}').render(), equals('False'));
      expect(Template('{{ true or false }}').render(), equals('True'));
      expect(Template('{{ not true }}').render(), equals('False'));
    });

    test('In and Not In operators', () {
      expect(Template('{{ 1 in [1, 2] }}').render(), equals('True'));
      expect(Template('{{ 3 in [1, 2] }}').render(), equals('False'));
      expect(Template('{{ "a" in "abc" }}').render(), equals('True'));
      expect(Template('{{ "d" not in "abc" }}').render(), equals('True'));
    });

    test('String concatenation with ~', () {
      expect(
        Template('{{ "a" ~ 1 ~ "b" ~ true }}').render({}),
        equals('a1bTrue'),
      );
    });

    test('Control flow: If', () {
      final tpl = Template('{% if x %}yes{% else %}no{% endif %}');
      expect(tpl.render({'x': true}), equals('yes'));
      expect(tpl.render({'x': false}), equals('no'));
    });

    test('Control flow: For', () {
      final tpl = Template('{% for i in [1, 2] %}{{ i }}{% endfor %}');
      expect(tpl.render(), equals('12'));
    });

    test('For loop with if condition', () {
      final tpl = Template(
        '{% for i in [1, 2, 3, 4] if i > 2 %}{{ i }}{% endfor %}',
      );
      expect(tpl.render(), equals('34'));
    });

    test('Set statement', () {
      expect(Template('{% set x = 1 %}{{ x }}').render(), equals('1'));
    });
  });

  group('Slicing', () {
    test('String slicing', () {
      expect(Template('{{ "hello"[0:2] }}').render(), equals('he'));
      expect(Template('{{ "hello"[0:5:2] }}').render(), equals('hlo'));
      expect(Template('{{ "hello"[-3:] }}').render(), equals('llo'));
      expect(Template('{{ "hello"[::-1] }}').render(), equals('olleh'));
    });

    test('List slicing', () {
      expect(Template('{{ [1, 2, 3, 4, 5][1:3] }}').render(), equals('[2, 3]'));
      expect(
        Template('{{ [1, 2, 3, 4, 5][::-1] }}').render(),
        equals('[5, 4, 3, 2, 1]'),
      );
    });
  });

  group('Call and Macro', () {
    test('Simple Macro', () {
      final source = '''
{% macro test(x) %}
  val: {{ x }}
{% endmacro %}
{{ test(10) | trim }}
''';
      expect(Template(source).render().trim(), equals('val: 10'));
    });

    test('Call block', () {
      final source = '''
{% macro target() %}
  start
  {{ caller() | trim }}
  end
{% endmacro %}
{% call target() %}
  middle
{% endcall %}
''';
      final result = Template(
        source,
      ).render().replaceAll(RegExp(r'\s+'), ' ').trim();
      expect(result, equals('start middle end'));
    });
  });
}
