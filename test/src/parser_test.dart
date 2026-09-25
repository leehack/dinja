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
    ]) {
      test('end of input in ${source.replaceAll('\n', r'\n')}', () {
        final e = _parserError(source);
        expect(e.pos, source.length);
        expect(e.line, line);
        expect(e.col, col);
      });
    }

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
}

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

ParserException _parserError(String source) {
  try {
    parseTemplate(source);
  } on ParserException catch (e) {
    return e;
  }
  fail('parseTemplate accepted an invalid template');
}
