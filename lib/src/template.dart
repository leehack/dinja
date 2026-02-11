import 'lexer.dart';
import 'parser.dart';
import 'ast/nodes.dart';
import 'runtime/context.dart';
import 'types/jinja_string.dart';
import 'types/value.dart';

/// Represents a compiled Jinja template.
class Template {
  final Program _ast;

  /// The original source text of the template.
  final String source;

  /// Creates a [Template] from the given [source] string.
  ///
  /// The source is immediately lexed and parsed.
  /// Throws a [ParserException] if the template syntax is invalid.
  Template(this.source) : _ast = _parse(source);

  static Program _parse(String source) {
    final lexer = Lexer(source);
    final lexerResult = lexer.tokenize();
    final parser = Parser(lexerResult.tokens, source);
    return parser.parse();
  }

  /// Renders the template with the given context.
  ///
  /// [values] can be a `Map<String, dynamic>` which will be converted to JinjaValues.
  /// Renders the template with the given [values] and returns a plain string.
  ///
  /// [values] provides the context variables.
  ///
  /// Note: The returned string is the final rendered output. If you need
  /// to inspect input/template boundaries (e.g. for debugging taint tracking),
  /// use [renderJinjaResult] instead.
  String render([Map<String, dynamic>? values]) {
    final ctx = Context();

    // built-ins are global, but we can allow custom values
    if (values != null) {
      values.forEach((k, v) {
        ctx.set(k, val(v));
      });
    }

    final result = _ast.execute(ctx);
    return result.toString();
  }

  /// Renders and returns the raw JinjaString (preserving parts/input marking).
  JinjaString renderJinjaResult([Map<String, dynamic>? values]) {
    final ctx = Context();
    if (values != null) {
      values.forEach((k, v) {
        ctx.set(k, val(v));
      });
    }

    final result = _ast.execute(ctx);
    if (result is JinjaStringValue) {
      return result.value;
    }
    return JinjaString([JinjaStringPart(result.toString(), false)]);
  }
}
