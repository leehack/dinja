import '../types/value.dart';
import '../types/jinja_string.dart';
import 'dart:math' as math;
import '../runtime/context.dart';
import '../runtime/builtins.dart';
import '../lexer.dart'; // for Token

// Signals for control flow
class BreakSignal {}

class ContinueSignal {}

/// Base class for all nodes in the Jinja AST that represent a command or structure.
abstract class Statement {
  /// The starting position of the statement in the source text.
  final int pos; // position in source for debugging/errors

  Statement(this.pos);

  /// Executes the statement within the given [ctx] and returns the result as a [JinjaValue].
  JinjaValue execute(Context ctx);

  /// Returns the type name of the statement.
  String get type;
}

/// Base class for AST nodes that evaluate to a value.
abstract class Expression extends Statement {
  Expression(super.pos);

  @override
  String get type => 'Expression';
}

/// The root node of a Jinja template AST, containing a body of statements.
class Program extends Statement {
  /// The list of statements that make up the template.
  final List<Statement> body;

  Program(this.body) : super(0);

  @override
  String get type => 'Program';

  @override
  JinjaValue execute(Context ctx) {
    return execStatements(body, ctx);
  }
}

// ... helper to execute list of statements and gather output ...
/// Executes a list of [stmts] within the given [ctx] and aggregates their results.
///
/// If a statement returns a string value, it is added to the output.
/// Non-string values (except None and Undefined) are converted to strings.
JinjaValue execStatements(List<Statement> stmts, Context ctx) {
  List<JinjaStringPart> parts = [];
  try {
    for (final stmt in stmts) {
      final val = stmt.execute(ctx);
      if (val is JinjaStringValue) {
        if (val.value.isSafe) {
          parts.addAll(val.value.parts);
        } else {
          parts.addAll(val.value.escape().parts);
        }
      } else if (!val.isNone && !val.isUndefined) {
        // Convert to string and escape it
        String s = val.toString();
        // Manually escape the string s
        final escapedS = s
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&#39;');
        parts.add(JinjaStringPart(escapedS, false));
      }
    }
  } catch (e) {
    if (e is BreakSignal || e is ContinueSignal) rethrow;
    if (e is Exception) {
      // If we have position info, we could wrap it
      // For now, just rethrow but this is where we'd add context
      rethrow;
    }
    rethrow;
  }
  return JinjaStringValue(JinjaString(parts, isSafe: true));
}

/// Represents a conditional 'if' block.
class IfStatement extends Statement {
  /// The condition expression to evaluate.
  final Expression test;

  /// The statements to execute if the condition is true.
  final List<Statement> body;

  /// The statements to execute if the condition is false.
  final List<Statement> alternate;

  IfStatement(super.pos, this.test, this.body, this.alternate);

  @override
  String get type => 'If';

  @override
  JinjaValue execute(Context ctx) {
    final testVal = test.execute(ctx);
    if (testVal.asBool) {
      return execStatements(body, ctx);
    } else {
      return execStatements(alternate, ctx);
    }
  }
}

/// Represents a 'for' loop over an iterable.
class ForStatement extends Statement {
  /// The variable(s) to bind to each item in the iteration.
  final Expression loopVar; // Identifier or TupleLiteral
  /// The expression that evaluates to an iterable object.
  final Expression iterable;

  /// The statements to execute for each item.
  final List<Statement> body;

  /// Optional statements to execute if the iterable is empty.
  final List<Statement> defaultBlock;

  ForStatement(
    super.pos,
    this.loopVar,
    this.iterable,
    this.body,
    this.defaultBlock,
  );

  @override
  String get type => 'For';

