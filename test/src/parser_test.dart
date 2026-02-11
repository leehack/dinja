import 'package:test/test.dart';
import 'package:dinja/src/parser.dart';
import 'package:dinja/src/ast/nodes.dart';
import 'package:dinja/src/lexer.dart';

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
        expect(e.line, equals(-1));
      }
    });
  });
}
