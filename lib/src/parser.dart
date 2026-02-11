import 'lexer.dart';
import 'ast/nodes.dart';

/// Exception thrown when a parsing error is encountered.
class ParserException implements Exception {
  /// The error message.
  final String message;

  /// The source text being parsed.
  final String source;

  /// The position in the source where the error occurred.
  final int pos;

  /// The line number where the error occurred (1-indexed).
  final int? line;

  /// The column number where the error occurred (1-indexed).
  final int? col;

  ParserException(this.message, this.source, this.pos, [this.line, this.col]);

  @override
  String toString() {
    if (line != null && col != null) {
      return 'ParserException: $message at $line:$col';
    }
    return 'ParserException: $message at pos $pos';
  }
}

/// The parser responsible for building an AST from a stream of [Token]s.
class Parser {
  /// The list of tokens to parse.
  final List<Token> tokens;

  /// The original source text.
  final String source;

  /// The current position in the token stream.
  int current = 0;

  Parser(this.tokens, this.source);

  /// Parses the token stream and returns the root [Program] node of the AST.
  Program parse() {
    final body = <Statement>[];
    while (current < tokens.length) {
      body.add(parseAny());
    }
    return Program(body);
  }

  // Helper methods

  Token peek([int offset = 0]) {
    if (current + offset >= tokens.length) {
      return const Token(TokenType.eof, '', -1, -1, -1);
    }
    return tokens[current + offset];
  }

  Token expect(TokenType type, String error) {
    final t = peek();
    if (t.type != type) {
      throw ParserException(
        '$error (Got ${t.value})',
        source,
        t.pos,
        t.line,
        t.col,
      );
    }
    current++;
    return t;
  }

  void expectIdentifier(String name) {
    final t = peek();
    if (t.type != TokenType.identifier || t.value != name) {
      throw ParserException(
        'Expected identifier: $name',
        source,
        t.pos,
        t.line,
        t.col,
      );
    }
    current++;
  }

  bool isType(TokenType type) {
    return peek().type == type;
  }

  bool isIdentifier(String name) {
    final t = peek();
    return t.type == TokenType.identifier && t.value == name;
  }

  bool isStatement(List<String> names) {
    if (peek().type != TokenType.openStatement) return false;
    // Check next token
    if (current + 1 >= tokens.length) return false;
    final next = tokens[current + 1];
    if (next.type != TokenType.identifier) return false;
    return names.contains(next.value);
  }

  // Parse methods

  Statement parseAny() {
    final t = peek();
    final startPos = t.pos;

    switch (t.type) {
      case TokenType.comment:
        current++;
        return CommentStatement(startPos, t.value);
      case TokenType.text:
        current++;
        return StringLiteral(startPos, t.value, isSafe: true);
      case TokenType.stringLiteral:
        current++;
        return StringLiteral(startPos, t.value, isSafe: false);
      case TokenType.openStatement:
        return parseJinjaStatement();
      case TokenType.openExpression:
        return parseJinjaExpression();
      default:
        throw ParserException(
          'Unexpected token type: ${t.type}',
          source,
          startPos,
          t.line,
          t.col,
        );
    }
  }

  Statement parseJinjaExpression() {
    expect(TokenType.openExpression, 'Expected {{');
    final result = parseExpression();
    expect(TokenType.closeExpression, 'Expected }}');
    return result;
  }