  @override
  JinjaValue execute(Context ctx) {
    // New scope for loop

    // Evaluate iterable
    // Handle SelectExpression (filtering) if present in iterable
    Expression iterExpr = iterable;
    Expression? testExpr;

    if (iterable is SelectExpression) {
      final sel = iterable as SelectExpression;
      iterExpr = sel.lhs;
      testExpr = sel.test;
    }

    JinjaValue iterableVal = iterExpr.execute(ctx);

    if (iterableVal.isUndefined) {
      iterableVal = const JinjaList([]);
    }

    if (!iterableVal.isList && !iterableVal.isMap && !iterableVal.isString) {
      throw Exception(
        'Expected iterable in for loop: got ${iterableVal.typeName}',
      );
    }

    List<JinjaValue> items = [];
    if (iterableVal is JinjaMap) {
      // Loop over keys (sorted?)
      items = iterableVal.items.keys
          .map((k) => JinjaStringValue.fromString(k))
          .toList();
    } else if (iterableVal is JinjaList) {
      items = iterableVal.items;
    } else if (iterableVal is JinjaTuple) {
      items = iterableVal.items;
    } else if (iterableVal is JinjaStringValue) {
      // Iterate chars
      items = iterableVal.value.parts
          .map((p) => p.val)
          .expand((s) => s.split(''))
          .map((c) => JinjaStringValue.fromString(c))
          .toList();
    }

    // Filter items first if testExpr
    if (testExpr != null) {
      List<JinjaValue> filtered = [];
      for (final item in items) {
        // Create temp context to evaluate test
        // We need to bind loop var to item
        final tempCtx = ctx.derive();
        _bindLoopVar(tempCtx, loopVar, item);
        if (testExpr.execute(tempCtx).asBool) {
          filtered.add(item);
        }
      }
      items = filtered;
    }

    if (items.isEmpty) {
      return execStatements(defaultBlock, ctx);
    }

    // Loop
    List<JinjaStringPart> parts = [];
    final loopCtx = ctx.derive(); // Scope for loop execution

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      // Loop object
      final loopObj = {
        'index': JinjaInteger(i + 1),
        'index0': JinjaInteger(i),
        'revindex': JinjaInteger(items.length - i),
        'revindex0': JinjaInteger(items.length - i - 1),
        'first': JinjaBoolean(i == 0),
        'last': JinjaBoolean(i == items.length - 1),
        'length': JinjaInteger(items.length),
        'previtem': i > 0 ? items[i - 1] : const JinjaUndefined(),
        'nextitem': i < items.length - 1
            ? items[i + 1]
            : const JinjaUndefined(),
      };
      loopCtx.set('loop', JinjaMap(loopObj.map((k, v) => MapEntry(k, v))));

      _bindLoopVar(loopCtx, loopVar, item);

      try {
        final result = execStatements(body, loopCtx);
        if (result is JinjaStringValue) parts.addAll(result.value.parts);
      } on ContinueSignal {
        continue;
      } on BreakSignal {
        break;
      }
    }

    return JinjaStringValue(JinjaString(parts));
  }

  void _bindLoopVar(Context ctx, Expression loopVar, JinjaValue item) {
    if (loopVar is Identifier) {
      ctx.set(loopVar.name, item);
    } else if (loopVar is TupleLiteral) {
      if (!item.isList) throw Exception('Cannot unpack non-sequence');
      final list = item.asList; // or assume it's list/tuple
      if (list.length != loopVar.items.length) {
        // mismatches?
      }
      for (int i = 0; i < loopVar.items.length && i < list.length; i++) {
        final v = loopVar.items[i];
        if (v is Identifier) {
          ctx.set(v.name, list[i]);
        }
      }
    }
  }
}

/// Represents a 'break' statement within a loop.
class BreakStatement extends Statement {
  BreakStatement(super.pos);
  @override
  String get type => 'Break';
  @override
  JinjaValue execute(Context ctx) {
    throw BreakSignal();
  }
}

/// Represents a 'continue' statement within a loop.
class ContinueStatement extends Statement {
  ContinueStatement(super.pos);
  @override
  String get type => 'Continue';
  @override
  JinjaValue execute(Context ctx) {
    throw ContinueSignal();
  }
}

/// A statement that does nothing.
class NoopStatement extends Statement {
  NoopStatement(super.pos);
  @override
  String get type => 'Noop';
  @override
  JinjaValue execute(Context ctx) => const JinjaNone();
}

/// Represents a 'set' statement for variable assignment.
class SetStatement extends Statement {
  /// The target for the assignment (e.g., Identifier or TupleLiteral).
  final Expression assignee;

  /// The expression whose value will be assigned. Null if it's a block assignment.
  final Expression? value; // null if block set
  /// The body of the block assignment, used to capture output if [value] is null.
  final List<Statement> body; // non-empty if block set

  SetStatement(super.pos, this.assignee, this.value, this.body);

  @override
  String get type => 'Set';

