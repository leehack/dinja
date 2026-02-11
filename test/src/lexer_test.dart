import 'package:test/test.dart';
import 'package:dinja/src/lexer.dart';

void main() {
  group('Lexer', () {
    test('Tokenizes simple text', () {
      final lexer = Lexer('Hello World');
      final result = lexer.tokenize();
      expect(result.tokens.length, 1);
      expect(result.tokens[0].type, TokenType.text);
      expect(result.tokens[0].value, 'Hello World');
    });

    test('Tokenizes variable', () {
      final lexer = Lexer('{{ name }}');
      final result = lexer.tokenize();
      expect(result.tokens.length, 3);
      expect(
        result.tokens[0].type,
        TokenType.openExpression,
      ); // Corrected from openVar
      expect(result.tokens[1].type, TokenType.identifier);
      expect(result.tokens[1].value, 'name');
      expect(
        result.tokens[2].type,
        TokenType.closeExpression,
      ); // Corrected from closeVar
    });

    test('Tokenizes block', () {
      final lexer = Lexer('{% if true %}');
      final result = lexer.tokenize();
      expect(result.tokens.length, 4);
      expect(result.tokens[0].type, TokenType.openStatement);
      expect(result.tokens[1].type, TokenType.identifier);
      expect(result.tokens[1].value, 'if');
      expect(
        result.tokens[2].type,
        TokenType.identifier,
      ); // boolean is identifier 'true'
      expect(result.tokens[2].value, 'true');
      expect(result.tokens[3].type, TokenType.closeStatement);
    });

    test('Tokenizes comment', () {
      final lexer = Lexer('{# comment #}');
      final result = lexer.tokenize();
      expect(result.tokens.length, 1); // Comments ARE tokenized
      expect(result.tokens[0].type, TokenType.comment);
    });

    test('Tokenizes mixed content', () {
      final lexer = Lexer('Hello {{ name }}!');
      final result = lexer.tokenize();
      expect(result.tokens.length, 5);
      expect(result.tokens[0].type, TokenType.text);
      expect(result.tokens[0].value, 'Hello ');
      expect(result.tokens[1].type, TokenType.openExpression);
      expect(result.tokens[2].value, 'name');
      expect(result.tokens[3].type, TokenType.closeExpression);
      expect(result.tokens[4].type, TokenType.text);
      expect(result.tokens[4].value, '!');
    });

    test('Handles strings', () {
      final lexer = Lexer('{{ "str" }}');
      final result = lexer.tokenize();
      expect(result.tokens[1].type, TokenType.stringLiteral); // Corrected enum
      expect(result.tokens[1].value, 'str');
    });

    test('Handles numbers', () {
      final lexer = Lexer('{{ 123 45.6 }}');
      final result = lexer.tokenize();
      expect(result.tokens[1].type, TokenType.numericLiteral); // Corrected enum
      expect(result.tokens[1].value, '123');
      expect(
        result.tokens[2].type,
        TokenType.numericLiteral,
      ); // float also numericLiteral in my lexer logic?
      // Lexer check:
      // if (isDigit) -> consumeNumeric -> TokenType.numericLiteral
      // It distinguishes internally but returns TokenType.numericLiteral for both. Is float distinguishable?
      // Lexer implementation uses `TokenType.numericLiteral` for both int and float.
      expect(result.tokens[2].value, '45.6');
    });

    test('Handles operators', () {
      final lexer = Lexer('{{ 1 + 2 }}');
      final result = lexer.tokenize();
      expect(
        result.tokens[2].type,
        TokenType.additiveBinaryOperator,
      ); // + is additive
    });
  });

  group('Lexer Error Location', () {
    test('unterminated string', () {
      const source = 'Hello\n{{ "world';
      try {
        Lexer(source).tokenize();
        fail('Should have thrown LexerException');
      } on LexerException catch (e) {
        expect(e.line, equals(2));
      }
    });
  });
}
