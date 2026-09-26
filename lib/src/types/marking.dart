import 'jinja_string.dart';
import 'repr.dart';
import 'value.dart';

/// Whether [s] has input-marked text that is escaped on output.
bool hasRawInput(JinjaString s) => !s.isSafe && s.parts.any((p) => p.isInput);

/// [s] as unescaped text. The text of a safe string is final, so its
/// input-marked parts become template text.
JinjaString rawOf(JinjaString s) {
  if (!s.isSafe) return s;
  return JinjaString([
    for (final p in s.parts) p.isInput ? JinjaStringPart(p.val, false) : p,
  ]);
}

/// The string form of [v] that keeps the input marking of the strings in it:
/// a string itself, a list, tuple or dict as [reprOf], anything else as
/// template text.
JinjaString stringOf(JinjaValue v) {
  if (v is JinjaStringValue) return v.value;
  if (v is JinjaList || v is JinjaTuple || v is JinjaMap) return reprOf(v);
  return JinjaString.template(v.toString());
}

/// Joins [pieces] as unescaped text.
///
/// Without input-marked text the result is one template part, as a plain
/// string is; otherwise each character keeps the marking of its piece.
JinjaString joinRaw(Iterable<JinjaString> pieces) {
  final parts = <JinjaStringPart>[];
  for (final part in [for (final piece in pieces) ...rawOf(piece).parts]) {
    if (part.val.isEmpty) continue;
    if (parts.isNotEmpty && parts.last.isInput == part.isInput) {
      parts.last = JinjaStringPart(parts.last.val + part.val, part.isInput);
    } else {
      parts.add(part);
    }
  }
  if (!parts.any((p) => p.isInput)) {
    return JinjaString.template(parts.map((p) => p.val).join());
  }
  return JinjaString(parts);
}

/// The characters of [s], each keeping its input marking.
List<JinjaValue> charsOf(JinjaString s) => [
  for (final p in rawOf(s).parts)
    for (final c in p.val.split(''))
      JinjaStringValue(JinjaString([JinjaStringPart(c, p.isInput)])),
];

/// The rendered output of one render and the values its caller supplied.
class _Render {
  final Set<JinjaString> rendered = Set.identity();
  final Set<JinjaString> supplied = Set.identity();
  final Set<JinjaFunction> functions = Set.identity();

  /// Whether the caller supplied input-marked text or a function, the only
  /// sources of input-marked text in a render.
  bool get tracking => supplied.isNotEmpty || functions.isNotEmpty;

  void supply(Iterable<JinjaValue> values) => _walk(values, (s) {
    if (hasRawInput(s)) supplied.add(s);
  }, onFunction: functions.add);
}

_Render? _render;

/// Runs [render] over the caller's [values], with its own record of
/// rendered output, restored afterwards.
T renderScope<T>(Iterable<JinjaValue> values, T Function() render) {
  final saved = _render;
  _render = _Render()..supply(values);
  try {
    return render();
  } finally {
    _render = saved;
  }
}

/// Records [s] as rendered output: a block `set`, macro, `caller()` or
/// `filter` block body. Its text is final, as in Jinja2 with autoescape, so
/// `safe` escapes the input-marked text in it.
void markRendered(JinjaString s) => _render?.rendered.add(s);

/// Whether [s] is rendered output, or derived from it or from safe text, in
/// the current render.
bool isRendered(JinjaString s) => _render?.rendered.contains(s) ?? false;

/// Whether [f] was supplied by the caller of the current render.
bool isSupplied(JinjaFunction f) => _render?.functions.contains(f) ?? false;

/// Records the [result] of a call to [f]: a value from a function the caller
/// supplied is the caller's, and is never marked rendered.
JinjaValue called(JinjaFunction f, JinjaValue result) {
  if (isSupplied(f)) _render!.supply([result]);
  return result;
}

/// The strings in some values, and whether any is safe text or rendered
/// output, taken before an operation on them.
class RenderInputs {
  final Set<JinjaString> _known = Set.identity();
  var _final = false;

  RenderInputs(Iterable<JinjaValue> values) {
    final render = _render;
    if (render == null || !render.tracking) return;
    _walk(values, (s) {
      _known.add(s);
      if (s.isSafe || render.rendered.contains(s)) _final = true;
    });
  }

  /// Whether the values hold safe text or rendered output.
  bool get holdsFinal => _final;

  /// Marks the new strings with input-marked text in [result] as rendered
  /// when these values hold safe text or rendered output, as Jinja2 with
  /// autoescape keeps such a result markup.
  JinjaValue derive(JinjaValue result) {
    final render = _render;
    if (render == null || !_final) return result;
    _walk([result], (s) {
      if (hasRawInput(s) && !_known.contains(s)) render.rendered.add(s);
    });
    return result;
  }
}

/// [RenderInputs.derive] for an operation that does not change [inputs],
/// leaving the values the caller supplied unmarked.
JinjaValue deriveRendered(JinjaValue result, Iterable<JinjaValue> inputs) {
  final render = _render;
  if (render == null || !render.tracking) return result;
  var fresh = false;
  _walk([result], (s) {
    if (hasRawInput(s) && !render.supplied.contains(s)) fresh = true;
  });
  if (!fresh) return result;
  return RenderInputs(inputs).derive(result);
}

void _walk(
  Iterable<JinjaValue> values,
  void Function(JinjaString) visit, {
  void Function(JinjaFunction)? onFunction,
}) {
  final seen = Set<Object>.identity();
  void walk(JinjaValue v) {
    if (v is JinjaStringValue) {
      visit(v.value);
    } else if (v is JinjaFunction) {
      onFunction?.call(v);
    } else if (v is JinjaList || v is JinjaTuple || v is JinjaMap) {
      if (!seen.add(v)) return;
      if (v is JinjaList) v.items.forEach(walk);
      if (v is JinjaTuple) v.items.forEach(walk);
      if (v is JinjaMap) {
        v.items.keys.forEach(walk);
        v.items.values.forEach(walk);
      }
    }
  }

  values.forEach(walk);
}
