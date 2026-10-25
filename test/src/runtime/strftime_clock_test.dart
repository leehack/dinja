import 'package:dinja/dinja.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 1, 2, 3, 4, 5);

  test(
    'the public callable supplies a fixed clock to repeated template calls',
    () {
      final template = Template(
        "{{ strftime_now('%F %T') }}|{{ strftime_now('%Y %j %z') }}",
      );
      expect(
        template.render({'strftime_now': strftimeNow(now)}),
        '2026-01-02 03:04:05|2026 002 +0000',
      );
    },
  );

  test('independent callables and default renders keep their own clocks', () {
    final template = Template("{{ strftime_now('%F') }}");
    final fixed = strftimeNow(now);
    expect(template.render({'strftime_now': fixed}), '2026-01-02');
    expect(
      template.render({'strftime_now': strftimeNow(DateTime.utc(2001))}),
      '2001-01-01',
    );
    final before = DateTime.now();
    final actual = template.render();
    final after = DateTime.now();
    String date(DateTime t) => t.toIso8601String().substring(0, 10);
    expect(actual, anyOf(date(before), date(after)));
    expect(template.render({'strftime_now': fixed}), '2026-01-02');
  });

  test('a caller-provided format retains input escaping', () {
    final template = Template('{{ strftime_now(format) }}');
    expect(
      template.render({
        'strftime_now': strftimeNow(now),
        'format': JinjaString.user('<b>%Y</b>'),
      }),
      '&lt;b&gt;2026&lt;/b&gt;',
    );
    expect(
      template.render({
        'strftime_now': strftimeNow(now),
        'format': '<b>%Y</b>',
      }),
      '<b>2026</b>',
    );
  });

  test(
    'argument and formatted-output failures match the built-in contract',
    () {
      for (final source in [
        '{{ strftime_now() }}',
        '{{ strftime_now(1) }}',
        "{{ strftime_now('') }}",
        "{{ strftime_now('${'x' * 100}') }}",
      ]) {
        expect(
          () => Template(source).render({'strftime_now': strftimeNow(now)}),
          throwsException,
        );
      }
    },
  );

  test('rendered input stays escaped through safe and derived filters', () {
    for (final source in [
      '{% set f %}{{ format }}{% endset %}{{ strftime_now(f)|safe }}',
      '{% macro f() %}{{ format }}{% endmacro %}{{ strftime_now(f())|safe }}',
      '{% set f %}{{ format }}{% endset %}'
          '{{ strftime_now(f)|upper|safe }}',
    ]) {
      final template = Template(source);
      final input = {'format': JinjaString.user('<injected>')};
      final expected = template.render(input);
      expect(expected.toLowerCase(), '&lt;injected&gt;');
      expect(
        template.render({...input, 'strftime_now': strftimeNow(now)}),
        expected,
      );
    }
  });
}
