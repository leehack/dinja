import 'dart:convert';

import 'package:test/test.dart';
import 'package:dinja/src/lexer.dart';
import 'package:dinja/src/template.dart';

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

  group('Minus after not', () {
    List<(TokenType, String)> lex(String source) => [
      for (final t in Lexer(source).tokenize().tokens) (t.type, t.value),
    ];

    test('is unary after the not operator', () {
      expect(lex('{{ not -n }}')[2], (TokenType.unaryOperator, '-'));
      expect(lex('{{ not -1 }}')[2], (TokenType.numericLiteral, '-1'));
      expect(lex('{{ x is not +1 }}')[4], (TokenType.numericLiteral, '+1'));
    });

    test('stays binary after a member or filter named not', () {
      expect(lex('{{ x.not - 1 }}')[4], (
        TokenType.additiveBinaryOperator,
        '-',
      ));
      expect(lex('{{ x|not - 1 }}')[4], (
        TokenType.additiveBinaryOperator,
        '-',
      ));
    });
  });

  group('Template text', () {
    // llama.cpp 7fe450e1 and Jinja2 3.1.6 print each of these verbatim.
    for (final source in [
      'a"        "b',
      '"        "',
      '{% if true %}x"        "y{% endif %}',
    ]) {
      test('keeps $source', () {
        expect(
          Template(source).render(),
          source.replaceAll(RegExp(r'{%[^%]*%}'), ''),
        );
      });
    }
  });

  group('lstrip_blocks after a newline removed by trim_blocks', () {
    // llama.cpp 7fe450e1 and Jinja2 3.1.6 give each of these outputs.
    const cases = {
      '{% if true %}\n    {% set x = 1 %}b{% endif %}': 'b',
      '{% if true %}\n\t{% if true %}b{% endif %}{% endif %}': 'b',
      '{% if false %}a{% else %}\n    {% endif %}b': 'b',
      '{% if false %}a{% elif true %}\n  {% endif %}b': 'b',
      '{% for i in [1, 2] %}\n    {% if i %}{{ i }}{% endif %}\n{% endfor %}':
          '12',
      '{% macro m() %}\n    {% if true %}m{% endif %}\n{% endmacro %}{{ m() }}':
          'm',
      '{% macro m() %}[{{ caller() }}]{% endmacro %}'
              '{% call m() %}\n    {% if true %}c{% endif %}\n{% endcall %}':
          '[c]',
      '{% filter upper %}\n    {% if true %}f{% endif %}\n{% endfilter %}': 'F',
      '{% if true %}\n    {# note #}b{% endif %}': 'b',
      '{# note #}\n    {% if true %}b{% endif %}': 'b',
      '{% set x = 1 %}\n    {% set y = 2 %}b': 'b',
    };
    cases.forEach((source, expected) {
      test('strips the indentation in ${jsonEncode(source)}', () {
        expect(Template(source).render(), expected);
      });
    });

    test('strips the indentation before a generation block', () {
      // llama.cpp 7fe450e1 output; Jinja2 has no generation tag.
      expect(
        Template(
          '{% generation %}\n    {% if true %}g{% endif %}\n{% endgeneration %}',
        ).render(),
        'g',
      );
    });
  });

  group('lstrip_blocks', () {
    // llama.cpp 7fe450e1 and Jinja2 3.1.6 give each of these outputs.
    const cases = {
      'a\n    {% if true %}b{% endif %}': 'a\nb',
      'x: {% if true %}b{% endif %}': 'x: b',
      '    {% if true %}b{% endif %}': 'b',
      '{{ "x" }}\n    {% if true %}b{% endif %}': 'x\nb',
      '{% if true %}\n    {{ "e" }}{% endif %}': '    e',
      '{% if true %}\n\n    {% set y = 1 %}b{% endif %}': '\nb',
      '{% if true %} \n    {% set y = 1 %}b{% endif %}': ' \nb',
      '{% if true %}\n    x    {% set y = 1 %}b{% endif %}': '    x    b',
      '{% if true %}\n    {%- set y = 1 %}b{% endif %}': 'b',
      '{% if true -%}\n    {% set y = 1 %}b{% endif %}': 'b',
      '{% if true %}x\n    {% endif %}': 'x\n',
    };
    cases.forEach((source, expected) {
      test('renders ${jsonEncode(source)} as ${jsonEncode(expected)}', () {
        expect(Template(source).render(), expected);
      });
    });

    test('keeps text at the start of the template', () {
      // Jinja2 3.1.6 output. llama.cpp 7fe450e1 drops the leading text when it
      // is one character followed only by whitespace.
      expect(Template('a{% if true %}b{% endif %}').render(), 'ab');
      expect(Template('a    {% if true %}b{% endif %}').render(), 'a    b');
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