  Statement parseJinjaStatement() {
    expect(TokenType.openStatement, 'Expected {%');

    final t = peek();
    if (t.type != TokenType.identifier) {
      throw ParserException(
        'Unknown statement start',
        source,
        t.pos,
        t.line,
        t.col,
      );
    }

    final startPos = t.pos;
    final name = t.value;
    current++; // consume identifier

    Statement result;

    switch (name) {
      case 'set':
        result = parseSetStatement(startPos);
        break;
      case 'if':
        result = parseIfStatement(startPos);
        expect(TokenType.openStatement, 'Expected {%');
        expectIdentifier('endif');
        expect(TokenType.closeStatement, 'Expected %}');
        break;
      case 'macro':
        result = parseMacroStatement(startPos);
        expect(TokenType.openStatement, 'Expected {%');
        expectIdentifier('endmacro');
        expect(TokenType.closeStatement, 'Expected %}');
        break;
      case 'for':
        result = parseForStatement(startPos);
        expect(TokenType.openStatement, 'Expected {%');
        expectIdentifier('endfor');
        expect(TokenType.closeStatement, 'Expected %}');
        break;
      case 'do':
        result = parseDoStatement(startPos);
        break;
      case 'break':
        expect(TokenType.closeStatement, 'Expected %}');
        result = BreakStatement(startPos);
        break;
      case 'continue':
        expect(TokenType.closeStatement, 'Expected %}');
        result = ContinueStatement(startPos);
        break;
      case 'call':
        // Optional caller args: {% call(x) dump(x) %}
        List<Statement> callerArgs = [];
        if (isType(TokenType.openParen)) {
          callerArgs = parseArgs();
        }

        final callee = parsePrimaryExpression();
        // Should verify callee is identifier or call expression?
        // Parser.cpp checks `is_type<identifier>(callee)` but general call expression is also valid?
        // Parser.cpp: `if (!is_type<identifier>(callee)) throw ...` strict check.
        // But `dump(x)` is a call expression.
        // Wait, parser.cpp calls `parse_primary_expression`.
        // If I have `dump(x)`, parsePrimary parses `dump` (id), then checks open paren...
        // Ah, `parse_primary_expression` in C++ returns CallExpression if parens follow?
        // Let's check `parse_primary_expression` in C++.
        // No, `parse_primary_expression` handles literals and identifiers and aggregators.
        // It consumes `(` for parenthesized expression but NOT function call.
        // `parse_call_expression` handles function calls.

        // In `parser.cpp` -> `parse_jinja_statement` -> `call`:
        // `auto callee = parse_primary_expression();`
        // `if (!is_type<identifier>(callee))` -> assumes we are calling a macro by name?
        // `auto call_args = parse_args();`
        // So syntax is `{% call macro_name(args) %}`

        if (callee is! Identifier) {
          throw ParserException(
            'Expected identifier for call',
            source,
            startPos,
            t.line,
            t.col,
          );
        }

        final callArgs = parseArgs();
        expect(TokenType.closeStatement, 'Expected %}');

        final body = <Statement>[];
        while (!isStatement(['endcall'])) {
          body.add(parseAny());
        }

        expect(TokenType.openStatement, 'Expected {%');
        expectIdentifier('endcall');
        expect(TokenType.closeStatement, 'Expected %}');

        final callExpr = CallExpression(startPos, callee, callArgs);
        result = CallStatement(startPos, callExpr, callerArgs, body);
        break;

      case 'filter':
        var filterNode = parsePrimaryExpression();
        if (filterNode is Identifier && isType(TokenType.openParen)) {
          filterNode = parseCallExpression(filterNode);
        }
        expect(TokenType.closeStatement, 'Expected %}');

        final body = <Statement>[];
        while (!isStatement(['endfilter'])) {
          body.add(parseAny());
        }

        expect(TokenType.openStatement, 'Expected {%');
        expectIdentifier('endfilter');
        expect(TokenType.closeStatement, 'Expected %}');

        result = FilterStatement(startPos, filterNode, body);
        break;

      case 'generation':
      case 'endgeneration':
        // Ignore generation blocks
        // Just consume body until endgeneration?
        // Parser.cpp: `result = mk_stmt<noop_statement>(start_pos); current++;`
        // It seems it just treats the tag itself as noop, but what about the content?
        // "Ignore generation blocks (transformers-specific)"
        // "See https://github.com/huggingface/transformers/pull/30650"
        // If it's `{% generation %}`, just return Noop?
        // But then the text inside will be parsed as text?
        // Yes, parser.cpp just returns Noop for the tag. The content is parsed as content.
        // And `endgeneration` tag is also Noop.
        // So effectively they are stripped but content remains.
        result = NoopStatement(startPos);
        expect(TokenType.closeStatement, 'Expected %}');
        break;

      default:
        throw ParserException(
          'Unknown statement: $name',
          source,
          startPos,
          t.line,
          t.col,
        );
    }

    return result;
  }

