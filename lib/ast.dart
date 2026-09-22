/// Lexer, parser and AST node types for Jinja templates.
///
/// Use this library to tokenize and parse a template into a [Program] and
/// inspect the resulting tree, without rendering it. `package:dinja/dinja.dart`
/// remains the entry point for rendering.
///
/// ```dart
/// import 'package:dinja/ast.dart';
///
/// final lexed = Lexer('{{ name }}').tokenize();
/// final program = Parser(lexed.tokens, lexed.source).parse();
/// for (final statement in program.body) {
///   print(statement.type);
/// }
/// ```
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
export 'src/lexer.dart'
    show Lexer, LexerException, LexerResult, Token, TokenType;
export 'src/parser.dart' show Parser, ParserException;