  @override
  JinjaValue execute(Context ctx) {
    JinjaValue rhs;
    if (value != null) {
      rhs = value!.execute(ctx);
    } else {
      // Block set: capture output of body
      rhs = execStatements(body, ctx);
    }

    if (assignee is Identifier) {
      ctx.set((assignee as Identifier).name, rhs);
    } else if (assignee is TupleLiteral) {
      // Unpack
      final tuple = assignee as TupleLiteral;
      if (!rhs.isList) throw Exception('Cannot unpack non-list');
      final list = rhs.asList;
      for (int i = 0; i < tuple.items.length; i++) {
        final target = tuple.items[i];
        if (target is Identifier) {
          ctx.set(
            target.name,
            i < list.length ? list[i] : const JinjaUndefined(),
          );
        }
      }
    } else if (assignee is MemberExpression) {
      // Set property: foo.bar = val
      final mem = assignee as MemberExpression;
      if (mem.computed) {
        throw Exception('Computed property assignment not supported');
      }
      if (mem.property is! Identifier) {
        throw Exception('Expected identifier property');
      }

      final obj = mem.object.execute(ctx);
      if (obj is JinjaMap) {
        obj.items[(mem.property as Identifier).name] = rhs;
      } else {
        throw Exception('Cannot set attribute on ${obj.typeName}');
      }
    }

    return const JinjaNone();
  }
}

/// Represents a 'macro' definition.
class MacroStatement extends Statement {
  /// The name of the macro.
  final Expression name; // Identifier
  /// The list of arguments the macro accepts.
  final List<Expression> args;

  /// The sequence of statements that form the macro's body.
  final List<Statement> body;

  MacroStatement(super.pos, this.name, this.args, this.body);

  @override
  String get type => 'Macro';

  @override
  JinjaValue execute(Context ctx) {
    if (name is! Identifier) {
      throw Exception('Macro name must be identifier');
    }
    final macroName = (name as Identifier).name;

    final func = JinjaFunction(macroName, (callArgs, callKwargs) {
      // Create macro context
      final macroCtx = ctx.derive();

      // Bind arguments
      for (int i = 0; i < args.length; i++) {
        final argDef = args[i];
        if (argDef is Identifier) {
          // Positional arg
          if (i < callArgs.length) {
            macroCtx.set(argDef.name, callArgs[i]);
          } else {
            macroCtx.set(argDef.name, const JinjaUndefined());
          }
        } else if (argDef is KeywordArgumentExpression) {
          // Default value: arg=default
          final key = argDef.key;
          if (key is! Identifier) {
            throw Exception('Invalid arg definition');
          }
          final paramName = key.name;

          if (callKwargs.containsKey(paramName)) {
            macroCtx.set(paramName, callKwargs[paramName]!);
          } else if (i < callArgs.length) {
            macroCtx.set(paramName, callArgs[i]);
          } else {
            // Use default
            macroCtx.set(paramName, argDef.val.execute(ctx));
          }
        }
      }

      // Inject 'caller' if present in kwargs (from {% call %})
      if (callKwargs.containsKey('caller')) {
        macroCtx.set('caller', callKwargs['caller']!);
      }

      return execStatements(body, macroCtx);
    });

    ctx.set(macroName, func);
    return const JinjaNone();
  }
}

/// Represents a comment in the Jinja source.
class CommentStatement extends Statement {
  /// The content of the comment.
  final String val;
  CommentStatement(super.pos, this.val);
  @override
  String get type => 'Comment';
  @override
  JinjaValue execute(Context ctx) => const JinjaNone();
}

/// Represents a 'call' block, used to invoke a macro with block content.
class CallStatement extends Statement {
  /// The macro call expression.
  final CallExpression call;

  /// Optional arguments for the caller.
  final List<Statement> callerArgs;

  /// The block content passed to the macro.
  final List<Statement> body;

  CallStatement(super.pos, this.call, this.callerArgs, this.body);
  @override
  String get type => 'CallStatement';

  @override
  JinjaValue execute(Context ctx) {
    // A 'call' block is equivalent to calling the target function/macro
    // with an additional keyword argument named 'caller', which is itself
    // a macro that renders the body of the call block.

    final callerMacro = JinjaFunction('caller', (callArgs, callKwargs) {
      final callerCtx = ctx.derive();
      // Bind callerArgs names to the values passed to caller()
      for (int i = 0; i < callArgs.length && i < callerArgs.length; i++) {
        final argDef = callerArgs[i];
        if (argDef is Identifier) {
          callerCtx.set(argDef.name, callArgs[i]);
        }
      }
      final out = StringBuffer();
      for (final stmt in body) {
        out.write(stmt.execute(callerCtx).toString());
      }
      return JinjaStringValue.fromString(out.toString());
    });

    final callExpr = call;
    // We need to execute the call expression but inject the 'caller' kwarg.
    // Instead of executing callExpr directly, we manually resolve the callee
    // and invoke it with the combined arguments.

    final callee = callExpr.callee.execute(ctx);
    if (callee is! JinjaFunction) {
      throw Exception('Callee must be a function/macro');
    }

    final args = callExpr.args
        .where((a) => a is! KeywordArgumentExpression)
        .map((a) => a.execute(ctx))
        .toList();
    final kwargs = <String, JinjaValue>{};
    for (final arg in callExpr.args.whereType<KeywordArgumentExpression>()) {
      kwargs[(arg.key as Identifier).name] = arg.val.execute(ctx);
    }

    // Inject caller
    kwargs['caller'] = callerMacro;

    return callee.handler(args, kwargs);
  }
}

