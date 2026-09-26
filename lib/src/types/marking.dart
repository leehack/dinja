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

final Expando<bool> _rendered = Expando();
var _inputSeen = false;

/// Runs [render] over the [values] it is given. Rendered output is tracked
/// only when they hold input-marked text.
T renderScope<T>(Iterable<JinjaValue> values, T Function() render) {
  final saved = _inputSeen;
  var input = false;
  _walk(values, (s) => input = input || hasRawInput(s));
  _inputSeen = input;
  try {
    return render();
  } finally {
    _inputSeen = saved;
  }
}

/// Records [s] as rendered output: a block `set`, macro, `caller()` or
/// `filter` block body. Its text is final, as in Jinja2 with autoescape, so
/// `safe` escapes the input-marked text in it.
void markRendered(JinjaString s) {
  if (hasRawInput(s)) _rendered[s] = true;
}

/// Whether [s] is rendered output, or derived from it or from safe text.
bool isRendered(JinjaString s) => _rendered[s] ?? false;

bool _isFinal(JinjaString s) => s.isSafe || isRendered(s);

/// Whether [v] is or holds safe text or rendered output.
bool holdsFinal(JinjaValue v) {
  if (!_inputSeen) return false;
  var found = false;
  _walk([v], (s) => found = found || _isFinal(s));
  return found;
}

/// Marks the new strings with input-marked text in [result] as rendered
/// when any of [inputs] holds safe text or rendered output, as Jinja2 with
/// autoescape keeps such a result markup.
JinjaValue deriveRendered(JinjaValue result, Iterable<JinjaValue> inputs) {
  if (!_inputSeen) return result;
  final known = Set<JinjaString>.identity();
  var fromFinal = false;
  _walk(inputs, (s) {
    known.add(s);
    if (_isFinal(s)) fromFinal = true;
  });
  if (!fromFinal) return result;
  _walk([result], (s) {
    if (!known.contains(s) && hasRawInput(s)) _rendered[s] = true;
  });
  return result;
}

void _walk(Iterable<JinjaValue> values, void Function(JinjaString) visit) {
  final seen = Set<Object>.identity();
  void walk(JinjaValue v) {
    if (v is JinjaStringValue) {
      visit(v.value);
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