  SetStatement parseSetStatement(int startPos) {
    final left = parseExpressionSequence();
    Expression? value;
    final body = <Statement>[];

    if (isType(TokenType.equals)) {
      current++;
      value = parseExpressionSequence();
    } else {
      expect(TokenType.closeStatement, 'Expected %}');
      while (!isStatement(['endset'])) {
        body.add(parseAny());
      }
      expect(TokenType.openStatement, 'Expected {%');
      expectIdentifier('endset');
    }
    expect(TokenType.closeStatement, 'Expected %}');
    return SetStatement(startPos, left, value, body);
  }

  IfStatement parseIfStatement(int startPos) {
    final test = parseExpression();
    expect(TokenType.closeStatement, 'Expected %}');

    final body = <Statement>[];
    final alternate = <Statement>[];

    while (!isStatement(['elif', 'else', 'endif'])) {
      body.add(parseAny());
    }

    if (isStatement(['elif'])) {
      final pos0 = current;
      current += 2; // consume {% elif
      alternate.add(parseIfStatement(pos0)); // Nested If
    } else if (isStatement(['else'])) {
      current += 2; // consume {% else
      expect(TokenType.closeStatement, 'Expected %}');

      while (!isStatement(['endif'])) {
        alternate.add(parseAny());
      }
    }

    return IfStatement(startPos, test, body, alternate);
  }

  MacroStatement parseMacroStatement(int startPos) {
    final name = parsePrimaryExpression();
    final args = parseArgs()
        .cast<Expression>(); // args in macros must be expressions?
    // Parser.cpp uses `parse_args()` returning `statements`.
    // In definition `statements args`.

    expect(TokenType.closeStatement, 'Expected %}');
    final body = <Statement>[];
    while (!isStatement(['endmacro'])) {
      body.add(parseAny());
    }
    return MacroStatement(startPos, name, args, body);
  }

  Expression parseExpressionSequence({bool primary = false}) {
    final startPos = current;
    final exprs = <Expression>[];

    exprs.add(primary ? parsePrimaryExpression() : parseExpression());

    bool isTuple = isType(TokenType.comma);
    while (isType(TokenType.comma)) {
      current++;
      exprs.add(primary ? parsePrimaryExpression() : parseExpression());
    }

    if (isTuple) {
      return TupleLiteral(startPos, exprs);
    }
    return exprs[0];
  }

  ForStatement parseForStatement(int startPos) {
    final loopVar = parseExpressionSequence(primary: true);
    if (!isIdentifier('in')) {
      final t = peek();
      throw ParserException("Expected 'in'", source, t.pos, t.line, t.col);
    }
    current++;

    final iterable = parseExpression();
    expect(TokenType.closeStatement, 'Expected %}');

    final body = <Statement>[];
    final defaultBlock = <Statement>[]; // 'else' block

    while (!isStatement(['endfor', 'else'])) {
      body.add(parseAny());
    }

    if (isStatement(['else'])) {
      current += 2; // {% else
      expect(TokenType.closeStatement, 'Expected %}');
      while (!isStatement(['endfor'])) {
        defaultBlock.add(parseAny());
      }
    }

    return ForStatement(startPos, loopVar, iterable, body, defaultBlock);
  }

  DoStatement parseDoStatement(int startPos) {
    final expr = parseExpression();
    expect(TokenType.closeStatement, 'Expected %}');
    return DoStatement(startPos, expr);
  }

  List<Statement> parseArgs() {
    expect(TokenType.openParen, 'Expected (');
    final args = <Statement>[];

    while (!isType(TokenType.closeParen)) {
      Statement arg;
      if (peek().type == TokenType.multiplicativeBinaryOperator &&
          peek().value == '*') {
        final startPos = current;
        current++;
        arg = SpreadExpression(startPos, parseExpression());
      } else {
        arg = parseExpression();
        if (isType(TokenType.equals)) {
          final startPos = current;
          current++;
          arg = KeywordArgumentExpression(
            startPos,
            arg as Expression,
            parseExpression(),
          );
        }
      }
      args.add(arg);
      if (isType(TokenType.comma)) {
        current++;
      }
    }
    expect(TokenType.closeParen, 'Expected )');
    return args;
  }