/// Represents a 'filter' block, applying a filter to its content.
class FilterStatement extends Statement {
  /// The filter expression to apply.
  final Expression filter;

  /// The statements whose output will be filtered.
  final List<Statement> body;

  FilterStatement(super.pos, this.filter, this.body);
  @override
  String get type => 'FilterStatement';

  @override
  JinjaValue execute(Context ctx) {
    // Execute body
    final bodyResult = execStatements(body, ctx);
    // Apply filter to body result (as string usually)

    final result = FilterExpression(
      pos,
      _ValueExpression(bodyResult),
      filter,
    ).execute(ctx);
    return result;
  }
}

/// Represents a 'do' statement, which evaluates an expression and ignores its result.
class DoStatement extends Statement {
  /// The expression to evaluate.
  final Expression expr;
  DoStatement(super.pos, this.expr);
  @override
  String get type => 'DoStatement';

  @override
  JinjaValue execute(Context ctx) {
    expr.execute(ctx);
    return const JinjaNone();
  }
}

class _ValueExpression extends Expression {
  final JinjaValue val;
  _ValueExpression(this.val) : super(0);
  @override
  JinjaValue execute(Context ctx) => val;
}

// Expressions

/// Represents an identifier (variable name).
class Identifier extends Expression {
  /// The name of the identifier.
  final String name;
  Identifier(super.pos, this.name);
  @override
  String get type => 'Identifier';

  @override
  JinjaValue execute(Context ctx) {
    final val = ctx.resolve(name);
    if (!val.isUndefined) return val;

    // Check builtins
    if (globalBuiltins.containsKey(name)) {
      return JinjaFunction(name, globalBuiltins[name]!);
    }

    return const JinjaUndefined();
  }
}

/// Represents an integer literal.
class IntegerLiteral extends Expression {
  /// The integer value.
  final int value;
  IntegerLiteral(super.pos, this.value);
  @override
  String get type => 'IntegerLiteral';
  @override
  JinjaValue execute(Context ctx) => JinjaInteger(value);
}

/// Represents a floating-point literal.
class FloatLiteral extends Expression {
  /// The double value.
  final double value;
  FloatLiteral(super.pos, this.value);
  @override
  String get type => 'FloatLiteral';
  @override
  JinjaValue execute(Context ctx) => JinjaFloat(value);
}

/// Represents a string literal.
class StringLiteral extends Expression {
  /// The string value.
  final String value;
  final bool isSafe;
  StringLiteral(super.pos, this.value, {this.isSafe = false});
  @override
  String get type => 'StringLiteral';
  @override
  JinjaValue execute(Context ctx) =>
      JinjaStringValue(JinjaString.from(value, isSafe: isSafe));
}

/// Represents an array (list) literal.
class ArrayLiteral extends Expression {
  /// The items in the array.
  final List<Expression> items;
  ArrayLiteral(super.pos, this.items);
  @override
  String get type => 'ArrayLiteral';
  @override
  JinjaValue execute(Context ctx) {
    return JinjaList(items.map((e) => e.execute(ctx)).toList());
  }
}

/// Represents a tuple literal.
class TupleLiteral extends Expression {
  /// The items in the tuple.
  final List<Expression> items;
  TupleLiteral(super.pos, this.items);
  @override
  String get type => 'TupleLiteral';
  @override
  JinjaValue execute(Context ctx) {
    return JinjaTuple(items.map((e) => e.execute(ctx)).toList());
  }
}

/// Represents an object (map) literal.
class ObjectLiteral extends Expression {
  /// The key-value pairs in the object.
  final List<MapEntry<Expression, Expression>> items;
  ObjectLiteral(super.pos, this.items);
  @override
  String get type => 'ObjectLiteral';
  @override
  JinjaValue execute(Context ctx) {
    final map = <String, JinjaValue>{};
    for (final entry in items) {
      final key = entry.key.execute(ctx).toString();
      final val = entry.value.execute(ctx);
      map[key] = val;
    }
    return JinjaMap(map);
  }
}

