import 'dart:io';

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

const _exportedTypes = <Type>[
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
  LexerException,
  ParserException,
];

const Program Function(String) _exportedFunction = parseTemplate;

Set<String> _showClauseNames(String library) {
  final directives = RegExp(
    r"^export\s+'[^']+'([^;]*);",
    multiLine: true,
  ).allMatches(library).map((Match m) => m.group(1)!.trim()).toList();
  expect(directives, isNotEmpty);
  final names = <String>{};
  for (final String combinators in directives) {
    final Match? show = RegExp(r'^show\s+([\s\S]+)$').firstMatch(combinators);
    expect(show, isNotNull, reason: 'export without a show clause');
    names.addAll(show!.group(1)!.split(',').map((s) => s.trim()));
  }
  return names;
}

ParserException _parserError(String source) {
  try {
    parseTemplate(source);
  } on ParserException catch (e) {
    return e;
  }
  fail('parseTemplate accepted an invalid template');
}

void main() {
  group('package:dinja/ast.dart', () {
    test('exports exactly the census symbols', () {
      expect(_exportedTypes.toSet(), hasLength(_exportedTypes.length));

      final census = <String>{
        for (final Type type in _exportedTypes) '$type',
        'parseTemplate',
      };
      expect(census, hasLength(35));
      expect(_exportedFunction('{{ x }}'), isA<Program>());
      expect(
        _showClauseNames(File('lib/ast.dart').readAsStringSync()),
        equals(census),
      );
    });

    test('parseTemplate returns a walkable Program', () {
      final Program program = parseTemplate(_template);

      expect(program.body, isNotEmpty);

      final seen = <Type>{};
      final operators = <String>{};
      void visit(Statement node) {
        seen.add(node.runtimeType);
        if (node is BinaryExpression) operators.add(node.op.value);
        if (node is UnaryExpression) operators.add(node.op.value);
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
      expect(operators, containsAll(<String>['==', '+', 'not']));
    });

    test('parseTemplate locates errors in a CRLF template', () {
      final ParserException e = _parserError('{{ a }}\r\n\r\n  {{ 1 + }}\r\n');

      expect(e.line, 3);
      expect(e.col, 10);
      expect(e.source, '{{ a }}\n\n  {{ 1 + }}');
      expect(e.source.substring(e.pos), '}}');
    });

    test('parseTemplate locates errors in a template with a trailing '
        'newline', () {
      final ParserException e = _parserError('{{ a }}\n{% if %}\n');

      expect(e.line, 2);
      expect(e.col, 7);
      expect(e.source, '{{ a }}\n{% if %}');
      expect(e.source.substring(e.pos), '%}');
    });

    test('parseTemplate throws the exported exception types', () {
      expect(
        () => parseTemplate('{{ "unterminated }}'),
        throwsA(isA<LexerException>()),
      );
      expect(
        () => parseTemplate('{% if x %}no endif'),
        throwsA(isA<ParserException>()),
      );
    });
  });
}
