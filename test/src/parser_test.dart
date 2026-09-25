import 'package:test/test.dart';
import 'package:dinja/src/parser.dart';
import 'package:dinja/src/ast/nodes.dart';
import 'package:dinja/src/lexer.dart';
import 'package:dinja/src/template.dart';

void main() {
  group('Parser', () {
    test('Parses text', () {
      final src = 'Hello';
      final tokens = Lexer(src).tokenize().tokens;
      final parser = Parser(tokens, src);
      final program = parser.parse();
      expect(program.body.length, 1);
      expect(program.body[0], isA<StringLiteral>()); // Text is StringLiteral
      expect((program.body[0] as StringLiteral).value, 'Hello');
    });

    test('Parses variable', () {
      final src = '{{ name }}';
      final tokens = Lexer(src).tokenize().tokens;
      final parser = Parser(tokens, src);
      final program = parser.parse();
      expect(program.body.length, 1);
      expect(
        program.body[0],
        isA<Identifier>(),
      ); // {{ name }} is Identifier expression
      expect((program.body[0] as Identifier).name, 'name');
    });

    test('Parses if statement', () {
      final src = '{% if true %}A{% endif %}';
      final tokens = Lexer(src).tokenize().tokens;
      final parser = Parser(tokens, src);
      final program = parser.parse();
      expect(program.body.length, 1);
      expect(program.body[0], isA<IfStatement>());
    });

    test('Parses for loop', () {
      final src = '{% for i in list %}A{% endfor %}';
      final tokens = Lexer(src).tokenize().tokens;
      final parser = Parser(tokens, src);
      final program = parser.parse();
      expect(program.body.length, 1);
      expect(program.body[0], isA<ForStatement>());
    });

    test('Parses set', () {
      final src = '{% set x = 1 %}';
      final tokens = Lexer(src).tokenize().tokens;
      final parser = Parser(tokens, src);
      final program = parser.parse();
      expect(program.body.length, 1);
      expect(program.body[0], isA<SetStatement>());
    });

    test('Parses do', () {
      final src = '{% do list.append(1) %}';
      final tokens = Lexer(src).tokenize().tokens;
      final parser = Parser(tokens, src);
      final program = parser.parse();
      expect(program.body.length, 1);
      expect(program.body[0], isA<DoStatement>());
    });
  });

  group('Parser Error Location', () {
    test('unexpected token', () {
      const source = '{% if true %}\n  {{ 1 + }}\n{% endif %}';
      try {
        final tokens = Lexer(source).tokenize().tokens;
        Parser(tokens, source).parse();
        fail('Should have thrown ParserException');
      } on ParserException catch (e) {
        expect(e.line, equals(2));
      }
    });

    test('missing end tag', () {
      const source = '{% if true %}\n  hello';
      try {
        final tokens = Lexer(source).tokenize().tokens;
        Parser(tokens, source).parse();
        fail('Should have thrown ParserException');
      } on ParserException catch (e) {
        expect(e.pos, equals(source.length));
        expect(e.line, equals(2));
        expect(e.col, equals(8));
      }
    });

    // Jinja2 3.1.6 raises "Unexpected end of template" for each of these.
    for (final (source, line, col) in [
      ('{% if x %}no endif', 1, 19),
      ('a\n{% for x in y %}\nb', 3, 2),
      ('{% set x %}abc', 1, 15),
      ('{% macro m() %}x', 1, 17),
      ('{{ x', 1, 5),
      ('{{ 1 +', 1, 7),
      ('{{ f(', 1, 6),
      ('{{ [1,', 1, 7),
      ('{{ x is', 1, 8),
    ]) {
      test('end of input in ${source.replaceAll('\n', r'\n')}', () {
        final e = _parserError(source);
        expect(e.pos, source.length);
        expect(e.line, line);
        expect(e.col, col);
      });
    }

    test('every prefix of a template fails with a positioned exception', () {
      const source =
          "{% macro m(a, b=[1, {'k': (2, 3)}]) %}"
          "{{ a | default('x') ~ b[0:1] }}{% endmacro %}"
          '{% for x in xs if x is not none %}'
          "{{ m(x, b=x.y) if x is eq 1 else x['z'] }}{% endfor %}"
          '{% set t %}{{ -1 ** 2 }}{% endset %}';
      parseTemplate(source);
      for (var end = 0; end < source.length; end++) {
        try {
          parseTemplate(source.substring(0, end));
        } on ParserException catch (e) {
          expect(e.pos, inInclusiveRange(0, end));
        } on LexerException catch (e) {
          expect(e.pos, inInclusiveRange(0, end));
        }
      }
    });

    test('Template locates errors in a CRLF template', () {
      final e = _templateError('{{ a }}\r\n\r\n  {{ 1 + }}\r\n');
      expect(e.line, 3);
      expect(e.col, 10);
      expect(e.source, '{{ a }}\n\n  {{ 1 + }}');
      expect(e.source.substring(e.pos), '}}');
    });

    test('Template locates end of input after a trailing newline', () {
      final e = _templateError('{% if x %}no endif\n');
      expect(e.source, '{% if x %}no endif');
      expect(e.pos, e.source.length);
      expect(e.line, 1);
      expect(e.col, 19);
    });

    test('end of input after a stripped trailing newline', () {
      final e = _parserError('{% if x %}no endif\n');
      expect(e.pos, 18);
      expect(e.line, 1);
      expect(e.col, 19);
    });
  });

  group('Test with an unparenthesized argument', () {
    // Expected values are Jinja2 3.1.6 output.
    for (final (source, expected) in [
      ('{{ 1 is eq 1 }}', 'True'),
      ("{{ 'a' is in ['a'] }}", 'True'),
      ("{{ 'b' is in ['a'] }}", 'False'),
      ("{{ 'k' is in {'k': 1} }}", 'True'),
      ('{{ 3 is gt 2 }}', 'True'),
      ('{{ 1 is not eq 2 }}', 'True'),
      ('{{ n is sameas none }}', 'True'),
      ('{{ x is eq m.z }}', 'True'),
      ("{{ x is eq m['z'] }}", 'True'),
      ("{{ s is eq 'a' 'b' }}", 'True'),
      ('{{ a is divisibleby 3 or b }}', 'B'),
      ('{{ 1 is eq 1 and 2 is eq 3 }}', 'False'),
      ('{{ 1 is eq 1 == true }}', 'True'),
      ('{{ 2 is eq 1 + 1 }}', '1'),
      ('{{ 1 is eq 1 not in [true] }}', 'False'),
      ("{% if 'a' is in ['a', 'b'] %}yes{% endif %}", 'yes'),
      ('{% for i in [1, 2, 3] if i is ne 2 %}{{ i }}{% endfor %}', '13'),
    ]) {
      test(source, () {
        expect(Template(source).render(_testContext), expected);
      });
    }

    test('parses like the parenthesized form', () {
      final test = _parse('{{ x is eq 1 }}') as TestExpression;
      final call = test.test as CallExpression;
      expect((call.callee as Identifier).name, 'eq');
      expect(call.args.single, isA<IntegerLiteral>());
    });
  });

  group('Test without an argument', () {
    // Jinja2 3.1.6 accepts each of these with the same output.
    for (final (source, expected) in [
      ('{{ x is defined and y }}', 'Y'),
      ('{{ x is not none }}', 'True'),
      ('{{ z is odd or y }}', 'Y'),
      ("{{ 'a' if u is defined else 'b' }}", 'b'),
      ("{{ [x is defined, 1] | join(',') }}", 'True,1'),
      ("{{ [1, 2, 3] | select('ne', 2) | join(',') }}", '1,3'),
      ("{{ [1, 2, 3] | reject('in', [2]) | join(',') }}", '1,3'),
    ]) {
      test(source, () {
        expect(Template(source).render(_testContext), expected);
      });
    }

    // Jinja2 rejects these; dinja and llama.cpp keep parsing them this way.
    for (final (source, expected) in [
      ('{{ x is defined if true else 2 }}', 'True'),
      ('{{ x is defined in [false] }}', 'False'),
      ('{{ x is defined not in [true] }}', 'False'),
      ('{{ x is defined is true }}', 'True'),
    ]) {
      test(source, () {
        expect(Template(source).render(_testContext), expected);
      });
    }

    test('before a unary minus is a subtraction', () {
      final sub = _parse('{{ x is eq -1 }}') as BinaryExpression;
      expect(sub.op.value, '-');
      expect((sub.left as TestExpression).test, isA<Identifier>());
    });
  });

  group('Unary minus and plus', () {
    // llama.cpp 7fe450e1 and Jinja2 3.1.6 give each of these outputs.
    for (final (source, expected) in [
      ('{{ -n }}', '-3'),
      ('{{ +m }}', '-3'),
      ('{{ +f }}', '-1.5'),
      ('{{ -f }}', '1.5'),
      ('{{ -m|abs }}', '3'),
      ('{{ -n is number }}', 'True'),
      ('{{ -n is odd }}', 'True'),
      ("{{ items[:-k]|join(',') }}", 'a'),
      ('{{ s[:-k] }}', 'hel'),
      ('{{ s[-k:] }}', 'lo'),
      ('{{ s[::-k] }}', 'olh'),
      ('{{ - -n }}', '3'),
      ('{{ --n }}', '3'),
      ('{{ -+n }}', '-3'),
      ('{{ b - -k }}', '7'),
      ('{{ b + -k }}', '3'),
      ('{{ -k * b }}', '-10'),
      ('{{ k * -b }}', '-10'),
      ('{{ -(k + b) }}', '-7'),
      ('{{ -d.v }}', '-4'),
      ('{{ -k if true else 0 }}', '-2'),
      ('{{ -k < k }}', 'True'),
      ("{{ -k ~ 'x' }}", '-2x'),
      ('{% set y = -k %}{{ y }}', '-2'),
      ('x {{- -k }}', 'x-2'),
      ("{{ {'v': -k}.v }}", '-2'),
    ]) {
      test(source, () {
        expect(Template(source).render(_unaryContext), expected);
      });
    }

    // Jinja2 3.1.6 gives these outputs; llama.cpp 7fe450e1 has no `**` or
    // `//` and rejects `-` after `not`.
    for (final (source, expected) in [
      ('{{ -k ** 2 }}', '4'),
      ('{{ 2 ** -k }}', '0.25'),
      ('{{ -b // k }}', '-3'),
      ('{{ not -n }}', 'False'),
      ('{{ not -z }}', 'True'),
    ]) {
      test(source, () {
        expect(Template(source).render(_unaryContext), expected);
      });
    }

    test('binds tighter than filters, tests, power and member access', () {
      final filter = _parse('{{ -n|abs }}') as FilterExpression;
      expect((filter.operand as UnaryExpression).op.value, '-');

      final test = _parse('{{ -n is number }}') as TestExpression;
      expect(test.operand, isA<UnaryExpression>());

      final power = _parse('{{ -k ** 2 }}') as BinaryExpression;
      expect(power.op.value, '**');
      expect(power.left, isA<UnaryExpression>());

      final member = _parse('{{ -d.v }}') as UnaryExpression;
      expect(member.argument, isA<MemberExpression>());

      final negation = _parse('{{ not -n }}') as UnaryExpression;
      expect(negation.op.value, 'not');
      expect((negation.argument as UnaryExpression).op.value, '-');
    });

    test('rejects a non-numeric operand', () {
      for (final (source, message) in [
        ('{{ -s }}', 'Unary - expects numeric'),
        ('{{ +s }}', 'Unary + expects numeric'),
        ('{{ -items|length }}', 'Unary - expects numeric'),
      ]) {
        expect(
          () => Template(source).render(_unaryContext),
          throwsA(predicate((Object e) => '$e'.contains(message))),
          reason: source,
        );
      }
    });
  });

  group('Binary minus is unchanged', () {
    for (final (source, expected) in [
      ('{{ b - k }}', '3'),
      ('{{ b-k }}', '3'),
      ('{{ b - -2 }}', '7'),
      ('{{ 3 - -2 }}', '5'),
      ('{{ 3-2 }}', '1'),
      ('{{ -2 }}', '-2'),
      ('{{ -2.5 }}', '-2.5'),
      ('{{ -2 + 3 }}', '1'),
      ('{{ -2 ** 2 }}', '4'),
      ('{{ k ** -1 }}', '0.5'),
      ('{{ (k) -b }}', '-3'),
      ('{{ items|length -k }}', '1'),
      ('{{ lst[1] -k }}', '0'),
      ('{{ k -}} x', '2x'),
    ]) {
      test(source, () {
        expect(Template(source).render(_unaryContext), expected);
      });
    }

    test('keeps the same tree', () {
      final sub = _parse('{{ b - -k }}') as BinaryExpression;
      expect(sub.op.value, '-');
      expect(sub.left, isA<Identifier>());
      expect((sub.right as UnaryExpression).op.value, '-');

      final literal = _parse('{{ b - -2 }}') as BinaryExpression;
      expect((literal.right as IntegerLiteral).value, -2);

      expect((_parse('{{ -2 }}') as IntegerLiteral).value, -2);
      expect((_parse('{{ -2.5 }}') as FloatLiteral).value, -2.5);

      for (final source in ['{{ d.not - 1 }}', '{{ d|not - 1 }}']) {
        final sub = _parse(source) as BinaryExpression;
        expect(sub.op.value, '-', reason: source);
        expect(sub.right, isA<IntegerLiteral>(), reason: source);
      }
    });
  });

  group('Empty subscript', () {
    test('parses as a blank expression', () {
      final member = _parse('{{ a[] }}') as MemberExpression;
      expect(member.computed, isTrue);
      expect(member.property, isA<BlankExpression>());
    });

    // llama.cpp 7fe450e1 and Jinja2 3.1.6 give each of these outputs.
    for (final (source, expected) in [
      ("{{ a[]|default('fallback') }}", 'fallback'),
      ('{{ a[] is undefined }}', 'True'),
      ('{{ items[] is undefined }}', 'True'),
      ('{{ s[] is defined }}', 'False'),
      ('[{{ a[] }}]', '[]'),
      ('{% set q = a[] %}{{ q is undefined }}', 'True'),
    ]) {
      test(source, () {
        expect(Template(source).render(_unaryContext), expected);
      });
    }
  });
}

const _unaryContext = <String, dynamic>{
  'n': 3,
  'm': -3,
  'k': 2,
  'b': 5,
  'f': -1.5,
  'z': 0,
  's': 'hello',
  'items': ['a', 'b', 'c'],
  'lst': [1, 2],
  'd': {'v': 4},
  'a': {'name': 'Bob'},
};

const _testContext = <String, dynamic>{
  'x': 1,
  'y': 'Y',
  'z': 2,
  'm': {'z': 1},
  'a': 4,
  'b': 'B',
  'n': null,
  's': 'ab',
};

Statement _parse(String source) {
  final program = Parser(Lexer(source).tokenize().tokens, source).parse();
  return program.body.single;
}

ParserException _templateError(String source) {
  try {
    Template(source);
  } on ParserException catch (e) {
    return e;
  }
  fail('Template accepted an invalid template');
}

ParserException _parserError(String source) {
  try {
    parseTemplate(source);
  } on ParserException catch (e) {
    return e;
  }
  fail('parseTemplate accepted an invalid template');
}