/// Represents a member access expression (e.g., `obj.prop` or `obj[expr]`).
class MemberExpression extends Expression {
  /// The object being accessed.
  final Expression object;

  /// The property or index being accessed.
  final Expression property;

  /// Whether the access is computed (using `[]`) or not (using `.`).
  final bool computed; // true if [], false if .

  MemberExpression(
    super.pos,
    this.object,
    this.property, {
    required this.computed,
  });
  @override
  String get type => 'MemberExpression';

  @override
  @override
  JinjaValue execute(Context ctx) {
    if (computed) {
      // obj[expr]
      // Check for SliceExpression
      if (property is SliceExpression) {
        final slice = property as SliceExpression;
        final startVal = slice.start?.execute(ctx);
        final stopVal = slice.stop?.execute(ctx);
        final stepVal = slice.step?.execute(ctx);

        final obj = object.execute(ctx);

        int? start = (startVal != null && !startVal.isNone)
            ? startVal.asInt
            : null;
        int? stop = (stopVal != null && !stopVal.isNone) ? stopVal.asInt : null;
        int step = (stepVal != null && !stepVal.isNone) ? stepVal.asInt : 1;

        if (obj is JinjaList) {
          int len = obj.items.length;
          start ??= step > 0 ? 0 : len - 1;
          stop ??= step > 0 ? len : -1;

          if (start < 0) start += len;
          if (stop < 0 && slice.stop != null) {
            stop += len; // Only adjust if explicit negative
          }

          // Clamp
          if (step > 0) {
            if (start < 0) start = 0;
            if (stop > len) stop = len;
          } else {
            if (start >= len) start = len - 1;
            if (stop < -1) stop = -1;
          }

          final res = <JinjaValue>[];
          if (step > 0) {
            for (int i = start; i < stop; i += step) {
              if (i >= 0 && i < len) res.add(obj.items[i]);
            }
          } else if (step < 0) {
            for (int i = start; i > stop; i += step) {
              if (i >= 0 && i < len) res.add(obj.items[i]);
            }
          }
          return JinjaList(res);
        }
        if (obj is JinjaStringValue) {
          final s = obj.value;
          int len = s.length;
          start ??= step > 0 ? 0 : len - 1;
          stop ??= step > 0 ? len : -1;

          if (start < 0) start += len;
          if (stop < 0 && slice.stop != null) stop += len;

          // Clamp
          if (step > 0) {
            if (start < 0) start = 0;
            if (stop > len) stop = len;
          } else {
            if (start >= len) start = len - 1;
            if (stop < -1) stop = -1;
          }

          if (step == 1) {
            if (start >= stop) return const JinjaStringValue(JinjaString([]));
            return JinjaStringValue(s.substring(start, stop));
          }

          final parts = <JinjaStringPart>[];
          if (step > 0) {
            for (int i = start; i < stop; i += step) {
              if (i >= 0 && i < len) parts.addAll(s[i].parts);
            }
          } else if (step < 0) {
            for (int i = start; i > stop; i += step) {
              if (i >= 0 && i < len) parts.addAll(s[i].parts);
            }
          }
          return JinjaStringValue(JinjaString(parts));
        }

        return const JinjaUndefined();
      }

      final obj = object.execute(ctx);
      final prop = property.execute(ctx);

      if (obj is JinjaMap) {
        // Key access
        final key = prop.toString();
        return obj.items[key] ?? const JinjaUndefined();
      } else if (obj is JinjaList) {
        if (prop is JinjaInteger) {
          int idx = prop.value;
          // handle negative index
          if (idx < 0) idx += obj.items.length;
          if (idx >= 0 && idx < obj.items.length) {
            return obj.items[idx];
          }
        }
        return const JinjaUndefined();
      }
      // String index?
      if (obj is JinjaStringValue) {
        if (prop is JinjaInteger) {
          int idx = prop.value;
          String s = obj.value.toString();
          if (idx < 0) idx += s.length;
          if (idx >= 0 && idx < s.length) {
            return JinjaStringValue.fromString(s[idx]);
          }
        }
      }
      return const JinjaUndefined();
    } else {
      // obj.prop
      // prop IS Identifier
      if (property is! Identifier) {
        throw Exception('Member property must be identifier');
      }
      final propName = (property as Identifier).name;
      final obj = object.execute(ctx);

      if (obj is JinjaMap) {
        if (obj.items.containsKey(propName)) return obj.items[propName]!;
      }

      // Check builtins on object (methods)
      final method = resolveMember(obj, propName);
      if (method != null) return method;

      return const JinjaUndefined();
    }
  }
}

