/// Parses Jinja templates into an AST for inspection without rendering them.
///
/// [parseTemplate] returns the root [Program]; walk it by pattern-matching on
/// the node types this library exports. `package:dinja/dinja.dart` remains the
/// entry point for rendering.
///
/// ```dart
/// import 'package:dinja/ast.dart';
///
/// final program = parseTemplate('{{ name }}');
/// for (final statement in program.body) {
///   print(statement.type);
/// }
/// ```
///
/// [BinaryExpression.op] and [UnaryExpression.op] are lexer tokens; read the
/// operator text, such as `==` or `not`, from their `value`. The `Token` and
/// `TokenType` types themselves are not exported.
///
/// This library reads a parsed template; it does not evaluate one.
/// [Statement.execute] cannot be called through it, because the type of its
/// `ctx` parameter is not exported by any dinja library. Render with
/// `Template` from `package:dinja/dinja.dart` instead.
library;

export 'src/ast/nodes.dart'
    show
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
        UnaryExpression;
export 'src/lexer.dart' show LexerException;
export 'src/parser.dart' show ParserException, parseTemplate;