  // Expression parsing (Precedence climbing)

  Expression parseExpression() {
    return parseIfExpression();
  }

  Expression parseIfExpression() {
    var a = parseLogicalOrExpression();
    if (isIdentifier('if')) {
      final startPos = current;
      current++; // if
      final test = parseLogicalOrExpression();
      if (isIdentifier('else')) {
        final pos0 = current;
        current++; // else
        final falseExpr = parseIfExpression();
        return TernaryExpression(pos0, test, a, falseExpr);
      } else {
        return SelectExpression(startPos, a, test);
      }
    }
    return a;
  }

  Expression parseLogicalOrExpression() {
    var left = parseLogicalAndExpression();
    while (isIdentifier('or')) {
      final startPos = current;
      final op = tokens[current++];
      left = BinaryExpression(startPos, op, left, parseLogicalAndExpression());
    }
    return left;
  }

  Expression parseLogicalAndExpression() {
    var left = parseLogicalNegationExpression();
    while (isIdentifier('and')) {
      final startPos = current;
      final op = tokens[current++];
      left = BinaryExpression(
        startPos,
        op,
        left,
        parseLogicalNegationExpression(),
      );
    }
    return left;
  }

  Expression parseLogicalNegationExpression() {
    if (isIdentifier('not')) {
      final startPos = current;
      final op = tokens[current++];
      return UnaryExpression(startPos, op, parseLogicalNegationExpression());
    }
    return parseComparisonExpression();
  }

  Expression parseComparisonExpression() {
    var left = parseAdditiveExpression();
    while (true) {
      if (current >= tokens.length) break;

      Token op;
      final startPos = current;

      if (isIdentifier('not') &&
          peek(1).type == TokenType.identifier &&
          peek(1).value == 'in') {
        final t1 = peek();
        op = Token(TokenType.identifier, 'not in', startPos, t1.line, t1.col);
        current += 2;
      } else if (isIdentifier('in')) {
        op = tokens[current++];
      } else if (isType(TokenType.comparisonBinaryOperator)) {
        op = tokens[current++];
      } else {
        break;
      }
      left = BinaryExpression(startPos, op, left, parseAdditiveExpression());
    }
    return left;
  }

  Expression parseAdditiveExpression() {
    var left = parseMultiplicativeExpression();
    while (isType(TokenType.additiveBinaryOperator)) {
      final startPos = current;
      final op = tokens[current++];
      left = BinaryExpression(
        startPos,
        op,
        left,
        parseMultiplicativeExpression(),
      );
    }
    return left;
  }

  Expression parseMultiplicativeExpression() {
    var left = parsePowerExpression();
    while (isType(TokenType.multiplicativeBinaryOperator) ||
        isType(TokenType.floorDivision)) {
      final startPos = current;
      final op = tokens[current++];
      left = BinaryExpression(startPos, op, left, parsePowerExpression());
    }
    return left;
  }

  Expression parsePowerExpression() {
    var left = parseTestExpression();
    while (isType(TokenType.power)) {
      final startPos = current;
      final op = tokens[current++];
      left = BinaryExpression(startPos, op, left, parseTestExpression());
    }
    return left;
  }

  Expression parseTestExpression() {
    var operand = parseFilterExpression();
    while (isIdentifier('is')) {
      final startPos = current;
      current++; // is
      bool negate = false;
      if (isIdentifier('not')) {
        current++;
        negate = true;
      }
      var testId = parsePrimaryExpression();
      if (isType(TokenType.openParen)) {
        testId = parseCallExpression(testId);
      }
      operand = TestExpression(startPos, operand, negate, testId);
    }
    return operand;
  }