/// Represents a function or macro call expression.
class CallExpression extends Expression {
  /// The expression that evaluates to the function to call.
  final Expression callee;

  /// The list of arguments passed to the call.
  final List<Statement> args; // Arguments can be expressions or keyword args

  CallExpression(super.pos, this.callee, this.args);
  @override
  String get type => 'CallExpression';

  @override
  JinjaValue execute(Context ctx) {
    final func = callee.execute(ctx);
    if (func is! JinjaFunction) {
      throw Exception('Call to non-function: ${func.typeName}');
    }

    // Evaluate args
    List<JinjaValue> positionals = [];
    Map<String, JinjaValue> kwargs = {};

    for (final arg in args) {
      if (arg is KeywordArgumentExpression) {
        final key = arg.key;
        if (key is! Identifier) {
          throw Exception('Keyword arg key must be identifier');
        }
        kwargs[key.name] = arg.val.execute(ctx);
      } else if (arg is Expression) {
        positionals.add(arg.execute(ctx));
      }
    }

    return func.handler(positionals, kwargs);
  }
}

/// Represents a binary operation (e.g., `+`, `-`, `*`, `/`, `==`, `!=`).
class BinaryExpression extends Expression {
  /// The operator token.
  final Token op;

  /// The left-hand operand.
  final Expression left;

  /// The right-hand operand.
  final Expression right;

  BinaryExpression(super.pos, this.op, this.left, this.right);
  @override
  String get type => 'BinaryExpression';

  @override
  JinjaValue execute(Context ctx) {
    final l = left.execute(ctx);
    // Short-circuit logic
    if (op.value == 'and') return l.asBool ? right.execute(ctx) : l;
    if (op.value == 'or') {
      return l.asBool ? l : right.execute(ctx);
    }

    final r = right.execute(ctx);

    switch (op.value) {
      case '+':
        if (l.isString || r.isString) {
          JinjaString lStr = l is JinjaStringValue
              ? l.value
              : JinjaString.template(l.toString());
          JinjaString rStr = r is JinjaStringValue
              ? r.value
              : JinjaString.template(r.toString());
          return JinjaStringValue(lStr + rStr);
        }
        if (l.isNumeric && r.isNumeric) {
          if (l is JinjaFloat || r is JinjaFloat) {
            return JinjaFloat(l.asDouble + r.asDouble);
          }
          return JinjaInteger(l.asInt + r.asInt);
        }
        if (l.isList && r.isList) {
          return JinjaList([...l.asList, ...r.asList]);
        }
        throw Exception(
          'Invalid operand types for +: ${l.typeName}, ${r.typeName}',
        );
      case '-':
        if (l.isNumeric && r.isNumeric) {
          if (l is JinjaFloat || r is JinjaFloat) {
            return JinjaFloat(l.asDouble - r.asDouble);
          }
          return JinjaInteger(l.asInt - r.asInt);
        }
        throw Exception('Invalid operand types for -');
      case '*':
        if (l.isNumeric && r.isNumeric) {
          if (l is JinjaFloat || r is JinjaFloat) {
            return JinjaFloat(l.asDouble * r.asDouble);
          }
          return JinjaInteger(l.asInt * r.asInt);
        }
        // String repeat? `~` is concat. `*` is repeat in Python.
        if (l.isString && r.isNumeric) {
          return JinjaStringValue.fromString(l.toString() * r.asInt);
        }
        throw Exception('Invalid operand types for *');
      case '/':
        return JinjaFloat(
          l.asDouble / r.asDouble,
        ); // Always float division in Jinja
      case '//':
        return JinjaInteger((l.asDouble / r.asDouble).floor()); // Floor div
      case '%':
        if (l.isNumeric && r.isNumeric) {
          final res = l.asDouble % r.asDouble;
          if (l is JinjaInteger && r is JinjaInteger) {
            return JinjaInteger(res.toInt());
          }
          return JinjaFloat(res);
        }
        throw Exception('Invalid operand types for %');
      case '**':
        if (l.isNumeric && r.isNumeric) {
          final res = math.pow(l.asDouble, r.asDouble);
          if (l is JinjaInteger &&
              r is JinjaInteger &&
              res == res.toInt().toDouble()) {
            return JinjaInteger(res.toInt());
          }
          return JinjaFloat(res.toDouble());
        }
        throw Exception('Invalid operand types for **');
      case '==':
        if (l.isNumeric && r.isNumeric) {
          return JinjaBoolean(l.asDouble == r.asDouble);
        }
        return JinjaBoolean(l.toString() == r.toString());
      case '!=':
        if (l.isNumeric && r.isNumeric) {
          return JinjaBoolean(l.asDouble != r.asDouble);
        }
        return JinjaBoolean(l.toString() != r.toString());
      case '<':
        return JinjaBoolean(_compare(l, r) < 0);
      case '>':
        return JinjaBoolean(_compare(l, r) > 0);
      case '<=':
        return JinjaBoolean(_compare(l, r) <= 0);
      case '>=':
        return JinjaBoolean(_compare(l, r) >= 0);
      case '~': // concat
        return JinjaStringValue.fromString(l.toString() + r.toString());
      case 'in':
        // r must be container
        if (r is JinjaList) {
          return JinjaBoolean(r.items.any((e) => e == l));
        }
        if (r is JinjaTuple) {
          return JinjaBoolean(r.items.any((e) => e == l));
        }
        if (r is JinjaMap) {
          return JinjaBoolean(r.items.containsKey(l.toString()));
        }
        if (r is JinjaStringValue) {
          return JinjaBoolean(r.toString().contains(l.toString()));
        }
        return const JinjaBoolean(false);
      case 'not in':
        // negate in
        if (r is JinjaList) {
          return JinjaBoolean(!r.items.any((e) => e == l));
        }
        if (r is JinjaTuple) {
          return JinjaBoolean(!r.items.any((e) => e == l));
        }
        if (r is JinjaMap) {
          return JinjaBoolean(!r.items.containsKey(l.toString()));
        }
        if (r is JinjaStringValue) {
          return JinjaBoolean(!r.toString().contains(l.toString()));
        }
        return const JinjaBoolean(true);
    }

    throw Exception('Unknown operator ${op.value}');
  }

