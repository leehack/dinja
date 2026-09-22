import 'package:dinja/ast.dart';
import 'package:test/test.dart';

const _template = '''
{% for message in messages %}
{% if message.role == 'system' %}{{ message.content }}{% endif %}
{% if message.tool_calls %}
{% for tool_call in message.tool_calls %}{{ tool_call.function.name }}{% endfor %}
{% endif %}
{% if not message.content %}{{ [1, 2] }}{{ (3, 4) }}{{ {'k': 'v'} }}{% endif %}
{% if message is defined %}{{ join(message, 'x') }}{% endif %}
{% endfor %}
{% macro render(item) %}{{ item }}{% endmacro %}
{% call render('a') %}body{% endcall %}
{% filter upper %}text{% endfilter %}
{% set count = 1 + 2 %}
{{ (count | string) if count else 'none' }}
''';

const _exportedSymbols = <Type>[
  ArrayLiteral,
  BinaryExpression,
  BreakStatement,
  CallExpression,
  CallStatement,
  CommentStatement,
  ContinueStatement,
  DoStatement,
  Expression,
  FilterExpression,
  FilterStatement,
  FloatLiteral,
  ForStatement,
  Identifier,
  IfStatement,
  IntegerLiteral,
  KeywordArgumentExpression,
  MacroStatement,
  MemberExpression,
  NoopStatement,
  ObjectLiteral,
  Program,
  SelectExpression,
  SetStatement,
  SliceExpression,
  SpreadExpression,
  Statement,
  StringLiteral,
  TernaryExpression,
  TestExpression,
  TupleLiteral,
  UnaryExpression,
  Lexer,
  LexerException,
  LexerResult,
  Token,
  TokenType,
  Parser,
  ParserException,
];

void main() {
  group('package:dinja/ast.dart', () {
    test('exports every symbol named in its show clauses', () {
      expect(_exportedSymbols, hasLength(39));
      expect(_exportedSymbols.toSet(), hasLength(_exportedSymbols.length));
    });

    test('exposes the lexer entry point', () {
      final LexerResult lexed = Lexer(_template).tokenize();

      expect(lexed.source, isNotEmpty);
      expect(lexed.tokens, isNotEmpty);
      expect(lexed.tokens.first, isA<Token>());
      expect(
        lexed.tokens.map((Token t) => t.type),
        contains(TokenType.openStatement),
      );
    });

    test('exposes the parser entry point and a walkable Program', () {
      final LexerResult lexed = Lexer(_template).tokenize();
      final Program program = Parser(lexed.tokens, lexed.source).parse();

      expect(program.body, isNotEmpty);

      final seen = <Type>{};
      void visit(Statement node) {
        seen.add(node.runtimeType);
        if (node is Program) {
          node.body.forEach(visit);
        } else if (node is IfStatement) {
          visit(node.test);
          node.body.forEach(visit);
          node.alternate.forEach(visit);
        } else if (node is ForStatement) {
          visit(node.iterable);
          visit(node.loopVar);
          node.body.forEach(visit);
          node.defaultBlock.forEach(visit);
        } else if (node is SetStatement) {
          visit(node.assignee);
          final Expression? value = node.value;
          if (value != null) visit(value);
          node.body.forEach(visit);
        } else if (node is FilterStatement) {
          visit(node.filter);
          node.body.forEach(visit);
        } else if (node is CallStatement) {
          visit(node.call);
          node.callerArgs.forEach(visit);
          node.body.forEach(visit);
        } else if (node is MacroStatement) {
          node.args.forEach(visit);
          node.body.forEach(visit);
        } else if (node is BinaryExpression) {
          visit(node.left);
          visit(node.right);
        } else if (node is UnaryExpression) {
          visit(node.argument);
        } else if (node is FilterExpression) {
          visit(node.operand);
          visit(node.filter);
        } else if (node is TestExpression) {
          visit(node.operand);
          visit(node.test);
        } else if (node is CallExpression) {
          visit(node.callee);
          node.args.forEach(visit);
        } else if (node is MemberExpression) {
          visit(node.object);
          visit(node.property);
        } else if (node is ObjectLiteral) {
          for (final MapEntry<Expression, Expression> entry in node.items) {
            visit(entry.key);
            visit(entry.value);
          }
        } else if (node is ArrayLiteral) {
          node.items.forEach(visit);
        } else if (node is TupleLiteral) {
          node.items.forEach(visit);
        } else if (node is TernaryExpression) {
          visit(node.condition);
          visit(node.trueExpr);
          visit(node.falseExpr);
        }
      }

      visit(program);

      expect(
        seen,
        containsAll(<Type>[
          Program,
          ForStatement,
          IfStatement,
          SetStatement,
          MacroStatement,
          CallStatement,
          FilterStatement,
          BinaryExpression,
          UnaryExpression,
          MemberExpression,
          FilterExpression,
          TestExpression,
          CallExpression,
          TernaryExpression,
          ObjectLiteral,
          ArrayLiteral,
          TupleLiteral,
          Identifier,
          IntegerLiteral,
          StringLiteral,
        ]),
      );
    });

    test('exposes the lexer and parser exception types', () {
      expect(
        () => Lexer('{{ "unterminated }}').tokenize(),
        throwsA(isA<LexerException>()),
      );
      expect(
        () => Parser(
          Lexer('{% if x %}no endif').tokenize().tokens,
          '{% if x %}no endif',
        ).parse(),
        throwsA(isA<ParserException>()),
      );
    });
  });
}