  Expression parseFilterExpression() {
    var operand = parseCallMemberExpression();
    while (isType(TokenType.pipe)) {
      final startPos = current;
      current++; // |
      var filter = parsePrimaryExpression();
      if (isType(TokenType.openParen)) {
        filter = parseCallExpression(filter);
      }
      operand = FilterExpression(startPos, operand, filter);
    }
    return operand;
  }

  Expression parseCallMemberExpression() {
    var member = parseMemberExpression(parsePrimaryExpression());
    return isType(TokenType.openParen) ? parseCallExpression(member) : member;
  }

  Expression parseCallExpression(Expression callee) {
    // In parser.cpp start_pos = current (the call parens start) check?
    // No, call expression includes callee.
    // Logic: foo.x().y()
    // parseCallMemberExpression -> parseMember(primary) -> returns MemberExpr

    // Here:
    // 1. Create CallExpression(callee, args)
    // 2. Wrap in MemberExpression if followed by . or [
    // 3. Recurse if followed by (

    var expr = CallExpression(callee.pos, callee, parseArgs());
    var member = parseMemberExpression(expr);

    return isType(TokenType.openParen) ? parseCallExpression(member) : member;
  }

  Expression parseMemberExpression(Expression object) {
    final startPos = object.pos;
    while (isType(TokenType.dot) || isType(TokenType.openSquareBracket)) {
      final op = tokens[current++];
      bool computed = op.type == TokenType.openSquareBracket;
      Expression prop;

      if (computed) {
        prop = parseMemberExpressionArguments();
        expect(TokenType.closeSquareBracket, 'Expected ]');
      } else {
        prop = parsePrimaryExpression();
      }
      object = MemberExpression(startPos, object, prop, computed: computed);
    }
    return object;
  }

  Expression parseMemberExpressionArguments() {
    // Slices or single expression
    final slices = <Expression?>[];
    bool isSlice = false;
    final startPos = current;

    while (!isType(TokenType.closeSquareBracket)) {
      if (isType(TokenType.colon)) {
        slices.add(null);
        current++;
        isSlice = true;
      } else {
        slices.add(parseExpression());
        if (isType(TokenType.colon)) {
          current++;
          isSlice = true;
        }
      }
    }

    if (isSlice) {
      final start = slices.isNotEmpty ? slices[0] : null;
      final stop = slices.length > 1 ? slices[1] : null;
      final step = slices.length > 2 ? slices[2] : null;
      return SliceExpression(startPos, start, stop, step);
    }
    return slices[0]!;
  }

  Expression parsePrimaryExpression() {
    final t = tokens[current++];
    final startPos = t.pos;

    switch (t.type) {
      case TokenType.numericLiteral:
        if (t.value.contains('.')) {
          return FloatLiteral(startPos, double.parse(t.value));
        } else {
          return IntegerLiteral(startPos, int.parse(t.value));
        }
      case TokenType.stringLiteral:
        var val = t.value;
        // String concatenation of adjacent literals ("a" "b" -> "ab")
        while (current < tokens.length && isType(TokenType.stringLiteral)) {
          val += tokens[current++].value;
        }
        return StringLiteral(startPos, val);
      case TokenType.identifier:
        return Identifier(startPos, t.value);
      case TokenType.openParen:
        final expr = parseExpressionSequence();
        expect(TokenType.closeParen, 'Expected )');
        return expr;
      case TokenType.openSquareBracket:
        final vals = <Expression>[];
        while (!isType(TokenType.closeSquareBracket)) {
          vals.add(parseExpression());
          if (isType(TokenType.comma)) current++;
        }
        current++;
        return ArrayLiteral(startPos, vals);
      case TokenType.openCurlyBracket:
        final pairs = <MapEntry<Expression, Expression>>[];
        while (!isType(TokenType.closeCurlyBracket)) {
          final key = parseExpression();
          expect(TokenType.colon, 'Expected :');
          pairs.add(MapEntry(key, parseExpression()));
          if (isType(TokenType.comma)) current++;
        }
        current++;
        return ObjectLiteral(startPos, pairs);
      default:
        throw ParserException(
          'Unexpected token: ${t.value}',
          source,
          startPos,
          t.line,
          t.col,
        );
    }
  }
}