  double _compare(JinjaValue a, JinjaValue b) {
    if (a.isNumeric && b.isNumeric) {
      return a.asDouble.compareTo(b.asDouble).toDouble();
    }
    if (a.isString && b.isString) {
      return a.toString().compareTo(b.toString()).toDouble();
    }
    // Mixed types: try to parse string as number
    if (a.isNumeric && b.isString) {
      final bVal = double.tryParse(b.toString());
      if (bVal != null) return a.asDouble.compareTo(bVal).toDouble();
    }
    if (a.isString && b.isNumeric) {
      final aVal = double.tryParse(a.toString());
      if (aVal != null) return aVal.compareTo(b.asDouble).toDouble();
    }
    // Fallback: compare strings
    return a.toString().compareTo(b.toString()).toDouble();
  }
}

/// Represents a unary operation (e.g., `not`, `-`, `+`).
class UnaryExpression extends Expression {
  /// The operator token.
  final Token op;

  /// The operand expression.
  final Expression argument;
  UnaryExpression(super.pos, this.op, this.argument);
  @override
  String get type => 'UnaryExpression';

  @override
  JinjaValue execute(Context ctx) {
    final arg = argument.execute(ctx);
    if (op.value == 'not') return JinjaBoolean(!arg.asBool);
    if (op.value == '-') {
      if (arg is JinjaInteger) return JinjaInteger(-arg.value);
      if (arg is JinjaFloat) return JinjaFloat(-arg.value);
      throw Exception('Unary - expects numeric');
    }
    if (op.value == '+') {
      if (arg.isNumeric) return arg;
      throw Exception('Unary + expects numeric');
    }
    throw Exception('Unknown unary op ${op.value}');
  }
}

/// Represents a filter application (e.g., `val | filter`).
class FilterExpression extends Expression {
  /// The value being filtered.
  final Expression operand;

  /// The filter to apply.
  final Expression filter;
  FilterExpression(super.pos, this.operand, this.filter);
  @override
  String get type => 'FilterExpression';

  @override
  JinjaValue execute(Context ctx) {
    final val = operand.execute(ctx);

    // Resolve filter function
    String filterName;
    List<JinjaValue> args = [val]; // Filter receives value as first arg
    Map<String, JinjaValue> kwargs = {};

    if (filter is Identifier) {
      filterName = (filter as Identifier).name;
    } else if (filter is CallExpression) {
      final call = filter as CallExpression;
      if (call.callee is! Identifier) {
        throw Exception('Filter must be identifier');
      }
      filterName = (call.callee as Identifier).name;
      // Evaluate args
      for (final arg in call.args) {
        if (arg is KeywordArgumentExpression) {
          kwargs[(arg.key as Identifier).name] = arg.val.execute(ctx);
        } else if (arg is Expression) {
          args.add(arg.execute(ctx));
        }
      }
    } else {
      throw Exception('Invalid filter expression');
    }

    if (globalBuiltins.containsKey(filterName)) {
      final res = globalBuiltins[filterName]!(args, kwargs);
      return res;
    }
    throw Exception('Unknown filter: $filterName');
  }
}

/// Represents a test application (e.g., `val is defined`).
class TestExpression extends Expression {
  /// The value being tested.
  final Expression operand;

  /// Whether the test is negated (`is not`).
  final bool negate;

  /// The test to perform.
  final Expression test;
  TestExpression(super.pos, this.operand, this.negate, this.test);
  @override
  String get type => 'TestExpression';

  @override
  JinjaValue execute(Context ctx) {
    final val = operand.execute(ctx);

    String testName;
    List<JinjaValue> args = [val];
    Map<String, JinjaValue> kwargs = {};

    if (test is Identifier) {
      testName = (test as Identifier).name;
    } else if (test is CallExpression) {
      final call = test as CallExpression;
      if (call.callee is! Identifier) {
        throw Exception('Test must be identifier');
      }
      testName = (call.callee as Identifier).name;
      for (final arg in call.args) {
        if (arg is KeywordArgumentExpression) {
          kwargs[(arg.key as Identifier).name] = arg.val.execute(ctx);
        } else if (arg is Expression) {
          args.add(arg.execute(ctx));
        }
      }
    } else {
      throw Exception('Invalid test expression');
    }

    final funcName = 'test_is_$testName';
    if (globalBuiltins.containsKey(funcName)) {
      final res = globalBuiltins[funcName]!(args, kwargs);
      return negate ? JinjaBoolean(!res.asBool) : res;
    }

    throw Exception('Unknown test: $testName');
  }
}

/// Represents a selection expression used in filtering iterations.
class SelectExpression extends Expression {
  /// The value to select.
  final Expression lhs;

  /// The test condition.
  final Expression test;
  SelectExpression(super.pos, this.lhs, this.test);
  @override
  String get type => 'SelectExpression';
  @override
  JinjaValue execute(Context ctx) {
    if (test.execute(ctx).asBool) {
      return lhs.execute(ctx);
    }
    return const JinjaUndefined();
  }
}

/// Represents a ternary conditional expression (e.g., `a if cond else b`).
class TernaryExpression extends Expression {
  /// The condition to evaluate.
  final Expression condition;

  /// The result if the condition is true.
  final Expression trueExpr;

  /// The result if the condition is false.
  final Expression falseExpr;
  TernaryExpression(super.pos, this.condition, this.trueExpr, this.falseExpr);
  @override
  String get type => 'TernaryExpression';
  @override
  JinjaValue execute(Context ctx) {
    if (condition.execute(ctx).asBool) {
      return trueExpr.execute(ctx);
    } else {
      return falseExpr.execute(ctx);
    }
  }
}

/// Represents a keyword argument in a function or macro call.
class KeywordArgumentExpression extends Expression {
  /// The name of the argument.
  final Expression key;

  /// The value of the argument.
  final Expression val;
  KeywordArgumentExpression(super.pos, this.key, this.val);
  @override
  String get type => 'KeywordArgumentExpression';
  @override
  JinjaValue execute(Context ctx) =>
      throw Exception('KeywordArg executed directly');
}

/// Represents a slice expression (e.g., `start:stop:step`).
class SliceExpression extends Expression {
  /// The start index.
  final Expression? start;

  /// The stop index.
  final Expression? stop;

  /// The step size.
  final Expression? step;
  SliceExpression(super.pos, this.start, this.stop, this.step);
  @override
  String get type => 'SliceExpression';
  @override
  JinjaValue execute(Context ctx) =>
      throw Exception('SliceExpression executed directly');
}

/// Represents a spread operation.
class SpreadExpression extends Expression {
  /// The expression to spread.
  final Expression argument;
  SpreadExpression(super.pos, this.argument);
  @override
  String get type => 'SpreadExpression';
  @override
  JinjaValue execute(Context ctx) => argument.execute(ctx);
}
